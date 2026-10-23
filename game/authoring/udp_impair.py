#!/usr/bin/env python3
"""UDP impairment relay for Ancient Nest network tests.

Client --> relay(listen_port) --> host(target_port), and back.
Each datagram, in each direction independently:
  * is dropped with probability loss_pct/100 (independent, per packet);
  * otherwise is delivered after rtt/2 + uniform(-jitter, +jitter) milliseconds
    (never negative). Packets can therefore arrive out of order, as on real
    jittery links.

Usage:
  python3 udp_impair.py --listen 18000 --target 127.0.0.1:17950 \
      --rtt 100 --jitter 10 --loss 2 --seed 7 --stats out.json
Stops on SIGTERM/SIGINT and writes per-direction counters to --stats.
"""
import argparse, heapq, json, random, selectors, signal, socket, time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", type=int, required=True)
    ap.add_argument("--target", required=True)
    ap.add_argument("--rtt", type=float, default=0.0, help="round-trip delay in ms (split evenly)")
    ap.add_argument("--jitter", type=float, default=0.0, help="+/- ms added per packet per direction")
    ap.add_argument("--loss", type=float, default=0.0, help="percent of packets dropped per direction")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--stats", default="")
    a = ap.parse_args()
    host, port = a.target.rsplit(":", 1)
    target = (host, int(port))
    rng = random.Random(a.seed)
    one_way = a.rtt / 2000.0
    jitter = a.jitter / 1000.0
    loss = a.loss / 100.0

    sel = selectors.DefaultSelector()
    front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    front.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1 << 20)
    front.bind(("127.0.0.1", a.listen))
    front.setblocking(False)
    sel.register(front, selectors.EVENT_READ, ("front", None))
    upstream = {}  # client addr -> socket to host
    queue = []     # (deliver_at, order, sock, payload, addr, direction)
    order = 0
    stats = {d: {"received": 0, "dropped": 0, "delivered": 0, "bytes": 0, "delay_ms_sum": 0.0, "reordered": 0}
             for d in ("to_host", "to_client")}
    last_deliver_at = {"to_host": 0.0, "to_client": 0.0}
    running = True

    def stop(*_):
        nonlocal running
        running = False
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def schedule(sock, payload, addr, direction):
        nonlocal order
        s = stats[direction]
        s["received"] += 1
        if rng.random() < loss:
            s["dropped"] += 1
            return
        delay = max(0.0, one_way + rng.uniform(-jitter, jitter))
        at = time.monotonic() + delay
        if at < last_deliver_at[direction]:
            s["reordered"] += 1
        last_deliver_at[direction] = max(last_deliver_at[direction], at)
        s["delay_ms_sum"] += delay * 1000
        order += 1
        heapq.heappush(queue, (at, order, sock, payload, addr, direction))

    while running:
        timeout = 0.002
        if queue:
            timeout = max(0.0, min(timeout, queue[0][0] - time.monotonic()))
        for key, _ in sel.select(timeout):
            kind, client = key.data
            sock = key.fileobj
            while True:
                try:
                    payload, addr = sock.recvfrom(65535)
                except BlockingIOError:
                    break
                if kind == "front":
                    up = upstream.get(addr)
                    if up is None:
                        up = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                        up.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1 << 20)
                        up.bind(("127.0.0.1", 0))
                        up.setblocking(False)
                        sel.register(up, selectors.EVENT_READ, ("up", addr))
                        upstream[addr] = up
                    schedule(up, payload, target, "to_host")
                else:
                    schedule(front, payload, client, "to_client")
        now = time.monotonic()
        while queue and queue[0][0] <= now:
            _, _, sock, payload, addr, direction = heapq.heappop(queue)
            try:
                sock.sendto(payload, addr)
                stats[direction]["delivered"] += 1
                stats[direction]["bytes"] += len(payload)
            except OSError:
                pass
    if a.stats:
        for s in stats.values():
            kept = s["received"] - s["dropped"]
            s["mean_delay_ms"] = s["delay_ms_sum"] / kept if kept else 0.0
            s["loss_pct"] = 100.0 * s["dropped"] / s["received"] if s["received"] else 0.0
        with open(a.stats, "w") as f:
            json.dump({"rtt_ms": a.rtt, "jitter_ms": a.jitter, "loss_pct": a.loss, "directions": stats}, f, indent=2)


if __name__ == "__main__":
    main()
