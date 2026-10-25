"""Export the integrated Windows game and package its runtime libraries and licenses.

Requires Godot 4.6.3, its matching export templates, and installed native addons.
The generated archive contains no server configuration or production credentials.
"""
import hashlib
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent / 'game'
OUTPUT = ROOT / 'dist' / 'windows'
GODOT = os.environ.get('GODOT_BIN', 'godot')


def build(output=OUTPUT, archive=None, executable_name='Ancient Nest.exe'):
    output = Path(output).resolve()
    archive = Path(archive).resolve() if archive else ROOT / 'dist' / 'Ancient-Nest-Windows.zip'
    if output.exists() or archive.exists():
        raise FileExistsError('Choose NEW output/archive paths. Existing builds and backups are preserved.')
    if Path(executable_name).name != executable_name or not executable_name.lower().endswith('.exe'):
        raise ValueError('Executable name must be a simple .exe filename.')
    version = subprocess.check_output([GODOT, '--version'], text=True).strip()
    if not version.startswith('4.6.3.stable.'):
        raise RuntimeError('Use Godot 4.6.3 and matching export templates for the pinned native addons.')
    extension = PROJECT / 'addons/discord_social_sdk/lib/windows'
    keyring = PROJECT / 'addons/keyring/bin/libkeyring.windows.template_release.x86_64.dll'
    if not keyring.is_file() or not (extension / 'discord_partner_sdk.dll').is_file():
        raise RuntimeError('Native dependencies missing. Run npm run discord:install first.')
    output.mkdir(parents=True)
    archive.parent.mkdir(parents=True, exist_ok=True)
    # Finish native addon imports before exporting from a fresh project cache.
    subprocess.run([GODOT, '--headless', '--path', str(PROJECT), '--editor', '--quit-after', '90'], check=True)
    executable = output / executable_name
    subprocess.run([GODOT, '--headless', '--path', str(PROJECT), '--export-release', 'Windows', str(executable)], check=True)
    if not executable.is_file() or executable.read_bytes()[:2] != b'MZ':
        raise RuntimeError('Windows executable was not produced.')
    # Include all SDK runtime DLLs, including the optional noise-suppression runtime.
    for name in ['discord_partner_sdk.dll', 'discord_krisp.dll']:
        shutil.copy2(extension / name, output / name)
    licenses = output / 'licenses'
    licenses.mkdir()
    for addon in ['discord_social_sdk', 'keyring', 'webrtc_native']:
        files = [p for p in (PROJECT / 'addons' / addon).rglob('*')
                 if p.is_file() and ('license' in p.name.lower() or 'notice' in p.name.lower())]
        if not files:
            raise RuntimeError(f'Missing {addon} license notices.')
        for index, source in enumerate(files):
            shutil.copy2(source, licenses / f'{addon}-{index}-{source.name}')
    for source in (ROOT / 'licenses').glob('Godot-*'):
        shutil.copy2(source, licenses / source.name)
    (output / 'Read me.txt').write_text(
        'ANCIENT NEST - PRIVATE DEVELOPMENT TEST\n\n'
        f'Extract this entire folder, then open {executable_name}.\n'
        'Keep the DLLs and licenses beside the executable. No Godot installation is required.\n'
        'Continue with Discord on first launch. Saved sign-in is tried\n'
        'automatically on later launches; a failed restore requires manual login.\n\n'
        'Development build. Live Discord and internet gameplay must be verified before release.\n'
        'The accounts Worker must be deployed and configured before online sign-in works.\n'
        'Discord voice requires approved app access and live audio testing.\n'
        'This build is unsigned. Windows startup/keyring checks run in GitHub Actions; live gameplay and audio still need testing.\n', encoding='utf8')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
        for source in sorted(output.rglob('*')):
            if source.is_file():
                out.write(source, Path('Ancient Nest Private Test') / source.relative_to(output))
    # Basic distribution validation: every native release library is shipped.
    with zipfile.ZipFile(archive) as out:
        if out.testzip() is not None:
            raise RuntimeError('Windows archive integrity check failed.')
        names = out.namelist()
        required = [executable_name, 'discord_partner_sdk.dll', 'discord_krisp.dll',
                    'discord_social_sdk.windows.template_release.x86_64.dll',
                    'libkeyring.windows.template_release.x86_64.dll', 'libwebrtc_native.windows.template_release.x86_64.dll']
        for name in required:
            if not any(Path(entry).name == name for entry in names):
                raise RuntimeError(f'Windows archive is missing {name}.')
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n', encoding='ascii')
    print(f'Windows download: {archive}\nSHA256: {digest}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--executable-name', default='Ancient Nest.exe')
    args = parser.parse_args()
    build(args.output, args.archive, args.executable_name)
