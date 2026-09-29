#!/usr/bin/env python3
"""Build and run local-only sandbox comparisons. Never uploads test reports."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import uuid

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--interactive', action='store_true', help='Wait for a real Control+Option+Shift+Command+V press in each sandbox variant')
args = parser.parse_args()
artifacts = Path(tempfile.mkdtemp(prefix='dockchord-sandbox-', dir='/private/tmp'))
reports = root / '.build/sandbox-reports'
reports.mkdir(parents=True, exist_ok=True)
cache = root / '.build/probe-module-cache'

def run(*command, **kwargs):
    subprocess.run(command, check=True, cwd=root, **kwargs)

def bundle(name, executable, identifier, entitlement=None):
    app = artifacts / (name + '.app')
    contents = app / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    shutil.copy2(executable, contents / 'MacOS' / name)
    with (contents / 'Info.plist').open('wb') as f:
        plistlib.dump({'CFBundleName': name, 'CFBundleIdentifier': identifier,
                      'CFBundleExecutable': name, 'CFBundlePackageType': 'APPL',
                      'CFBundleVersion': '1', 'LSUIElement': not name.startswith('ProbeTarget'),
                      'LSMinimumSystemVersion': '13.0'}, f)
    flags = ['--entitlements', str(entitlement)] if entitlement else []
    run('codesign', '--force', '--sign', '-', *flags, str(app))
    run('codesign', '--verify', '--strict', str(app))
    return app

run('swiftc', '-parse-as-library', '-module-cache-path', str(cache),
    'Sources/DockChord/Models.swift', 'Sources/DockChord/HotKeys.swift',
    'Tests/SandboxProbe/Probe.swift', '-o', str(artifacts / 'probe'))
run('swiftc', '-parse-as-library', '-module-cache-path', str(cache),
    'Tests/SandboxProbe/Helper.swift', '-o', str(artifacts / 'helper'))
variants = [('baseline', None), ('sandbox', root / 'Configuration/Sandbox.entitlements'),
            ('sandbox-dock', root / 'Configuration/SandboxDock.entitlements')]
for variant, entitlements in variants:
    if args.interactive and variant == 'baseline':
        continue
    helper = bundle('ProbeTarget-' + variant, artifacts / 'helper', 'io.github.code4vinitha.dockchord.probetarget.' + variant)
    identifier = 'io.github.code4vinitha.dockchord.probe.' + variant
    app = bundle('Probe-' + variant, artifacts / 'probe', identifier, entitlements)
    run_id = str(uuid.uuid4())
    options = ['--interactive'] if args.interactive else []
    print('Running ' + variant, flush=True)
    run('open', '-W', '-n', str(app), '--args', '--helper', str(helper),
        '--boundary-file', str(root / 'README.md'), '--run-id', run_id, *options, timeout=50)
    home = Path.home() / 'Library/Containers' / identifier / 'Data' if entitlements else Path.home()
    report_path = home / 'Library/Application Support/DockChordProbe/report.json'
    report = json.loads(report_path.read_text())
    if report.get('runID') != run_id:
        raise RuntimeError('Probe did not produce a fresh report: ' + variant)
    if entitlements and (not report['sandboxContainerHome'] or not report['outsideContainerReadDenied']):
        raise RuntimeError('Sandbox enforcement was not proven: ' + variant)
    suffix = '-interactive' if args.interactive else ''
    (reports / (variant + suffix + '.json')).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)
print('Reports saved to ' + str(reports))
