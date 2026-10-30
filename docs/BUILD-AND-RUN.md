# Build and run

## Tools and hardware

- Digilent Arty Artix-7 35T board, USB data cable and PC.
- Vivado with Artix-7 device support. Original project: Vivado 2026.1, `xc7a35ticsg324-1L`.
- Python 3.10 or newer (the GUI uses modern type annotations); Python 3.12 was documented for the original workflow.
- Python packages listed in `requirements.txt`. Versions are not pinned because the original environment lockfile was not supplied.

## 1. Python environment

From the repository root in PowerShell:

```powershell
py -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe software/fir_reference.py
```

The generator writes 213 deterministic sample/valid/expected rows to `sim/data/fir_vectors.txt`.

## 2. Recreate the FPGA project

Start Vivado, open the Tcl console and change to this repository directory. Use forward slashes and braces around paths containing spaces:

```tcl
cd {D:/your/path/FIR-Studio-FPGA-DSP}
source scripts/create_project.tcl
```

This creates `build/vivado/fir_studio.xpr`, adds RTL, all testbenches and the board XDC, and selects `fir_uart_top`. Do not use the board-pin XDC to implement the standalone arithmetic modules: their external ports differ.

These portable Tcl scripts were prepared during packaging and require validation in your Vivado installation; Vivado was not available on the packaging command path. Original saved reports and bitstream are included separately.

## 3. Simulate

```tcl
set testbench tb_fir_python
source scripts/run_sim.tcl
set testbench tb_fir_programmable
source scripts/run_sim.tcl
set testbench tb_uart_loopback
source scripts/run_sim.tcl
```

Other available tops: `tb_fir_moving_average`, `tb_fir_fixed_point`, `tb_fir_compare`. Each testbench is a separate simulation. The script copies vectors to XSim's working directory before launch. If launching simulation manually, put `fir_vectors.txt` in the simulation working directory. Review the simulator output for PASS messages and `$error`/`$fatal` messages; GUI launch alone does not indicate success.

## 4. Build and program

```tcl
source scripts/build_bitstream.tcl
```

After successful completion, the generated file is `build/vivado/fir_studio.runs/impl_1/fir_uart_top.bit`.

Connect the board by USB. In Hardware Manager select **Open Target → Auto Connect → Program Device**, then choose the generated bitstream. The original tested bitstream is also available under `hardware/prebuilt/` for the matching device and pinout.

## 5. Run FIR Studio

```powershell
.venv\Scripts\python.exe software/fir_interactive.py
```

1. Press and release **BTN0** on the board before a new session.
2. Refresh/select your USB-UART port. COM5 was used in the original project; your port can differ.
3. Connect and confirm the physical reset in the prompt.
4. Send a signed sample from -128 to 127, or choose a test sequence.
5. Compare input, FPGA output and Python expected output in **Waveforms**.
6. Choose a preset or enter four coefficients, then click **Apply coefficients to FPGA**. Selecting a preset alone does not transmit it.
7. Review **Measurements**, **Frequency & Error**, and **Event log**; export recorded results to CSV.

Only one application may own the serial port. Close FIR Studio before running `software/fir_hardware_test.py` or `software/uart_loopback_test.py`; edit their COM5 setting if necessary. The loopback script needs a separately built `uart_loopback_top` bitstream, not the final FIR protocol bitstream.

## State and recovery

Coefficient loading does **not** clear sample history. Clear charts only clears displayed records. After a reset, timeout or mismatch: disconnect, press/release BTN0 and reconnect so both reference and FPGA start with zero history and default coefficients. The protocol has no software reset command.

## Troubleshooting

| Symptom | Check |
|---|---|
| No COM port | USB data cable, USB-UART driver and board power |
| Serial port busy | Close another GUI, terminal or test script |
| No response | Correct bitstream, port, 115200 baud and board reset |
| First outputs mismatch | Reset board and reconnect; coefficient changes retain history |
| Cannot open vector file | Run simulation helper or copy vectors to XSim working directory |
| Missing Python module | Install requirements using the same interpreter used to launch the GUI |
| Clock is unconstrained | Confirm `create_clock -period 10.000` in the XDC and `fir_uart_top` as top |
