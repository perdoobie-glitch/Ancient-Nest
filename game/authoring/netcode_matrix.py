#!/usr/bin/env python3
"""Run tests/network_netcode.gd as separate host and client Godot processes
through udp_impair.py for a matrix of RTT / jitter / loss settings.

Usage:
  python3 authoring/netcode_matrix.py [--godot godot] [--out DIR] [--only label,label] [--repeat N]
Writes DIR/<label>/{host,client}.json, logs, relay stats and DIR/summary.{json,md}.
"""
import argparse, json, math, os, pathlib, signal, subprocess, sys, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
HERE = pathlib.Path(__file__).resolve().parent

# label, rtt ms, jitter +/- ms per direction, loss % per direction
CONFIGS = [
    ("rtt0_clean", 0, 0, 0.0),
    ("rtt0_j5_l1", 0, 5, 1.0),
    ("rtt50_j5_l1", 50, 5, 1.0),
    ("rtt50_j10_l3", 50, 10, 3.0),
    ("rtt100_j10_l2", 100, 10, 2.0),
    ("rtt100_j15_l3", 100, 15, 3.0),
    ("rtt150_j15_l1", 150, 15, 1.0),
    ("rtt150_j20_l3", 150, 20, 3.0),
]

USER_DIR = pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")) / "godot/app_userdata/Ancient Nest"


def reset_user_data():
    for name in ("custom_game.cfg", "preferences.cfg"):
        try:
            (USER_DIR / name).unlink()
        except FileNotFoundError:
            pass


def percentile(values, q):
    if not values:
        return float("nan")
    v = sorted(values)
    k = (len(v) - 1) * q
    f = math.floor(k); c = math.ceil(k)
    return v[f] if f == c else v[f] + (v[c] - v[f]) * (k - f)


def interpolation_error(truth, samples):
    """Rendered remote position vs host truth at the same host time."""
    truth = sorted(truth)
    times = [t[0] for t in truth]
    errors = []
    import bisect
    for tv, x, y, z in samples:
        i = bisect.bisect_left(times, tv)
        if i <= 0 or i >= len(truth):
            continue
        a, b = truth[i - 1], truth[i]
        f = (tv - a[0]) / max(b[0] - a[0], 1e-9)
        tx, ty, tz = (a[k] + (b[k] - a[k]) * f for k in (1, 2, 3))
        errors.append(math.dist((x, y, z), (tx, ty, tz)))
    return {"samples": len(errors), "mean_m": sum(errors) / len(errors) if errors else float("nan"),
            "p95_m": percentile(errors, .95), "max_m": max(errors) if errors else float("nan")}


