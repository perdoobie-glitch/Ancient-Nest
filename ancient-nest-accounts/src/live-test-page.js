export const testPage = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Ancient Nest service test</title>
<link rel="stylesheet" href="/setup-test.css">
<main><h1>Ancient Nest service test</h1>
<p>Use your own email and phone to test real delivery. Creating an account sends verification messages and may incur provider charges. Tokens stay in this page's memory. Sign out when finished.</p>
<button id="health">Check configuration</button><pre id="health-status" aria-live="polite"></pre>
<h2>Account</h2><form id="account-form">
<label>Username<input id="username" autocomplete="username" minlength="3" maxlength="24" required></label>
<label>Password<input id="password" type="password" autocomplete="current-password" minlength="8" maxlength="128" required></label>
<label>Email (required for new accounts)<input id="email" type="email" autocomplete="email" maxlength="254"></label>
<label>Phone with country code (required for new accounts)<input id="phone" type="tel" autocomplete="tel" placeholder="+12345678900" maxlength="32"></label>
<div><button type="submit" id="register">Create account / send codes</button><button type="submit" id="login">Sign in</button></div></form>
<p id="status" role="status"></p><pre id="account-status"></pre>
<h2>Verify real delivery</h2><p>Enter the codes you actually received. A successful send request alone does not prove delivery.</p>
<label>Email code<input id="email-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></label>
<button data-verify="email">Verify email</button> <button data-resend="email">Resend email</button>
<label>SMS code<input id="phone-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code"></label>
<button data-verify="phone">Verify phone</button> <button data-resend="phone">Resend SMS</button>
<h2>Session and Discord identity</h2><button id="refresh">Test saved-session refresh</button>
<button id="profile">Refresh account status</button><button id="discord">Get Discord linking URL</button>
<a id="discord-link" hidden target="_blank" rel="noopener noreferrer">Authorize Discord</a>
<button id="logout">Sign out this test session</button>
<p>This page tests accounts, delivery and Discord linking. Windows credential storage and two-player audio require the Windows client. Team assignment must come from the trusted coordinator.</p>
</main><script src="/setup-test.js" defer></script></html>`;

export const testCss = `:root{color-scheme:dark;font:16px system-ui}body{margin:0;background:#111c29;color:#edf3f8}main{max-width:760px;margin:auto;padding:24px}label{display:block;margin:12px 0}input{display:block;box-sizing:border-box;width:100%;padding:10px;margin-top:5px}button,a{display:inline-block;margin:5px 8px 5px 0;padding:10px;cursor:pointer}button:disabled{opacity:.5}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#1b2b3d;padding:12px;border-radius:6px}p{line-height:1.5}#status{min-height:24px}`;

export const testScript = `"use strict";
let session = null;
let busy = false;
const el = id => document.getElementById(id);
async function api(path, method = 'GET', data, authorized = true) {
  const headers = {};
  if (data !== undefined) headers['Content-Type'] = 'application/json';
  if (authorized && session) headers.Authorization = 'Bearer ' + session.token;
  const response = await fetch(path, { method, headers, cache: 'no-store', redirect: 'error',
    body: data === undefined ? undefined : JSON.stringify(data), signal: AbortSignal.timeout(15000) });
  const value = await response.json();
  if (!response.ok) throw new Error(value.error || ('HTTP ' + response.status));
  return value;
}
async function action(callback) {
  if (busy) return;
  busy = true;
  document.querySelectorAll('button').forEach(button => { button.disabled = true; });
  el('status').textContent = 'Working…';
  try { await callback(); }
  catch (error) { el('status').textContent = 'Test stopped: ' + error.message; }
  finally {
    busy = false;
    document.querySelectorAll('button').forEach(button => { button.disabled = false; });
  }
}
function requireSession() { if (!session) throw new Error('Sign in or create an account first.'); }
async function profile() {
  requireSession();
  const value = await api('/account');
  el('account-status').textContent = JSON.stringify(value, null, 2);
}
el('account-form').addEventListener('submit', event => {
  event.preventDefault();
  const register = event.submitter?.id !== 'login';
  action(async () => {
    if (session) throw new Error('Sign out the current test session before signing into another account.');
    const data = { username: el('username').value.trim(), password: el('password').value };
    if (register) { data.email = el('email').value.trim(); data.phone = el('phone').value.trim(); }
    try { session = await api(register ? '/register' : '/login', 'POST', data, false); }
    finally { el('password').value = ''; }
    await profile();
    el('status').textContent = session.send_errors?.length
      ? 'Account created, but sending failed: ' + JSON.stringify(session.send_errors)
      : (register ? 'Account created. Check your email and phone, then verify the received codes.' : 'Signed in.');
  });
});
document.querySelectorAll('[data-verify]').forEach(button => button.addEventListener('click', () => action(async () => {
  requireSession();
  const type = button.dataset.verify;
  const code = el(type + '-code').value.trim();
  if (!/^\\d{6}$/.test(code)) throw new Error('Enter the six-digit code you received.');
  await api('/verify/' + type, 'POST', { code });
  el(type + '-code').value = '';
  await profile();
  el('status').textContent = type + ' delivery and verification passed.';
})));
document.querySelectorAll('[data-resend]').forEach(button => button.addEventListener('click', () => action(async () => {
  requireSession();
  await api('/verify/' + button.dataset.resend + '/resend', 'POST', {});
  el('status').textContent = 'Provider accepted the send request. Verify the new code when it arrives.';
})));
el('health').addEventListener('click', () => action(async () => {
  const checks = {};
  for (const path of ['/ready', '/discord/ready']) {
    const response = await fetch(path, { cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) });
    checks[path] = { http_status: response.status, ...await response.json() };
  }
  el('health-status').textContent = JSON.stringify(checks, null, 2);
  el('status').textContent = 'Configuration checked. Delivery and audio must be tested separately.';
}));
el('profile').addEventListener('click', () => action(async () => { await profile(); el('status').textContent = 'Account status updated.'; }));
el('refresh').addEventListener('click', () => action(async () => {
  requireSession();
  session = await api('/refresh', 'POST', { refresh_token: session.refresh_token }, false);
  await profile();
  el('status').textContent = 'Session refresh passed. Windows saved sign-in is tested in the client.';
}));
el('discord').addEventListener('click', () => action(async () => {
  requireSession();
  const value = await api('/auth/discord');
  const url = new URL(value.url);
  if (url.origin !== 'https://discord.com' || url.pathname !== '/oauth2/authorize') throw new Error('Unexpected authorization URL.');
  el('discord-link').href = url.href;
  el('discord-link').hidden = false;
  el('status').textContent = 'Use Authorize Discord, then refresh account status after returning.';
}));
el('logout').addEventListener('click', () => action(async () => {
  requireSession();
  await api('/logout', 'POST', { refresh_token: session.refresh_token }, false);
  session = null;
  el('account-status').textContent = '';
  el('discord-link').hidden = true;
  el('discord-link').removeAttribute('href');
  el('status').textContent = 'Test session revoked and removed from this page.';
}));`;

export function liveTestRoute(path) {
  const files = { '/setup-test': [testPage, 'text/html; charset=utf-8'],
    '/setup-test.js': [testScript, 'text/javascript; charset=utf-8'],
    '/setup-test.css': [testCss, 'text/css; charset=utf-8'] };
  if (!files[path]) return null;
  const [content, type] = files[path];
  return new Response(content, { headers: { 'Content-Type': type, 'Cache-Control': 'no-store',
    'Content-Security-Policy': "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
    'Referrer-Policy': 'no-referrer' } });
}
