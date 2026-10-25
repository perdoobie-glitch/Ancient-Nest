// ../game/data/network_defaults.json
var network_defaults_default = {
  host_heartbeat_seconds: 20,
  host_stale_seconds: 60,
  browser_refresh_seconds: 15,
  queue_fallback_seconds: 5,
  request_timeout_seconds: 10,
  retry_cap_seconds: 30,
  socket_keepalive_seconds: 20,
  socket_stale_seconds: 90,
  authority_lease_seconds: 60,
  continuity_seconds: 5,
  clock_skew_seconds: 2,
  simulation_hz: 60,
  input_hz: 60,
  snapshot_min_hz: 20,
  snapshot_max_hz: 30
};

// src/control_policy.ts
var CONTROL = Object.freeze(network_defaults_default);
function retryDelay(attempt, random = 0.5, retryAfter2 = 0) {
  return Math.max(retryAfter2, Math.min(CONTROL.retry_cap_seconds, 2 ** Math.min(8, Math.max(0, attempt))) * (0.5 + 0.5 * Math.max(0, Math.min(1, random))));
}
function retryAfter(value, time = Date.now()) {
  if (!value) return 0;
  const seconds = Number(value);
  return Number.isFinite(seconds) ? Math.max(0, seconds) : Math.max(0, (Date.parse(value) - time) / 1e3) || 0;
}
function hostAvailable(received, time) {
  return Number.isFinite(received) && received > 0 && time - received < CONTROL.host_stale_seconds;
}
function validHostUpdate(update, epoch, revision) {
  return update.epoch === epoch && Number.isSafeInteger(update.revision) && update.revision > revision;
}
function nextAlarm(time, deadlines) {
  return Math.max(time + 0.1, Math.min(time + 30, ...deadlines.filter((d) => Number.isFinite(d) && d > time)));
}
export {
  CONTROL,
  hostAvailable,
  nextAlarm,
  retryAfter,
  retryDelay,
  validHostUpdate
};
