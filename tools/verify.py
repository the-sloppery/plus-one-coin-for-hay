#!/usr/bin/env python3
"""Verify real command exits AND suite execution counts; writes a source-bound receipt."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luaudit-hook', type=Path)
    args = parser.parse_args()
    out = ROOT / 'outputs/verification'
    out.mkdir(parents=True, exist_ok=True)
    (ROOT / 'build').mkdir(exist_ok=True)
    def digest():
        candidates = sorted(p for folder in ('src', 'tests', 'tools') for p in (ROOT / folder).rglob('*') if p.is_file())
        candidates += [ROOT / name for name in ('default.project.json', 'rokit.toml', 'selene.toml', 'stylua.toml', '.luaurc')]
        return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in candidates}
    before = digest()
    commands = [
        ('format', ['stylua', '--check', 'src', 'tests', 'tools'], None),
        ('logic', ['lune', 'run', 'tests/run.luau'], r'RESULT 45 passed, 0 failed'),
        ('server', ['lune', 'run', 'tests/integration.luau'], r'RESULT 15 integrated server scenarios passed'),
        ('ui', ['lune', 'run', 'tests/ui.luau'], r'RESULT 8 UI scenarios passed'),
        ('sourcemap', ['rojo', 'sourcemap', 'default.project.json', '--output', 'sourcemap.json'], None),
        ('build', ['rojo', 'build', 'default.project.json', '-o', 'build/plus-one-coin-for-hay.rbxlx'], None),
    ]
    if args.luaudit_hook:
        commands.append(('luaudit', ['python3', str(args.luaudit_hook.resolve()), 'check', 'src', '--warnings'], None))
    elif shutil.which('luaudit'):
        commands.append(('luaudit', ['luaudit', 'check', 'src', '--warnings'], None))
    else:
        parser.error('luaudit is required; install it or provide --luaudit-hook')
    results = []
    for name, argv, expected in commands:
        result = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True, timeout=180)
        (out / f'{name}.log').write_text(result.stdout + result.stderr)
        ok = result.returncode == 0 and (expected is None or re.search(expected, result.stdout) is not None)
        results.append({'name': name, 'argv': argv, 'exitCode': result.returncode, 'expectedResultFound': ok})
        print(f'{name}: {"PASS" if ok else "FAIL"}', flush=True)
    artifact = ROOT / 'build/plus-one-coin-for-hay.rbxlx'
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True, capture_output=True)
    receipt = {'capturedAtUtc': datetime.now(timezone.utc).isoformat(), 'sourceCommit': revision.stdout.strip() if revision.returncode == 0 else None, 'sourceFiles': before,
        'sourceUnchanged': before == digest(), 'checks': results,
        'artifactSha256': hashlib.sha256(artifact.read_bytes()).hexdigest() if artifact.exists() else None,
        'nativeStudio': 'not-run', 'liveTeleportAndPersistence': 'not-run'}
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    raise SystemExit(0 if receipt['sourceUnchanged'] and all(row['expectedResultFound'] for row in results) else 1)

if __name__ == '__main__':
    main()
