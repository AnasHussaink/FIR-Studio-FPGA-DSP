# Architecture and protocol

## Data path

The four-tap filter computes `total = H0*x[n] + H1*x[n-1] + H2*x[n-2] + H3*x[n-3]`. Samples and stored coefficients are signed 8-bit integers. Coefficients represent Q1.7 values, so output scaling divides by 128 with an arithmetic right shift.

Products are 16 bits, pairwise sums 17 bits and the final sum 18 bits. The output is the low signed 8 bits after shifting; **overflow wraps, it does not saturate**. Arithmetic shifting rounds negative non-integer results toward negative infinity. The GUI reference explicitly models signed 8-bit wrapping.

| Pipeline stage | Operation |
|---|---|
| 1 | Register four products; update three-sample history on `sample_valid` |
| 2 | Register two sign-extended partial sums |
| 3 | Add partial sums, shift and register output |

A sample captured at edge 1 appears after edge 3. Valid flags follow the data. The standalone core can accept a sample each clock, but the integrated UART controller serialises requests and replies. The 100 MHz clock does not imply 100 million samples/second through the PC interface.

## Coefficients

Default integers `[16,48,48,16]` represent `[0.125,0.375,0.375,0.125]`; average `[32,32,32,32]` represents four weights of 0.25. Reset restores defaults and clears history. Loading coefficients preserves history. A sample captured on the same edge as `coeff_load` uses the old coefficients due to nonblocking assignments.

## UART protocol

100 MHz clock; 868 clock cycles per UART bit; nominal 115200 baud, 8N1. UART RX has a two-register input synchronizer. The top-level FSM receives complete commands, waits for the FIR output and completes transmission before accepting the next command.

| Request | Bytes sent | Response |
|---|---|---|
| Sample | ASCII `S` (0x53), then one signed sample encoded as a byte | One signed 8-bit result |
| Coefficients | ASCII `C` (0x43), then four signed coefficient bytes | ASCII `K` (0x4B) |

Negative integers use two's-complement byte encoding (`value & 255`). There is no packet checksum, FIFO streaming or UART reset command. Wait for each reply before sending another request.

## Hardware pinout

| Port | Package pin | Role |
|---|---|---|
| clk | E3 | 100 MHz oscillator |
| uart_rx_pin | A9 | PC to FPGA |
| uart_tx_pin | D10 | FPGA to PC |
| reset | D9 | BTN0, active-high reset |

All listed ports use LVCMOS33. USB supplies power and provides separate logical JTAG and UART paths. No external analogue sensor or ADC is used in this demonstration: the PC supplies numeric samples.

## Desktop application

PySide6 handles the interface, pyqtgraph draws traces, NumPy produces test sequences and response calculations, and PySerial communicates with the board. A worker thread performs one serial transaction at a time. The software compares each result to its reference and stops further requests after a mismatch or communication error.

The frequency-response view is calculated from coefficients; it is not an instrument measurement. Host transaction timing includes UART, operating-system and software overhead; it is not a direct measurement of FPGA pipeline latency.
