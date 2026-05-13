import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile, parseReservationInput } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
await loadEnvFile(path.resolve(__dirname, '../.env'));

const input = process.argv.slice(2).join(' ').trim();
if (!input) {
  console.error('usage: node src/simulate.js "예약 원문"');
  process.exit(1);
}

const config = buildConfig(process.env);
const result = await parseReservationInput({ text: input }, config);
console.log(JSON.stringify(result, null, 2));