def run_config(godot, label, rtt, jitter, loss, index, outdir, timeout, seed):
    d = outdir / label
    d.mkdir(parents=True, exist_ok=True)
    host_port = 17950 + index
    relay_port = 18150 + index
    reset_user_data()
    relay = subprocess.Popen([sys.executable, str(HERE / "udp_impair.py"), "--listen", str(relay_port),
                              "--target", f"127.0.0.1:{host_port}", "--rtt", str(rtt), "--jitter", str(jitter),
                              "--loss", str(loss), "--seed", str(seed), "--stats", str(d / "relay.json")])
    base = [godot, "--headless", "--path", str(ROOT), "-s", "tests/network_netcode.gd", "--"]
    host = subprocess.Popen(base + ["host", str(host_port), str(host_port), str(d / "host.json"), label],
                            stdout=open(d / "host.log", "w"), stderr=subprocess.STDOUT)
    time.sleep(1.5)
    client = subprocess.Popen(base + ["client", str(host_port), str(relay_port), str(d / "client.json"), label],
                              stdout=open(d / "client.log", "w"), stderr=subprocess.STDOUT)
    started = time.time()
    for proc in (host, client):
        try:
            proc.wait(timeout=max(1, timeout - (time.time() - started)))
        except subprocess.TimeoutExpired:
            proc.kill()
    relay.send_signal(signal.SIGTERM)
    relay.wait(timeout=10)
    out = {"label": label, "rtt_ms": rtt, "jitter_ms": jitter, "loss_pct": loss,
           "host_exit": host.returncode, "client_exit": client.returncode, "seconds": round(time.time() - started, 1)}
    try:
        h = json.loads((d / "host.json").read_text()); c = json.loads((d / "client.json").read_text())
    except (FileNotFoundError, json.JSONDecodeError) as e:
        out["error"] = f"missing results: {e}"
        return out
    r = json.loads((d / "relay.json").read_text()) if (d / "relay.json").exists() else {}
    out["relay"] = {k: {"loss_pct": round(v.get("loss_pct", 0), 2), "mean_delay_ms": round(v.get("mean_delay_ms", 0), 1),
                        "reordered": v.get("reordered", 0), "packets": v.get("received", 0)}
                    for k, v in r.get("directions", {}).items()}
    out["checks"] = {"host": [h.get("checks", 0), h.get("failures", 0)], "client": [c.get("checks", 0), c.get("failures", 0)]}
    out["failed_checks"] = [f"{x['message']}" for side in (h, c) for x in side.get("checks_detail", []) if not x["ok"]]
    out["movement"] = {**c.get("A", {}), **{k: v for k, v in h.get("A", {}).items()}}
    out["disturbance"] = {**c.get("A2", {}), **{"host_" + k: v for k, v in h.get("A2", {}).items()}}
    out["lift"] = {**c.get("L", {}), **{"host_" + k: v for k, v in h.get("L", {}).items()}}
    out["interpolation"] = {**interpolation_error(h.get("B_truth", []), c.get("B_samples", [])), **c.get("B", {})}
    out["hits"] = h.get("C", {})
    out["cadence"] = h.get("D", {})
    hs, cs = h.get("stats", {}), c.get("stats", {})
    out["host_stats"] = {k: hs.get(k) for k in ("commands_lost", "filler_commands", "deferred_actions", "deferred_timeouts",
                                               "rewinds", "rewinds_clamped", "shots_rejected_cadence", "shots_rejected_origin",
                                               "shots_rejected_state", "command_packets_received", "commands_overflowed") if k in hs}
    out["client_stats"] = {k: cs.get(k) for k in ("corrections", "predictions_confirmed", "stalled_ack_adoptions",
                                                 "interp_delay_ms", "enet_rtt_ms", "max_correction_m") if k in cs}
    return out


def run_load(godot, label, rtt, jitter, loss, index, outdir, seed, seconds=10.0):
    """Ten actors (bots fill both teams) through the same impairment."""
    d = outdir / label
    host_port = 17970 + index; relay_port = 18170 + index
    reset_user_data()
    relay = subprocess.Popen([sys.executable, str(HERE / "udp_impair.py"), "--listen", str(relay_port),
                              "--target", f"127.0.0.1:{host_port}", "--rtt", str(rtt), "--jitter", str(jitter),
                              "--loss", str(loss), "--seed", str(seed + 100), "--stats", str(d / "load_relay.json")])
    base = [godot, "--headless", "--path", str(ROOT), "-s", "tests/network_load.gd", "--"]
    host = subprocess.Popen(base + ["host", str(host_port), str(host_port), str(d / "load_host.json"), str(seconds + 2)],
                            stdout=open(d / "load_host.log", "w"), stderr=subprocess.STDOUT)
    time.sleep(1.5)
    client = subprocess.Popen(base + ["client", str(host_port), str(relay_port), str(d / "load_client.json"), str(seconds)],
                              stdout=open(d / "load_client.log", "w"), stderr=subprocess.STDOUT)
    for proc in (client, host):
        try:
            proc.wait(timeout=90)
        except subprocess.TimeoutExpired:
            proc.kill()
    relay.send_signal(signal.SIGTERM); relay.wait(timeout=10)
    try:
        c = json.loads((d / "load_client.json").read_text())
    except (FileNotFoundError, json.JSONDecodeError) as e:
        return {"error": str(e), "client_exit": client.returncode}
    st = c.get("stats", {})
    ticks = st.get("interp_ticks", 0) + st.get("extrapolated_ticks", 0) + st.get("interp_underflow_ticks", 0)
    return {"client_exit": client.returncode, "host_exit": host.returncode, "valid": c.get("valid"), "actors": c.get("actors"),
            "snapshots_completed": c.get("snapshots_completed"), "snapshots_expected": c.get("snapshots_expected"),
            "extrapolated_pct": round(100 * st.get("extrapolated_ticks", 0) / ticks, 2) if ticks else None,
            "underflow_pct": round(100 * st.get("interp_underflow_ticks", 0) / ticks, 2) if ticks else None,
            "interp_delay_ms": round(st.get("interp_delay_ms", 0))}


