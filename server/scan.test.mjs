import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

const run = promisify(execFile);
const scanner = fileURLToPath(new URL('./scan.mjs', import.meta.url));

test('Origins group evidence, exclude installed copies, preserve Drift, and keep hints Loose', async (t) => {
  const home = await fs.mkdtemp(path.join(os.tmpdir(), 'spellbook-origin-'));
  t.after(() => fs.rm(home, { recursive: true, force: true }));
  const write = async (relative, text) => {
    const file = path.join(home, relative);
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, text);
    return file;
  };
  const json = (file, data) => write(file, JSON.stringify(data));
  const skill = (root, id, description, body = '') => write(`${root}/${id}/SKILL.md`, `---\nname: ${id}\ndescription: ${description}\n---\n${body}\n`);
  const repo = async (name, slug) => {
    await write(`Code/${name}/.git/config`, `[remote "origin"]\n  url = https://github.com/${slug}.git\n`);
    return `Code/${name}`;
  };
  await fs.mkdir(path.join(home, 'Project'));
  await skill('.agents/skills', 'first', 'Recorded skill one.');
  await skill('.claude/skills', 'first', 'Recorded skill one.', 'A changed copy.');
  await skill('.claude/skills', 'second', 'Recorded skill two.');
  await skill('Project/.claude/skills', 'first', 'An unrelated project skill.');
  await json('.agents/.skill-lock.json', { skills: {
    first: { source: 'owner/bundle', skillPath: 'skills/first/SKILL.md', skillFolderHash: 'first-hash', installedAt: '2020-01-02T00:00:00Z', updatedAt: '2021-02-03T00:00:00Z' },
    second: { source: 'owner/bundle', skillPath: 'skills/second/SKILL.md', skillFolderHash: 'second-hash', installedAt: '2025-01-02T00:00:00Z' },
    absent: { source: 'owner/stale' },
    pluginonly: { source: 'owner/stale-plugin-name' }
  } });
  for (const id of ['hint-one', 'hint-two']) await skill('.agents/skills', id, `${id} description.`, 'See https://github.com/owner/hint/releases.');
  await skill('.agents/skills', 'unknown', 'A description that appears nowhere else.');
  await skill('.agents/skills', 'copied', 'Description found only in another project skill root.');
  const copyRepo = await repo('InstalledCopies', 'owner/copies');
  for (const root of ['.agents', '.claude', '.codex', '.gemini', '.cursor']) {
    await skill(`${copyRepo}/${root}/skills`, 'copied', 'Description found only in another project skill root.');
  }
  const local = await repo('Local', 'owner/local');
  await skill('.agents/skills', 'matched', 'Unique source description.');
  await write(`${local}/src/installer.ts`, 'Unique source description.');
  await skill('.agents/skills', 'ambiguous', 'Ambiguous source description.');
  for (const name of ['Alpha', 'Beta']) await write(`${await repo(name, `owner/${name}`)}/source.md`, 'Ambiguous source description.');
  await skill('.agents/skills', 'excluded', 'Description only in excluded files.');
  await write(`${local}/dist/source.md`, 'Description only in excluded files.');
  await write(`${local}/node_modules/pkg/source.md`, 'Description only in excluded files.');
  await write(`${local}/oversized.md`, 'Description only in excluded files.' + 'x'.repeat(2 * 1024 * 1024));
  const linked = await repo('Linked', 'owner/linked');
  await skill(`${linked}/skills`, 'linked', 'A linked skill.');
  await fs.symlink(path.join(home, linked, 'skills/linked'), path.join(home, '.agents/skills/linked'));
  const bench = await repo('Bench', 'owner/Bench');
  await skill('.agents/skills', 'pack-one', 'Pack source description.');
  await write(`${bench}/INSTALL.md`, 'Pack source description.');
  await skill('.agents/skills', 'pack-changed', 'A changed pack description.');
  await json('.agents/skills/.bench-install.json', { version: '1.12.0', skills: { 'pack-one': ['SKILL.md'], 'pack-changed': ['SKILL.md'], 'pack-absent': ['SKILL.md'] } });
  await skill('.codex/skills/.system', 'system-one', 'System description.');
  const pluginPath = path.join(home, 'Plugin');
  await skill('Plugin/skills', 'pluginonly', 'A plugin skill.');
  await json('.claude/plugins/installed_plugins.json', { plugins: { 'example@market': [{ installPath: pluginPath, gitCommitSha: 'commit', version: '2.0' }] } });
  await json('.claude/plugins/known_marketplaces.json', { market: { source: { repo: 'owner/market' } } });
  const packageRoot = 'runtime/lib/node_modules/fixture-cli';
  const executable = await write(`${packageRoot}/cli.js`, '#!/usr/bin/env node\n');
  await fs.chmod(executable, 0o755);
  const pkg = { name: 'fixture-cli', version: '1.0', repository: 'https://github.com/owner/cli.git' };
  await json(`${packageRoot}/package.json`, pkg);
  await fs.mkdir(path.join(home, 'bin'));
  await fs.symlink(executable, path.join(home, 'bin/fixture-cli'));
  await json('.npm/_npx/cache/node_modules/fixture-cli/package.json', pkg);
  await skill('.agents/skills', 'cli', 'A CLI skill.', 'Run `fixture-cli open file.md`.');
  await skill('.agents/skills', 'prose-only', 'CLI is a word here.', 'The fixture-cli package is an unrelated example.');
  await skill('.agents/skills', 'local-command', 'Locally bundled command.', 'Run `<skill-base-dir>/scripts/fixture-cli open`; `fixture-cli open` is shorthand.');

  const scan = async () => JSON.parse((await run(process.execPath, [scanner, '--project', path.join(home, 'Project'), '--compact'], {
    env: { ...process.env, HOME: home, PATH: path.join(home, 'bin') }, maxBuffer: 5 * 1024 * 1024
  })).stdout);
  const survey = await scan();
  const devices = survey.installs.filter((i) => i.source === 'device');
  const entry = (id) => devices.find((i) => i.skills.some((s) => s.id === id));
  assert.equal(entry('first').id, entry('second').id, 'dates do not split an Origin');
  assert.equal(entry('first').name, 'owner/bundle');
  assert.equal(entry('first').skills[0].date, '2021-02-03');
  assert.equal(entry('first').skills[0].installedAt, '2020-01-02T00:00:00Z');
  assert.equal(entry('first').drift, true);
  assert.deepEqual(entry('first').skills[0].driftDetail.changed, ['SKILL.md']);
  assert.equal(entry('first').origin.path, undefined, 'per-skill paths are not asserted for the whole Install');
  assert.equal(entry('first').skills[0].origin.path, 'skills/first');
  assert.equal(entry('absent'), undefined);
  assert.equal(survey.installs.find((i) => i.source === 'project').origin.grade, 'unknown');
  for (const id of ['hint-one', 'hint-two']) {
    assert.equal(entry(id).kind, 'loose'); assert.equal(entry(id).origin.grade, 'hinted');
  }
  assert.notEqual(entry('hint-one').id, entry('hint-two').id);
  for (const id of ['unknown', 'copied', 'ambiguous', 'excluded', 'prose-only', 'local-command']) assert.equal(entry(id).origin.grade, 'unknown', id);
  assert.equal(entry('matched').origin.grade, 'matched');
  assert.equal(entry('matched').origin.slug, 'owner/local');
  assert.match(entry('matched').origin.evidence[0], /src\/installer.ts/);
  assert.equal(entry('linked').origin.grade, 'matched');
  assert.match(entry('linked').origin.evidence[0], /symlink/);
  assert.equal(entry('pack-one').id, entry('pack-changed').id);
  assert.equal(entry('pack-one').origin.kind, 'pack');
  assert.equal(entry('pack-one').origin.grade, 'recorded');
  assert.equal(entry('pack-one').origin.slug, 'owner/Bench');
  assert.equal(entry('pack-one').origin.version, '1.12.0');
  assert.equal(entry('pack-absent'), undefined);
  assert.equal(entry('system-one').origin.slug, 'openai/skills');
  assert.equal(entry('pluginonly').origin.kind, 'plugin');
  assert.equal(entry('pluginonly').origin.slug, 'owner/market');
  assert.equal(entry('pluginonly').origin.path, 'plugins/example');
  assert.equal(entry('pluginonly').origin.ref, 'commit');
  assert.equal(entry('cli').origin.grade, 'matched');
  assert.equal(entry('cli').origin.slug, 'owner/cli');
  assert.ok(survey.records.some((r) => r.kind === 'Agent Skills CLI lockfile' && r.entries === 4 && r.read));
  assert.ok(devices.every((i) => i.kind === 'loose' || /^orig-[a-f0-9]{8}$/.test(i.id)));
  assert.deepEqual((await scan()).installs.map((i) => i.id), survey.installs.map((i) => i.id), 'identities are stable across scans');
});
