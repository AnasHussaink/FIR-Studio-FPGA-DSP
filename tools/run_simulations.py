"""Run hardware-free regression testbenches using Icarus Verilog."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
build = root / 'build' / 'simulation'
build.mkdir(parents=True, exist_ok=True)
for tool in ('iverilog', 'vvp'):
    if not shutil.which(tool):
        raise SystemExit(f'Install {tool} and add it to PATH.')
subprocess.run([sys.executable, str(root / 'software/fir_reference.py')], check=True)
shutil.copyfile(root / 'sim/data/fir_vectors.txt', build / 'fir_vectors.txt')
rtl = sorted(str(p) for p in (root / 'rtl').glob('*.sv'))
for top in ('tb_fir_python', 'tb_fir_programmable', 'tb_uart_loopback'):
    executable = build / f'{top}.vvp'
    subprocess.run(['iverilog', '-g2012', '-s', top, '-o', str(executable),
                    *rtl, str(root / 'sim' / f'{top}.sv')], check=True)
    result = subprocess.run(['vvp', str(executable)], cwd=build, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=60)
    print(result.stdout)
    # Some simulators print $error but return zero; reject that outcome too.
    if result.returncode or 'ERROR:' in result.stdout or 'FATAL:' in result.stdout:
        raise SystemExit(f'{top} failed')
    if 'PASSED' not in result.stdout:
        raise SystemExit(f'{top} did not report successful checks')
print('All three simulation regressions passed.')
