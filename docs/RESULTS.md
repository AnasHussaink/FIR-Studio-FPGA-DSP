# Results and evidence

## Earlier standalone designs: post-synthesis comparison

| Metric | Fixed baseline | Fixed pipelined | Programmable pipelined |
|---|---:|---:|---:|
| LUTs | 51 | 58 | 153 |
| Registers | 33 | 87 | 96 |
| Setup WNS | +3.190 ns | +5.576 ns | +4.230 ns |

These figures come from the supplied screenshots and original report. Baseline-to-pipeline setup margin increases by **2.386 ns (74.8%)**, with 7 additional LUTs and 54 additional registers. This is a timing-margin comparison at the same 10 ns target, not a 74.8% frequency or throughput increase.

The report records standalone programmable FIR post-route WNS +3.402 ns and hold slack +0.221 ns, with 2 DSP48E1s. Keep this separate from the full integrated design below.

## Final FIR + UART implementation

| Metric | Saved final report |
|---|---:|
| Clock constraint | 10 ns / 100 MHz |
| LUTs | 229 |
| Registers | 210 |
| Slices | 85 |
| DSP48E1 blocks | 2 |
| Post-route setup WNS | +3.280 ns |
| Post-route hold WHS | +0.032 ns |
| Failing setup / hold endpoints | 0 / 0 |

See [timing report](reports/fir_uart_top_timing_summary_routed.rpt) and [utilization report](reports/fir_uart_top_utilization_placed.rpt). The reports flag two inputs without input delay and one output without output delay; passed internal constraints are not a complete external-interface timing guarantee. The included power report is an estimate, not measured board power.

## Verification evidence

| Campaign | Supplied evidence |
|---|---|
| Moving-average checks | Report records 6 passing examples |
| Fixed-point FIR | Report records 9 passing checks |
| Baseline versus pipeline | Report records 20 passing comparisons |
| Python vectors versus both RTLs | 213 vector rows; report records 432 checks including flush cycles |
| Programmable FIR | Report records 16 checked cycles |
| UART simulation | Saved simulator log: received ASCII A, loopback passed |
| Physical FIR | Screenshot: eight matching signed-sample results |
| Physical coefficient update | Screenshot: initial state mismatch, then eight matches after BTN0 reset |
| Original dashboard | Screenshot: 13 samples, 13 matches, zero mismatches |
| New FIR Studio | Recordings show additional sessions, including a 130/130 comparison table and a separate 128-sample plot |

Do not add counters from different recordings into a single claimed test total. This repository preserves supplied evidence; hardware tests and Vivado simulations were not rerun during packaging.

## Current boundaries

Four taps and 8-bit I/O are fixed in this implementation. Output wraps on overflow. UART is stop-and-wait; no sustained external streaming benchmark is supplied. Results demonstrate the shown test cases, not exhaustive formal verification.