def markdown(results):
    lines = ["| Config | Checks (host+client) | Disturbance (corrections, host fillers, final error, view offset) | Lift ride (corrections, final error, view offset) | Corrections / confirmed | Jumps client→host | Final error | Interp error mean / p95 | Extrapolated ticks | Hits comp ON | Hits comp OFF | Mean rewind | Full-auto accepted |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in results:
        if "error" in r:
            lines.append(f"| {r['label']} | ERROR: {r['error']} |" + " |" * 9)
            continue
        ch = r["checks"]; m = r["movement"]; i = r["interpolation"]; hits = r["hits"]; cs = r["client_stats"]
        on = hits.get("true", {}); off = hits.get("false", {})
        passed = ch["host"][0] + ch["client"][0] - ch["host"][1] - ch["client"][1]
        total = ch["host"][0] + ch["client"][0]
        dist = r.get("disturbance", {}); lift = r.get("lift", {})
        lines.append(
            f"| {r['label']} | {passed}/{total} | {dist.get('corrections','?')} corr, {dist.get('host_filler_commands','?')} fill, {dist.get('host_final_error_m',float('nan')):.4f} m, view ≤{dist.get('max_view_correction_m',float('nan')):.2f} m | {lift.get('corrections','?')} corr, {lift.get('host_final_error_m',float('nan')):.4f} m, view ≤{lift.get('max_view_correction_m',float('nan')):.2f} m | {m.get('corrections','?')} / {int(cs.get('predictions_confirmed',0))} | "
            f"{m.get('client_jumps','?')}→{m.get('host_jumps','?')} | {m.get('final_error_m',float('nan')):.4f} m | "
            f"{i['mean_m']:.3f} / {i['p95_m']:.3f} m | {i.get('extrapolated_ticks','?')} | "
            f"{on.get('hits','?')}/{on.get('fired','?')} | {off.get('hits','?')}/{off.get('fired','?')} | "
            f"{on.get('mean_rewind_ms',0):.0f} ms | {r['cadence'].get('accepted','?')}/{r['cadence'].get('fired','?')} |")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--out", default=str(ROOT / "output" / "netcode-matrix"))
    ap.add_argument("--only", default="")
    ap.add_argument("--timeout", type=int, default=240)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    outdir = pathlib.Path(a.out); outdir.mkdir(parents=True, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    results = []
    for index, (label, rtt, jitter, loss) in enumerate(CONFIGS):
        if only and label not in only:
            continue
        print(f"== {label}: RTT {rtt} ms, jitter ±{jitter} ms, loss {loss}%", flush=True)
        r = run_config(a.godot, label, rtt, jitter, loss, index, outdir, a.timeout, a.seed + index)
        r["load"] = run_load(a.godot, label, rtt, jitter, loss, index, outdir, a.seed + index)
        results.append(r)
        print(json.dumps({k: r.get(k) for k in ("checks", "failed_checks", "movement", "interpolation", "hits", "cadence", "relay")}, indent=1), flush=True)
    (outdir / "summary.json").write_text(json.dumps(results, indent=2))
    md = markdown(results)
    (outdir / "summary.md").write_text(md + "\n")
    md += "\n\n| Config | Ten-actor load: snapshots completed/expected | Extrapolated ticks | Interp buffer |\n|---|---|---|---|\n"
    for r in results:
        L = r.get("load", {})
        md += f"| {r['label']} | {L.get('snapshots_completed','?')}/{L.get('snapshots_expected','?')} | {L.get('extrapolated_pct','?')}% | {L.get('interp_delay_ms','?')} ms |\n"
    (outdir / "summary.md").write_text(md + "\n")
    print(md)
    bad = [r for r in results if "error" in r or r["host_exit"] != 0 or r["client_exit"] != 0 or r.get("load", {}).get("client_exit") != 0 or r.get("load", {}).get("host_exit") != 0 or not r.get("load", {}).get("valid", False)]
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
