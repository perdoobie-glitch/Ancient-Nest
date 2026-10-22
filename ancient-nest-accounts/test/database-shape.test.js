import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assertCompatible, baseColumns } from '../scripts/database-shape.mjs';

test('migration preflight accepts empty databases and the complete exported schema', () => {
  assert.doesNotThrow(() => assertCompatible([]));
  const rows = Object.entries(baseColumns).flatMap(([table_name, columns]) => columns.map(name => ({ table_name, name })));
  assert.doesNotThrow(() => assertCompatible(rows));
  assert.doesNotThrow(() => assertCompatible([...rows, { table_name: 'users', name: 'auth_version' }]));
});

test('migration preflight refuses the incompatible previous scaffold without discarding data', () => {
  assert.throws(() => assertCompatible(['id', 'username', 'username_key', 'password_hash', 'created_at']
    .map(name => ({ table_name: 'users', name }))), /Incompatible users table/);
  assert.throws(() => assertCompatible([{ table_name: 'sessions', name: 'id' }]), /Incompatible sessions table/);
});
