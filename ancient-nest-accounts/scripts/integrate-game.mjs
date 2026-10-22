import { cp, mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { prompt } from './interactive.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const exists = async path => { try { await stat(path); return true; } catch { return false; } };
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export function setSetting(text, section, key, value) {
  const header = new RegExp('^\\[' + escape(section) + '\\]\\s*$', 'm');
  const match = header.exec(text);
  if (!match) return text + '\n[' + section + ']\n' + key + '=' + value + '\n';
  const start = match.index + match[0].length;
  const next = /^\[/m.exec(text.slice(start));
  const end = next ? start + next.index : text.length;
  let block = text.slice(start, end);
  const property = new RegExp('^' + escape(key) + '\\s*=.*$', 'm');
  block = property.test(block) ? block.replace(property, () => key + '=' + value) : '\n' + key + '=' + value + '\n' + block.replace(/^\n+/, '');
  return text.slice(0, start) + block + text.slice(end);
}

export async function integrateGame(directory, sourceRoot = root) {
  const game = resolve(directory);
  const project = join(game, 'project.godot');
  const account = join(game, 'scripts/account_link.gd');
  const main = join(game, 'scripts/main.gd');
  const hybrid = join(game, 'scripts/hybrid_network.gd');
  for (const path of [project, account, main, hybrid]) {
    if (!await exists(path)) throw new Error('Choose the existing Ancient Nest game folder containing project.godot and scripts/account_link.gd. No files changed.');
  }
  const current = await readFile(account, 'utf8');
  const code = await readFile(main, 'utf8');
  if (!current.includes('class_name NestAccountLink') || !code.replace(/\s/g, '').includes('accounts=NestAccountLink.new()') ||
      !(await readFile(hybrid, 'utf8')).includes('account_assertion')) {
    throw new Error('Existing account interface differs. No files changed; review the current game source first.');
  }
  let text = await readFile(project, 'utf8');
  const original = /^original_main_scene="([^"]+)"/m.exec(text)?.[1] ?? /^run\/main_scene="([^"]+)"/m.exec(text)?.[1];
  if (!original?.startsWith('res://') || original === 'res://addons/ancient_nest/login.tscn' || !await exists(join(game, original.slice(6)))) {
    throw new Error('Cannot identify the original startup scene. No files changed.');
  }
  const folders = ['ancient_nest', 'discord_social_sdk', 'keyring'];
  for (const folder of folders) {
    if (!await exists(join(sourceRoot, 'godot-client/addons', folder))) throw new Error('Install native dependencies before integrating. No files changed.');
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, '-') + '-' + crypto.randomUUID().slice(0, 8);
  const backup = join(game, '.account-integration-backup', stamp);
  await mkdir(join(backup, 'scripts'), { recursive: true });
  await cp(project, join(backup, 'project.godot'));
  await cp(account, join(backup, 'scripts/account_link.gd'));
  for (const folder of folders) {
    const destination = join(game, 'addons', folder);
    if (await exists(destination)) await cp(destination, join(backup, 'addons', folder), { recursive: true });
    await cp(join(sourceRoot, 'godot-client/addons', folder), destination, { recursive: true });
  }
  text = setSetting(text, 'application', 'run/main_scene', '"res://addons/ancient_nest/login.tscn"');
  for (const [name, script] of [['AncientNestAuth', 'auth.gd'], ['AncientNestDiscordVoice', 'discord_voice.gd'],
    ['AncientNestVerification', 'verification_panel.gd'], ['AncientNestAccountGuard', 'integration_guard.gd']]) {
    text = setSetting(text, 'autoload', name, JSON.stringify('*res://addons/ancient_nest/' + script));
  }
  text = setSetting(text, 'ancient_nest', 'original_main_scene', JSON.stringify(original));
  text = setSetting(text, 'ancient_nest', 'account_api', '"https://ancient-nest-accounts.ancientnest-llc.workers.dev"');
  await writeFile(project, text);
  await cp(join(sourceRoot, 'integration/account_link.gd'), account);
  return { backup, original };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  (async () => {
    const directory = process.argv[2] ?? await prompt('Folder containing your existing game project.godot', value => value.length > 0);
    const result = await integrateGame(directory.replace(/^"|"$/g, ''));
    console.log('Account gate installed. Original gameplay startup: ' + result.original);
    console.log('Backup: ' + result.backup);
    console.log('Review the current coordinator identity and team-voice hooks before online release.');
  })().catch(error => { console.error('Integration stopped: ' + error.message); process.exitCode = 1; });
}
