#!/usr/bin/env python3
"""Run Ancient Nest regression tests with Godot 4.6.3.

Single-process tests run headless (or under Xvfb for *_native tests).
Network tests run as two separate Godot processes (host + client).

Usage:
  python3 authoring/run_tests.py [--godot godot] [--only name,name] [--skip-native]
"""
import argparse, os, re, subprocess, sys, time, pathlib, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent

SINGLE = [
    "smoke", "edge_cases", "expansion", "combat_timing", "combat_geometry",
    "combat_feedback", "aim_ballistics", "sound_combat", "grenade_audio",
    "crouch_regen_update", "player_polish", "compact_map", "bot_movement_polish",
    "ak47", "input_reliability", "traversal",
]
NATIVE = ["aim_input_native", "player_polish_native", "sound_native", "ui_native"]
PAIRS = [
    "network", "network_regression", "network_input", "network_combat_authority",
    "network_fair", "network_feedback", "network_recap", "network_ak47", "network_load",
]


USER_DIR = pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")) / "godot/app_userdata/Ancient Nest"


def reset_user_data():
    # Tests call start_game(), which persists user://custom_game.cfg. Without a
    # reset, one test's mode/round settings leak into the next test program.
    for name in ("custom_game.cfg", "preferences.cfg"):
        try:
            (USER_DIR / name).unlink()
        except FileNotFoundError:
            pass


def summarise(out: str) -> str:
    passes = len(re.findall(r"^PASS", out, re.M))
    fails = len(re.findall(r"FAIL", out))
    errs = len(re.findall(r"^(SCRIPT )?ERROR", out, re.M))
    return f"{passes} PASS lines, {fails} FAIL mentions, {errs} ERROR lines"


def run_single(godot, name, native, timeout, logdir):
    cmd = [godot, "--path", str(ROOT), "-s", f"tests/{name}.gd"]
    if native:
        if not shutil.which("xvfb-run"):
            return name, None, "skipped (no xvfb-run)"
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1440x900x24"] + cmd + ["--audio-driver", "Dummy"]
    else:
        cmd.insert(1, "--headless")
    reset_user_data()
    t = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        out, code = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        out, code = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or ""), "timeout"
    (logdir / f"{name}.log").write_text(out)
    return name, code, f"{summarise(out)} ({time.time()-t:.0f}s)"


def run_pair(godot, name, timeout, logdir, extra=()):
    base = [godot, "--headless", "--path", str(ROOT), "-s", f"tests/{name}.gd", "--"]
    reset_user_data()
    t = time.time()
    host = subprocess.Popen(base + ["host", *extra], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    time.sleep(1.0)
    client = subprocess.Popen(base + ["client", *extra], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    outs = {}
    for role, proc in (("host", host), ("client", client)):
        try:
            outs[role] = proc.communicate(timeout=timeout)[0]
        except subprocess.TimeoutExpired:
            proc.kill(); outs[role] = (proc.communicate()[0] or "") + "\n[runner] TIMEOUT"
    for role in outs:
        (logdir / f"{name}.{role}.log").write_text(outs[role])
    codes = (host.returncode, client.returncode)
    ok = codes == (0, 0)
    return name, 0 if ok else codes, f"host: {summarise(outs['host'])} | client: {summarise(outs['client'])} ({time.time()-t:.0f}s)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--only", default="")
    ap.add_argument("--skip-native", action="store_true")
    ap.add_argument("--logdir", default=str(ROOT / "output" / "test-logs"))
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args()
    logdir = pathlib.Path(a.logdir); logdir.mkdir(parents=True, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    pick = lambda names: [n for n in names if not only or n in only]
    results = []
    for n in pick(SINGLE):
        results.append(run_single(a.godot, n, False, a.timeout, logdir)); print(*results[-1], flush=True)
    if not a.skip_native:
        for n in pick(NATIVE):
            results.append(run_single(a.godot, n, True, a.timeout, logdir)); print(*results[-1], flush=True)
    for n in pick(PAIRS):
        results.append(run_pair(a.godot, n, a.timeout, logdir)); print(*results[-1], flush=True)
    bad = [r for r in results if r[1] not in (0,) and not str(r[2]).startswith("skipped")]
    print(f"\n{len(results)-len(bad)}/{len(results)} test programs exited 0. Logs: {logdir}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
