"""Install downloaded native dependencies into the canonical game. Never downloads secrets."""
from pathlib import Path
import shutil, os
ROOT=Path(__file__).resolve().parents[1]
def copy(source,destination):
    if Path(destination).exists():return str(destination)
    try:os.link(source,destination)
    except OSError:shutil.copy2(source,destination)
    return str(destination)
for name in ['discord_social_sdk','keyring']:
    source=ROOT/'ancient-nest-accounts/godot-client/addons'/name
    destination=ROOT/'game/addons'/name
    if not source.is_dir():raise SystemExit('Run python ancient-nest-accounts/scripts/install-discord-sdk.py first.')
    if destination.is_symlink():destination.unlink()
    shutil.copytree(source,destination,dirs_exist_ok=True,copy_function=copy)
print('Native Discord and keyring dependencies installed in game/addons.')
