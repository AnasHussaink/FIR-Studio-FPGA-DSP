"""FIR Studio | Arty Artix-7, existing S/C UART bitstream.

Install: python -m pip install PySide6 pyqtgraph numpy pyserial
Run: python fir_interactive.py (or any filename you choose)

FPGA protocol (already implemented):
 S + 1 signed 8-bit sample -> 1 signed 8-bit result
 C + 4 signed 8-bit Q1.7 coefficients -> ASCII K
No software reset / no streaming implemented. BTN0 resets FPGA sample history.
"""
from __future__ import annotations

import csv
import math
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

try:
    import numpy as np
    import pyqtgraph as pg
    import serial
    from serial.tools import list_ports
    from PySide6.QtCore import QObject, QThread, QTimer, Qt, Signal, Slot
    from PySide6.QtGui import QColor, QFont, QIntValidator
    from PySide6.QtWidgets import (
        QApplication, QCheckBox, QComboBox, QDoubleSpinBox, QFileDialog,
        QFormLayout, QFrame, QGridLayout, QGroupBox, QHBoxLayout, QHeaderView,
        QLabel, QLineEdit, QMainWindow, QMessageBox, QProgressBar, QPushButton, QSpinBox,
        QSplitter, QTableWidget, QTableWidgetItem, QTabWidget, QTextEdit,
        QVBoxLayout, QWidget, QScrollArea, QAbstractSpinBox,
    )
except ImportError as exc:
    raise SystemExit("Missing a dependency. Run: python -m pip install PySide6 pyqtgraph numpy pyserial") from exc

BAUD = 115200
DEFAULT = [16, 48, 48, 16]
BLUE = '#58a6ff'
GREEN = '#39d5a0'
AMBER = '#ffc76a'
RED = '#ff6976'
MUTED = '#94a7bf'


def signed8(n: int) -> int:
    return ((n + 128) % 256) - 128


@dataclass
class Record:
    number: int
    timestamp: str
    sample: int
    previous: tuple[int, int, int]
    coefficients: tuple[int, int, int, int]
    raw: int
    expected: int
    actual: int
    elapsed_ms: float
    ok: bool


class SerialWorker(QObject):
    result = Signal(str, object, str)
    finished = Signal()

    def __init__(self, connection, command: str, payload: bytes):
        super().__init__()
        self.connection = connection
        self.command = command
        self.payload = payload

    @Slot()
    def run(self):
        try:
            # Keep COM port open for the entire GUI session. One UART transaction
            # at a time: the FPGA controller is stop-and-wait, without a FIFO.
            import time
            start = time.monotonic()
            self.connection.write(self.payload)
            self.connection.flush()
            reply = self.connection.read(1)
            if len(reply) != 1:
                raise TimeoutError('No reply from FPGA (2 s timeout).')
            if self.command == 'C' and reply != b'K':
                raise ValueError(f'Expected K acknowledgement, got {reply!r}')
            self.result.emit(self.command, (reply, (time.monotonic() - start) * 1000), '')
        except Exception as exc:
            self.result.emit(self.command, None, str(exc))
        finally:
            self.finished.emit()


class StatCard(QFrame):
    def __init__(self, label, value='—', accent=BLUE):
        super().__init__()
        self.setObjectName('statCard')
        layout = QVBoxLayout(self)
        layout.setContentsMargins(18, 12, 18, 12)
        lab = QLabel(label.upper()); lab.setObjectName('eyebrow')
        self.value = QLabel(value); self.value.setObjectName('statValue')
        self.value.setStyleSheet(f'color:{accent};')
        layout.addWidget(lab); layout.addWidget(self.value)


