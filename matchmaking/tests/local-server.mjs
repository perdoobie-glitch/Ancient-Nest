import { Miniflare } from "miniflare";
import { fileURLToPath } from "node:url";
const root = fileURLToPath(new URL("../", import.meta.url));
const mf = new Miniflare({
  modules: true,
  scriptPath: root + "dist/worker.js",
  compatibilityDate: "2026-08-06",
  port: 18080,
  host: "127.0.0.1",
  durableObjects: { MATCHMAKER: { className: "Matchmaker", useSQLite: true } },
  bindings: {
    MONITOR_TOKEN: process.env.NEST_TEST_MONITOR_TOKEN || "local-test-monitor-key-not-for-production-0123456789",
    ALLOW_GUESTS: "true",
    LOCAL_TEST: "true",
    VOTE_SECONDS: "3",
    RELAY_ONLY: process.env.NEST_RELAY_ONLY || "false",
    LOCAL_ICE_JSON: process.env.NEST_LOCAL_ICE_JSON || "[]",
  },
  durableObjectsPersist:
    process.env.NEST_CF_STATE || root + ".local-test-state",
});
await mf.ready;
console.log("READY http://127.0.0.1:18080");
let stopping = false;
async function shutdown() {
  if (stopping) return;
  stopping = true;
  await mf.dispose();
  process.exit(0);
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
// Windows terminate() does not deliver SIGTERM to Node. The native test harness
// uses this private stdin pipe so workerd releases its SQLite files before exit.
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => {
  if (chunk.trim() === "shutdown") shutdown();
});
