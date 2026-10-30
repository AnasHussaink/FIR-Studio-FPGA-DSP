# Packaging provenance

- RTL copied from the supplied project without functional edits.
- `tb_fir_python.sv`: replaced the original absolute Windows vector path with `fir_vectors.txt` for portability.
- `fir_reference.py`: resolves its output to this repository's `sim/data/fir_vectors.txt`.
- Other Python files and testbenches preserved.
- Tcl recreation, simulation and build helpers added; not executed in Vivado during packaging.
- Original screenshots, four hardware photographs, PDF, final run reports and original bitstream retained.
- Three full-length screen recordings re-encoded for ordinary GitHub storage; originals remain in the source folder.
- Original report describes an older dashboard and earlier standalone implementation measurements. Current README documents the supplied PySide6 FIR Studio application and distinguishes final integrated metrics.
- Generated Vivado cache, intermediate checkpoints and machine-specific `.xpr` omitted; recreate the project using Tcl.
- Documentation diagrams and video intro are explanatory visuals, not measured waveforms. Actual results use supplied evidence.
