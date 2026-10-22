import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { integrateGame } from '../scripts/integrate-game.mjs';

test('integration preserves the original game and assets, backs up edits, and keeps the original startup on rerun', async () => {
  const base = await mkdtemp(join(tmpdir(), 'ancient-nest-integration-'));
  const game = join(base, 'game');
  const source = join(base, 'source');
  try {
    await mkdir(join(game, 'scripts'), { recursive: true });
    await mkdir(join(game, 'intro'), { recursive: true });
    const originalProject = '[application]\nrun/main_scene="res://intro/start.tscn"\n[physics]\n3d/default_gravity=7.34693877\n';
    const originalAccount = 'class_name NestAccountLink\nextends Node\n';
    await writeFile(join(game, 'project.godot'), originalProject);
    await writeFile(join(game, 'scripts/account_link.gd'), originalAccount);
    await writeFile(join(game, 'scripts/main.gd'), 'accounts = NestAccountLink.new()');
    await writeFile(join(game, 'scripts/hybrid_network.gd'), 'account_assertion');
    await writeFile(join(game, 'intro/start.tscn'), 'existing-game-startup');
    for (const folder of ['ancient_nest', 'discord_social_sdk', 'keyring']) await mkdir(join(source, 'godot-client/addons', folder), { recursive: true });
    await mkdir(join(source, 'integration'), { recursive: true });
    await writeFile(join(source, 'integration/account_link.gd'), originalAccount + '# adapter');
    const result = await integrateGame(game, source);
    const updated = await readFile(join(game, 'project.godot'), 'utf8');
    assert.match(updated, /original_main_scene="res:\/\/intro\/start.tscn"/);
    assert.match(updated, /3d\/default_gravity=7.34693877/);
    assert.equal(await readFile(join(result.backup, 'project.godot'), 'utf8'), originalProject);
    assert.equal(await readFile(join(result.backup, 'scripts/account_link.gd'), 'utf8'), originalAccount);
    assert.equal(await readFile(join(game, 'intro/start.tscn'), 'utf8'), 'existing-game-startup');
    const second = await integrateGame(game, source);
    assert.equal(second.original, 'res://intro/start.tscn');
    assert.notEqual(second.backup, result.backup);
  } finally { await rm(base, { recursive: true, force: true }); }
});

test('integration refuses a different game interface before editing project files', async () => {
  const base = await mkdtemp(join(tmpdir(), 'ancient-nest-refuse-'));
  try {
    const original = '[application]\nrun/main_scene="res://start.tscn"\n';
    await writeFile(join(base, 'project.godot'), original);
    await assert.rejects(integrateGame(base), /No files changed/);
    assert.equal(await readFile(join(base, 'project.godot'), 'utf8'), original);
  } finally { await rm(base, { recursive: true, force: true }); }
});
