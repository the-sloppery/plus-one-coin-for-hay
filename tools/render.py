#!/usr/bin/env python3
"""Export the production modules and capture RHR results using an installed runtime."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
out = root / 'outputs/render'
out.mkdir(parents=True, exist_ok=True)
results = []
for mode in ('lobby', 'field', 'contracts', 'equipment', 'group'):
    subprocess.run(['lune', 'run', 'tools/export.luau', mode], cwd=root, check=True)
    command = [sys.executable, '-m', 'rhr', 'check', str(out / f'{mode}.rbxm'), '--devices', 'all']
    result = subprocess.run(command, cwd=root, capture_output=True, text=True)
    (out / f'{mode}-check.json').write_text(result.stdout)
    (out / f'{mode}-check.stderr').write_text(result.stderr)
    results.append({'mode': mode, 'exitCode': result.returncode})
    for device in ('phone', 'desktop'):
        subprocess.run([sys.executable, '-m', 'rhr', 'ui', str(out / f'{mode}.rbxm'), '--device', device, '--max-size', '800', '--out', str(out / f'{mode}-{device}.png')], cwd=root, check=True)
for scene in ('lobby', 'field'):
    subprocess.run([sys.executable, '-m', 'rhr', 'scene', str(out / f'{scene}-scene.rbxm'), '--view', 'iso', '--max-size', '800', '--out', str(out / f'{scene}-scene.png'), '--json'], cwd=root, check=True, stdout=(out / f'{scene}-scene.json').open('w'))
(out / 'receipt.json').write_text(json.dumps(results, indent=2) + '\n')
if any(row['exitCode'] != 0 for row in results):
    raise SystemExit('RHR check failed; inspect findings.')
