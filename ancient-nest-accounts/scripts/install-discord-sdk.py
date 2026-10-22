"""Install the pinned Godot Discord Social SDK binding, including its desktop runtimes."""
import hashlib
import io
from pathlib import Path
import urllib.request
import zipfile

URL = "https://github.com/thiagola92/discord-social-sdk/releases/download/5.0.0/discord_social_sdk.zip"
SHA256 = "e3b87af14f6d2753877cfb3646927e38db620ae1019b20ddbd6b0c6c69f996d6"
ROOT = Path(__file__).resolve().parents[1] / "godot-client"
PREFIX = "demo/addons/discord_social_sdk/"

def main():
    with urllib.request.urlopen(URL, timeout=30) as response:
        data = response.read(32 * 1024 * 1024)
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise RuntimeError("Discord addon checksum mismatch; nothing installed")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if sum(item.file_size for item in archive.infolist()) > 128 * 1024 * 1024:
            raise RuntimeError("Addon unexpectedly large")
        for item in archive.infolist():
            if not item.filename.startswith(PREFIX) or item.is_dir():
                continue
            relative = Path(item.filename.removeprefix("demo/"))
            if ".." in relative.parts or relative.is_absolute():
                raise RuntimeError("Unsafe archive path")
            destination = ROOT / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(archive.read(item))
    print("Installed Discord Social SDK Godot binding 5.0.0 (Windows/Linux x86_64).")
    notices_url = "https://raw.githubusercontent.com/thiagola92/discord-social-sdk/995540a18ff102af85abc0a8ef67dce5bcdbd3ad/sdk/License-Notices.txt"
    with urllib.request.urlopen(notices_url, timeout=30) as response:
        notices = response.read(2 * 1024 * 1024)
    if hashlib.sha256(notices).hexdigest() != "e8afa66340c225431e69768543cc34a7240f3494a9d759189fe118620ea8eebf":
        raise RuntimeError("SDK notices checksum mismatch")
    (ROOT / "addons/discord_social_sdk/SDK-License-Notices.txt").write_bytes(notices)
    keyring_url = "https://github.com/shomykohai/godot-keyring/releases/download/1.0.0/libkeyring_stable.zip"
    with urllib.request.urlopen(keyring_url, timeout=30) as response:
        keyring = response.read(8 * 1024 * 1024)
    if hashlib.sha256(keyring).hexdigest() != "1e1711d0dba08472d5d2f6f19c4921ec973f13a94f467bb4a9dfcbba224784c5":
        raise RuntimeError("Keyring checksum mismatch; keyring not installed")
    with zipfile.ZipFile(io.BytesIO(keyring)) as archive:
        if sum(item.file_size for item in archive.infolist()) > 32 * 1024 * 1024:
            raise RuntimeError("Keyring addon unexpectedly large")
        for item in archive.infolist():
            if not item.filename.startswith("addons/keyring/") or item.is_dir():
                continue
            relative = Path(item.filename)
            if ".." in relative.parts or relative.is_absolute():
                raise RuntimeError("Unsafe keyring archive path")
            destination = ROOT / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(archive.read(item))
    print("Installed Godot Keyring 1.0.0 (Windows/Linux x86_64).")
    # These packaged native libraries do not need editor hot reload.
    for extension in (ROOT / "addons/discord_social_sdk/lib/discord.gdextension", ROOT / "addons/keyring/keyring.gdextension"):
        extension.write_text(extension.read_text().replace("reloadable = true", "reloadable = false"))

if __name__ == "__main__":
    main()
