"""Checksum-verified Godot tooling for Windows CI; never contains game credentials."""
from pathlib import Path
import hashlib
import os
import shutil
import tempfile
import urllib.request
import zipfile

VERSION='4.6.3-stable'
BASE='https://github.com/godotengine/godot-builds/releases/download/'+VERSION+'/'
ASSETS={
 'Godot_v4.6.3-stable_win64.exe.zip':'e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90',
 'Godot_v4.6.3-stable_export_templates.tpz':'3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8',
}

def main():
    if os.name!='nt': raise RuntimeError('This installer is for Windows CI.')
    tools=Path(os.environ['RUNNER_TEMP'])/'godot-4.6.3'
    tools.mkdir(parents=True,exist_ok=True)
    for name,expected in ASSETS.items():
        archive=tools/name
        digest=hashlib.sha256()
        with urllib.request.urlopen(BASE+name,timeout=60) as response, archive.open('wb') as out:
            while chunk:=response.read(4*1024*1024):
                digest.update(chunk);out.write(chunk)
        if digest.hexdigest()!=expected: raise RuntimeError('Godot archive checksum mismatch')
        with zipfile.ZipFile(archive) as z:
            if name.endswith('.tpz'):
                dest=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable'
                dest.mkdir(parents=True,exist_ok=True)
                for entry in ['templates/windows_release_x86_64.exe','templates/version.txt']:
                    (dest/Path(entry).name).write_bytes(z.read(entry))
            else:
                for entry in z.namelist():
                    if entry.endswith('.exe'):
                        (tools/Path(entry).name).write_bytes(z.read(entry))
        archive.unlink()
    console=tools/'Godot_v4.6.3-stable_win64_console.exe'
    if not console.is_file(): raise RuntimeError('Godot console executable missing')
    with open(os.environ['GITHUB_ENV'],'a',encoding='utf8') as out: out.write('GODOT_BIN='+str(console)+'\n')
    print('Installed verified Godot Windows tooling.')

if __name__=='__main__': main()
