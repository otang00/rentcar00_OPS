import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, parseFineNoticeInput } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const fixturesDir = path.resolve(__dirname, '../src/fixtures');
const files = (await fs.readdir(fixturesDir)).filter((name) => name.endsWith('.json')).sort();

const results = [];
for (const file of files) {
  const content = await fs.readFile(path.join(fixturesDir, file), 'utf8');
  const fixture = JSON.parse(content);
  const result = await parseFineNoticeInput({ fixture }, buildConfig({}));
  results.push({ file, noticeProfile: result.noticeProfile, noticeType: result.noticeType, warnings: result.warnings });
}

console.log(JSON.stringify({ ok: true, count: results.length, results }, null, 2));