class IntegerEntry(QLineEdit):
    """Simple visible numeric entry, avoiding QSpinBox's native subcontrol rendering."""
    valueChanged = Signal(int)

    def __init__(self, minimum, maximum, initial):
        super().__init__(str(initial))
        self.setValidator(QIntValidator(minimum, maximum, self))
        self.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        self.setMinimumHeight(36)
        self.setMinimumWidth(70)
        self.setStyleSheet('QLineEdit { background-color: #0e1a2b; color: #ffffff; '
                           'border: 1px solid #58718f; border-radius: 5px; '
                           'padding: 6px 9px; selection-background-color: #2375c3; }'
                           'QLineEdit:focus { border: 2px solid #58a6ff; }')
        self.textEdited.connect(self._updated)

    def _updated(self, text):
        if self.hasAcceptableInput():
            self.valueChanged.emit(int(text))

    def value(self):
        if not self.hasAcceptableInput():
            raise ValueError('Enter a valid integer in every numeric field.')
        return int(self.text())

    def setValue(self, value):
        self.setText(str(value))
        self.valueChanged.emit(int(value))


class FirStudio(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('FIR Studio  |  FPGA Signal Analysis Workbench')
        self.resize(1520, 960)
        self.setMinimumSize(1050, 680)
        self.coeffs = DEFAULT.copy()
        self.history = [0, 0, 0]
        self.records: list[Record] = []
        self.synced = False
        self.connected = False
        self.busy = False
        self.sequence: list[int] = []
        self.sequence_active = False
        self.thread = None
        self.worker = None
        self.serial_connection = None
        self._pending_value = None
        self.play_timer = QTimer(self)
        self.play_timer.timeout.connect(self._feed_next)
        self._create_ui()
        self._refresh_ports()
        self._refresh_plots()
        self._refresh_response()

    def _create_ui(self):
        self.setStyleSheet('''
        QMainWindow, QWidget {background:#0c1422;color:#e6eef9;font:10pt "Segoe UI";}
        QFrame#statCard,QGroupBox {background-color:#152237;color:#e6eef9;border:1px solid #263a55;border-radius:10px;}
        QGroupBox QLabel {background:transparent;color:#e6eef9;}
        QGroupBox QSpinBox, QGroupBox QComboBox {background-color:#0e1a2b;color:#eef5ff;}
        QScrollArea, QScrollArea > QWidget > QWidget {background:#0c1422;border:0;}
        QGroupBox {font-weight:600;margin-top:12px;padding-top:15px;}
        QGroupBox::title {subcontrol-origin:margin;left:13px;padding:0 5px;color:#bfcee3;}
        QLabel#eyebrow {font-size:9pt;letter-spacing:1px;color:#92a8c1;}
        QLabel#statValue {font:700 23pt "Segoe UI";}
        QLabel#title {font:700 21pt "Segoe UI";color:#f0f6ff;}
        QLabel#subtitle {color:#98aac2;}
        QPushButton {background:#243952;border:1px solid #38516e;border-radius:6px;padding:8px 11px;font-weight:600;}
        QPushButton:hover {background:#304d6d;}
        QPushButton:disabled {color:#62768d;background:#172439;border-color:#22334a;}
        QPushButton#primary {background:#2375c3;border:1px solid #4c9bdf;color:white;}
        QPushButton#danger {background:#5b2836;border:1px solid #9f465a;}
        QSpinBox,QDoubleSpinBox,QComboBox {background:#0e1a2b;border:1px solid #3b506d;border-radius:5px;padding:5px 9px;color:white;min-height:23px;}
        QSpinBox::up-button,QSpinBox::down-button,QDoubleSpinBox::up-button,QDoubleSpinBox::down-button {width:0px;border:0px;}
        QComboBox::drop-down {width:23px;border:0px;}
        QComboBox QAbstractItemView {background:#17273b;color:white;selection-background-color:#28629b;}
        QPushButton {min-height:21px;}
        QTableWidget {background:#101d30;alternate-background-color:#15263c;border:1px solid #2d405b;gridline-color:#24374e;}
        QHeaderView::section {background:#1d3048;padding:7px;border:0;border-right:1px solid #30445f;color:#d1e0f3;}
        QTabWidget::pane {border:1px solid #2b415d;}
        QTabBar::tab {background:#17273b;padding:9px 17px;color:#95aac5;}
        QTabBar::tab:selected {background:#2b4260;color:white;}
        QProgressBar {border:1px solid #30445f;border-radius:4px;text-align:center;background:#152237;}
        QProgressBar::chunk {background:#2ba98e;}
        QTextEdit {background:#101b2d;border:1px solid #30445f;color:#c3d3e7;font:9pt Consolas;}
        QCheckBox {spacing:7px;}
        ''')
        pg.setConfigOptions(antialias=True, background='#111e31', foreground='#b7cbe4')
        central = QWidget(); self.setCentralWidget(central)
        main = QVBoxLayout(central); main.setSpacing(12); main.setContentsMargins(18, 14, 18, 14)
        header = QHBoxLayout()
        brand = QVBoxLayout()
        t = QLabel('FIR STUDIO  /  FPGA SIGNAL WORKBENCH'); t.setObjectName('title')
        st = QLabel('Arty Artix-7 35T   ·   100 MHz FPGA clock   ·   Q1.7 fixed point   ·   UART 115200   ·   stop-and-wait samples')
        st.setObjectName('subtitle')
        brand.addWidget(t);brand.addWidget(st)
        header.addLayout(brand, 1)
        header.addWidget(QLabel('PORT'))
        self.port_combo = QComboBox(); self.port_combo.setMinimumWidth(125);header.addWidget(self.port_combo)
        b = QPushButton('Refresh');b.clicked.connect(self._refresh_ports);header.addWidget(b)
        self.connect_btn = QPushButton('Connect'); self.connect_btn.setObjectName('primary'); self.connect_btn.clicked.connect(self._connect);header.addWidget(self.connect_btn)
        main.addLayout(header)
        self.status = QLabel('●  Disconnected  ·  Press/release BTN0 before a new synchronized session')
        self.status.setStyleSheet('color:#ffbb79');main.addWidget(self.status)
        cards = QHBoxLayout(); self.stat_samples = StatCard('Samples','0');self.stat_pass=StatCard('Verified','0',GREEN)
        self.stat_fail=StatCard('Mismatches','0',RED);self.stat_latest=StatCard('Last FPGA output','—',AMBER)
        for c in [self.stat_samples,self.stat_pass,self.stat_fail,self.stat_latest]:cards.addWidget(c)
        main.addLayout(cards)
        body = QSplitter(Qt.Horizontal)
        body.setChildrenCollapsible(False)
        left = QWidget(); left.setMinimumWidth(400); l = QVBoxLayout(left);l.setContentsMargins(5,5,9,5);l.setSpacing(12)
        sample_box=QGroupBox('SAMPLE GENERATOR  /  S command');sf=QVBoxLayout(sample_box)
        sr=QHBoxLayout();self.sample_spin=IntegerEntry(-128,127,40);self.sample_spin.setMinimumWidth(95)
        self.send_btn=QPushButton('Send sample →');self.send_btn.setObjectName('primary');self.send_btn.clicked.connect(self._send_sample)
        sr.addWidget(QLabel('Signed value'));sr.addWidget(self.sample_spin,1);sr.addWidget(self.send_btn);sf.addLayout(sr)
        self.hist_label=QLabel('History [newest → oldest]   0 · 0 · 0');self.hist_label.setStyleSheet('color:#9eb2cb');sf.addWidget(self.hist_label)
        l.addWidget(sample_box)
        coeff_box=QGroupBox('FILTER DESIGN  /  C command');cf=QVBoxLayout(coeff_box)
        self.coeff_spins=[];coef_grid=QGridLayout()
        for i,c in enumerate(DEFAULT):
            sp=IntegerEntry(-128,127,c);sp.setMinimumWidth(66);sp.valueChanged.connect(self._refresh_response)
            self.coeff_spins.append(sp);coef_grid.addWidget(QLabel(f'h{i}'),0,i);coef_grid.addWidget(sp,1,i)
        cf.addLayout(coef_grid)
        presets=QHBoxLayout()
        for name,values in [('Weighted',[16,48,48,16]),('Average',[32,32,32,32]),('Newest',[64,32,16,16])]:
            bt=QPushButton(name);bt.clicked.connect(lambda checked=False,v=values:self._preset(v));presets.addWidget(bt)
        cf.addLayout(presets)
        self.coeff_load=QPushButton('Apply coefficients to FPGA');self.coeff_load.clicked.connect(self._send_coeff);cf.addWidget(self.coeff_load)
        self.coeff_label=QLabel('ACTIVE FPGA COEFFS   [16, 48, 48, 16]');self.coeff_label.setWordWrap(True);self.coeff_label.setStyleSheet('color:#64dbbe');cf.addWidget(self.coeff_label)
        self.sum_label=QLabel('Editor sum: 128 / 128');cf.addWidget(self.sum_label)
        l.addWidget(coeff_box)
        gen_box=QGroupBox('TEST SEQUENCE  /  hardware responses');gf=QVBoxLayout(gen_box)
        gf.addWidget(QLabel('Waveform to send as sequential S commands'))
        self.wave_select=QComboBox();self.wave_select.addItems(['Sine','Square','Triangle','Impulse','Step','Random (seeded)']);gf.addWidget(self.wave_select)
        opt=QGridLayout();self.count_spin=IntegerEntry(4,2000,64)
        self.amplitude_spin=IntegerEntry(1,120,60)
        self.period_spin=IntegerEntry(4,256,24)
        for spin in (self.count_spin,self.amplitude_spin,self.period_spin):
            spin.setMinimumWidth(115)
        opt.addWidget(QLabel('Samples'),0,0);opt.addWidget(self.count_spin,0,1)
        opt.addWidget(QLabel('Amplitude'),1,0);opt.addWidget(self.amplitude_spin,1,1)
        opt.addWidget(QLabel('Period (samples)'),2,0);opt.addWidget(self.period_spin,2,1)
        gf.addLayout(opt)
        self.run_btn=QPushButton('▶  Run sequence on FPGA');self.run_btn.setObjectName('primary');self.run_btn.clicked.connect(self._start_sequence)
        self.stop_btn=QPushButton('■  Stop after current sample');self.stop_btn.clicked.connect(self._stop_sequence)
        gf.addWidget(self.run_btn);gf.addWidget(self.stop_btn)
        self.progress=QProgressBar();self.progress.setRange(0,100);self.progress.setValue(0);gf.addWidget(self.progress)
        gf.addWidget(QLabel('One sample → one reply. Not a high-speed continuous capture.'))
        l.addWidget(gen_box)
        act=QHBoxLayout();self.export_btn=QPushButton('Export CSV');self.export_btn.clicked.connect(self._export)
        self.clear_btn=QPushButton('Clear charts');self.clear_btn.clicked.connect(self._clear_charts)
        act.addWidget(self.export_btn);act.addWidget(self.clear_btn);l.addLayout(act)
        self.note=QLabel('IMPORTANT: Clear charts does not reset FPGA history.\nBTN0 resets FPGA. Disconnect/reconnect afterward to resync.')
        self.note.setWordWrap(True);self.note.setStyleSheet('color:#d7ac75;');l.addWidget(self.note)
        l.addStretch(1)
        left_scroll=QScrollArea();left_scroll.setWidgetResizable(True);left_scroll.setFrameShape(QFrame.NoFrame);left_scroll.setMinimumWidth(420);left_scroll.setWidget(left)
        body.addWidget(left_scroll)
        self.tabs=QTabWidget()
        signal_tab=QWidget();signal_layout=QVBoxLayout(signal_tab)
        self.wave_plot=self._plot_widget('Sample index','Signed 8-bit value')
        self.curve_input=self.wave_plot.plot(pen=pg.mkPen(BLUE,width=1.6),name='Input')
        self.curve_actual=self.wave_plot.plot(pen=pg.mkPen(GREEN,width=2.2),name='FPGA actual')
        self.curve_expected=self.wave_plot.plot(pen=pg.mkPen(AMBER,width=1.5,style=Qt.DashLine),name='Python expected')
        self.cursor=pg.InfiniteLine(pos=1,angle=90,movable=True,pen=pg.mkPen('#728aa9',style=Qt.DotLine));self.wave_plot.addItem(self.cursor)
        self.cursor.sigPositionChanged.connect(self._cursor_readout)
        self.cursor_text=QLabel('Drag vertical cursor to inspect a sample. Mouse wheel: zoom · drag: pan')
        self.cursor_text.setStyleSheet('color:#91a8c5');signal_layout.addWidget(self.wave_plot,1);signal_layout.addWidget(self.cursor_text)
        self.tabs.addTab(signal_tab,'Waveforms')
        analysis_tab=QWidget();an=QVBoxLayout(analysis_tab)
        an.addWidget(QLabel('Theoretical frequency response of the EDITED coefficients (not a measured FPGA sweep).'))
        self.response_plot=self._plot_widget('Normalized frequency (cycles/sample)','Magnitude (dB)')
        self.response_curve=self.response_plot.plot(pen=pg.mkPen(AMBER,width=2))
        an.addWidget(self.response_plot,1)
        self.response_info=QLabel('');an.addWidget(self.response_info)
        self.error_plot=self._plot_widget('Sample index','FPGA − Python (LSB)')
        self.error_curve=self.error_plot.plot(pen=pg.mkPen(RED,width=1.5),symbol='o',symbolSize=4)
        an.addWidget(self.error_plot,1)
        self.tabs.addTab(analysis_tab,'Frequency & Error')
        log_tab=QWidget();log_layout=QVBoxLayout(log_tab)
        self.table=QTableWidget(0,8);self.table.setHorizontalHeaderLabels(['#','Sample','Previous 3','Coeff (Q1.7)','Python','FPGA','Error','Result'])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table.setAlternatingRowColors(True);self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        log_layout.addWidget(self.table)
        self.tabs.addTab(log_tab,'Measurements')
        self.log=QTextEdit();self.log.setReadOnly(True);self.log.setMaximumHeight(125)
        self.tabs.addTab(self.log,'Event log')
        body.addWidget(self.tabs);body.setStretchFactor(0,0);body.setStretchFactor(1,1);body.setSizes([460,1050])
        main.addWidget(body,1)
        self._set_enabled()
        self._log('Application ready. Board must be reset using BTN0 before connecting.')

    def _plot_widget(self, xlabel, ylabel):
        plot=pg.PlotWidget()
        plot.setLabel('bottom',xlabel);plot.setLabel('left',ylabel)
        plot.showGrid(x=True,y=True,alpha=0.2)
        plot.getPlotItem().getViewBox().setMouseMode(pg.ViewBox.PanMode)
        plot.addLegend(offset=(10,8))
        return plot

    def _log(self, msg):
        self.log.append(f'[{datetime.now():%H:%M:%S}] {msg}')

    def _refresh_ports(self):
        current=self.port_combo.currentText() or 'COM5'
        ports=[p.device for p in list_ports.comports()]
        self.port_combo.clear();self.port_combo.addItems(ports or ['COM5'])
        if current in ports:self.port_combo.setCurrentText(current)
        elif 'COM5' in ports:self.port_combo.setCurrentText('COM5')

    def _set_enabled(self):
        enabled=self.connected and self.synced and not self.busy and not self.sequence_active
        for control in [self.send_btn,self.coeff_load,self.run_btn]:control.setEnabled(enabled)
        self.stop_btn.setEnabled(self.sequence_active)
        self.connect_btn.setEnabled(not self.busy and not self.sequence_active)
        self.connect_btn.setText('Disconnect' if self.connected else 'Connect')

    def _connect(self):
        if self.connected:
            self._stop_sequence();self.connected=False;self.synced=False
            if self.serial_connection is not None:
                self.serial_connection.close()
                self.serial_connection = None
            self.status.setText('●  Disconnected  ·  Press BTN0 before reconnecting')
            self.status.setStyleSheet('color:#ffbb79')
            self._log('Disconnected; history will require resynchronization.')
            self._set_enabled();return
        port=self.port_combo.currentText().strip()
        if not QMessageBox.question(self,'Synchronize FPGA',
                'Have you pressed and released BTN0 on your Arty board?\n\n'
                'This is essential: it clears hardware sample history and restores default coefficients.\n'
                'The existing bitstream has NO UART reset command.',
                QMessageBox.Yes|QMessageBox.No,QMessageBox.No)==QMessageBox.Yes:
            return
        try:
            self.serial_connection = serial.Serial(port,BAUD,timeout=2,write_timeout=2)
            self.serial_connection.reset_input_buffer()
        except Exception as exc:
            QMessageBox.critical(self,'Serial port unavailable',str(exc));return
        self.connected=True;self.synced=True;self.coeffs=DEFAULT.copy();self.history=[0,0,0]
        self._preset(DEFAULT)
        self.coeff_label.setText('ACTIVE FPGA COEFFS   '+str(self.coeffs))
        self._clear_charts()
        self.status.setText(f'●  CONNECTED   {port} · {BAUD} baud · history synchronized by BTN0')
        self.status.setStyleSheet('color:#39d5a0')
        self._log(f'Connected on {port}, assuming BTN0 reset. Sample history [0,0,0].')
        self._set_enabled()

    def _preset(self,values):
        for s,v in zip(self.coeff_spins,values):s.setValue(v)
        self._refresh_response()

    def _refresh_response(self,*args):
        if not hasattr(self,'response_curve'):return
        c=np.array([s.value() for s in self.coeff_spins],dtype=float)/128.0
        w=np.linspace(0,0.5,512)
        response=sum(c[k]*np.exp(-2j*np.pi*w*k) for k in range(4))
        db=20*np.log10(np.maximum(abs(response),1e-6))
        self.response_curve.setData(w,db)
        self.response_plot.setXRange(0,0.5,padding=0)
        self.response_info.setText(f'Edited sum={sum(s.value() for s in self.coeff_spins)} /128   ·   DC gain={sum(c):.4f}   ·   Nyquist gain={abs(response[-1]):.4f}   ·   Q1.7')
        self.sum_label.setText(f'Editor coefficient sum: {sum(s.value() for s in self.coeff_spins)} / 128')

    def _send_sample(self):
        try:
            value = self.sample_spin.value()
        except ValueError as exc:
            QMessageBox.warning(self, 'Invalid sample', str(exc))
            return
        self._command('S',value)

    def _send_coeff(self):
        try:
            values = [s.value() for s in self.coeff_spins]
        except ValueError as exc:
            QMessageBox.warning(self, 'Invalid coefficients', str(exc))
            return
        self._command('C', values)

    def _command(self,kind,value):
        if not self.connected or not self.synced or self.busy:return
        payload=(b'S'+bytes([value&255])) if kind=='S' else (b'C'+bytes([v&255 for v in value]))
        self.busy=True;self._set_enabled()
        self._pending_value = value
        self.thread=QThread(self)
        self.worker=SerialWorker(self.serial_connection,kind,payload)
        self.worker.moveToThread(self.thread)
        self.thread.started.connect(self.worker.run)
        # Route the worker signal to a QObject slot in the GUI thread.
        self.worker.result.connect(self._on_worker_result)
        self.worker.finished.connect(self.thread.quit)
        self.worker.finished.connect(self.worker.deleteLater)
        self.thread.finished.connect(self.thread.deleteLater)
        self.thread.finished.connect(self._worker_thread_finished)
        self.thread.start()

    @Slot(str, object, str)
    def _on_worker_result(self, kind, answer, error):
        self._on_result(kind, answer, error, self._pending_value)

    @Slot()
    def _worker_thread_finished(self):
        # Start the next UART command only once the prior thread has exited.
        self.thread = None
        self.worker = None
        if self.sequence_active and self.sequence and not self.busy and self.synced:
            QTimer.singleShot(0, self._feed_next)

    def _on_result(self,kind,answer,error,value):
        self.busy=False
        if error:
            self._stop_sequence()
            self.synced=False
            self.status.setText('●  LINK ERROR / STATE UNKNOWN · BTN0 reset, then reconnect')
            self.status.setStyleSheet('color:#ff6976')
            self._log(f'ERROR {kind}: {error}. No further commands until reset and reconnect.')
            QMessageBox.warning(self,'Serial communication error',error+'\n\nPress BTN0, disconnect and reconnect to resynchronize.')
            self._set_enabled();return
        reply,elapsed=answer
        if kind=='C':
            self.coeffs=list(value)
            self.coeff_label.setText('ACTIVE FPGA COEFFS   '+str(self.coeffs))
            self._log(f'C ACK K · coefficients loaded {self.coeffs} · {elapsed:.1f} ms')
        else:
            samples=[int(value)]+self.history
            raw=sum(int(c)*int(x) for c,x in zip(self.coeffs,samples))//128
            expected=signed8(raw)
            actual=int.from_bytes(reply,'little',signed=True)
            ok=actual==expected
            item=Record(len(self.records)+1,datetime.now().isoformat(timespec='seconds'),int(value),tuple(self.history),tuple(self.coeffs),raw,expected,actual,elapsed,ok)
            self.records.append(item)
            self.history=[int(value)]+self.history[:2]
            self.hist_label.setText('History [newest → oldest]   '+' · '.join(map(str,self.history)))
            self._add_row(item)
            self._refresh_plots()
            self._log(f'S {value:+d} → FPGA {actual:+d} · expected {expected:+d} · {"PASS" if ok else "FAIL"} · {elapsed:.1f} ms')
            if raw!=expected:self._log('Note: output wrapped to signed 8-bit; saturation is NOT in firmware.')
            if not ok:
                self._stop_sequence()
                self.synced = False
                self.status.setText('●  OUTPUT MISMATCH / STATE UNKNOWN · BTN0 reset and reconnect')
                self.status.setStyleSheet('color:#ff6976')
                self._log('Verification mismatch: stopped further transfers to prevent misleading data.')
            if self.sequence_active:
                self.progress.setValue(int(100*self.sequence_index/self.sequence_total))
                if not self.sequence:
                    self.sequence_active=False
                    self._log('Sequence complete.')
        self._set_enabled()

    def _add_row(self,r):
        row=self.table.rowCount();self.table.insertRow(row)
        entries=[r.number,r.sample,str(r.previous),str(r.coefficients),r.expected,r.actual,r.actual-r.expected,'PASS' if r.ok else 'FAIL']
        for j,v in enumerate(entries):
            item=QTableWidgetItem(str(v));item.setTextAlignment(Qt.AlignCenter)
            if j==7:item.setForeground(QColor(GREEN if r.ok else RED))
            self.table.setItem(row,j,item)
        self.table.scrollToBottom()

    def _refresh_plots(self):
        xs=np.array([r.number for r in self.records],dtype=float)
        self.curve_input.setData(xs,[r.sample for r in self.records])
        self.curve_actual.setData(xs,[r.actual for r in self.records])
        self.curve_expected.setData(xs,[r.expected for r in self.records])
        self.error_curve.setData(xs,[r.actual-r.expected for r in self.records])
        self.stat_samples.value.setText(str(len(self.records)))
        self.stat_pass.value.setText(str(sum(r.ok for r in self.records)))
        self.stat_fail.value.setText(str(sum(not r.ok for r in self.records)))
        self.stat_latest.value.setText(str(self.records[-1].actual) if self.records else '—')
        if not self.records:
            self.wave_plot.setXRange(0,20,padding=0)
            self.wave_plot.setYRange(-128,127,padding=0)
            self.error_plot.setXRange(0,20,padding=0)
            self.error_plot.setYRange(-2,2,padding=0)
        if self.records:
            self.wave_plot.setXRange(0.5,max(2.5,len(self.records)+0.5),padding=0)
            values=[v for r in self.records for v in (r.sample,r.actual,r.expected)]
            lo=min(values);hi=max(values);pad=max(4,(hi-lo)*0.12)
            self.wave_plot.setYRange(lo-pad,hi+pad,padding=0)
            self.error_plot.enableAutoRange()

    def _cursor_readout(self):
        if not self.records:return
        n=round(self.cursor.value())
        if 1<=n<=len(self.records):
            r=self.records[n-1]
            self.cursor_text.setText(f'CURSOR #{n}    input {r.sample:+d}  |  FPGA {r.actual:+d}  |  Python {r.expected:+d}  |  error {r.actual-r.expected:+d}  |  {r.elapsed_ms:.1f} ms UART transaction')

    def _generate_sequence(self):
        try:
            n=self.count_spin.value();amp=self.amplitude_spin.value();period=self.period_spin.value()
        except ValueError as exc:
            QMessageBox.warning(self, 'Invalid generator setting', str(exc))
            return
        mode=self.wave_select.currentText()
        rng=np.random.default_rng(42)
        output=[]
        for i in range(n):
            if mode=='Sine':v=amp*math.sin(2*math.pi*i/period)
            elif mode=='Square':v=amp*(1 if i%period<period/2 else -1)
            elif mode=='Triangle':v=amp*(4*abs(((i/period+0.25)%1)-0.5)-1)
            elif mode=='Impulse':v=amp if i==0 else 0
            elif mode=='Step':v=0 if i<n//3 else amp
            else:v=int(rng.integers(-amp,amp+1))
            output.append(max(-128,min(127,round(v))))
        return output

    def _start_sequence(self):
        if not self.connected or self.busy or not self.synced:return
        self.sequence=self._generate_sequence()
        self.sequence_active=True
        self.sequence_total=len(self.sequence);self.sequence_index=0
        self.progress.setValue(0);self._log(f'Start {self.wave_select.currentText()} sequence: {self.sequence_total} samples, stop-and-wait')
        self._feed_next()

    def _feed_next(self):
        if not self.sequence_active or not self.sequence or self.busy or not self.synced:return
        value=self.sequence.pop(0);self.sequence_index+=1
        self.sample_spin.setValue(value)
        self._command('S',value)

    def _stop_sequence(self):
        if self.sequence_active:self._log('Sequence stopped; in-flight sample will finish.')
        self.sequence=[]
        self.sequence_active=False
        self.progress.setValue(0)
        self._set_enabled()

    def _clear_charts(self):
        if self.busy or self.sequence_active:return
        self.records.clear();self.table.setRowCount(0)
        self._refresh_plots();self.progress.setValue(0)
        self._log('Display cleared; FPGA and Python sample histories were NOT reset.')

    def _export(self):
        if not self.records:
            QMessageBox.information(self,'No results','Send some samples first.');return
        name=f'fir_capture_{datetime.now():%Y%m%d_%H%M%S}.csv'
        path,_=QFileDialog.getSaveFileName(self,'Export verified sample data',str(Path.cwd()/name),'CSV files (*.csv)')
        if not path:return
        with open(path,'w',newline='',encoding='utf-8') as f:
            writer=csv.writer(f)
            writer.writerow(['sample_index','timestamp','sample','prev1','prev2','prev3','h0','h1','h2','h3','full_q17_result','expected_signed8','fpga_signed8','difference','pass','uart_roundtrip_ms'])
            for r in self.records:
                writer.writerow([r.number,r.timestamp,r.sample,*r.previous,*r.coefficients,r.raw,r.expected,r.actual,r.actual-r.expected,r.ok,f'{r.elapsed_ms:.3f}'])
        self._log(f'CSV exported: {path}')

    def closeEvent(self,event):
        if self.busy:
            QMessageBox.warning(self,'UART transaction active','Allow the current UART request to finish before closing.')
            event.ignore();return
        if self.serial_connection is not None:
            self.serial_connection.close()
            self.serial_connection = None
        event.accept()


if __name__=='__main__':
    app=QApplication(sys.argv)
    app.setFont(QFont('Segoe UI',10))
    window=FirStudio();window.show()
    sys.exit(app.exec())
