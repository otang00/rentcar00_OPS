import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile, parseReservationInput, validateConfig } from './parser-core.js';

const execFileAsync = promisify(execFile);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
await loadEnvFile(path.resolve(__dirname, '../.env'));

const config = buildConfig(process.env);

if (process.argv.includes('--check')) {
  console.log(JSON.stringify({
    hasOpenAiApiKey: Boolean(config.openAiApiKey),
    openAiModel: config.openAiModel,
    host: config.host,
    port: config.port,
    timeoutMs: config.timeoutMs
  }, null, 2));
  process.exit(0);
}

validateConfig(config);

const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/health') {
      if (req.method !== 'GET') {
        return sendMethodNotAllowed(res, ['GET']);
      }
      return sendJson(res, 200, { ok: true, service: 'reservation_ai_parser' });
    }

    if (req.url === '/parse-reservation') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const result = await parseReservationInput({ text: body?.text }, config);
      return sendJson(res, 200, result);
    }

    if (req.url === '/ims/create-reservation') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsReservationPayload(body);
      const result = await runImsReservationScript(payload);
      const ok = result?.code === 'SUCCESS' || result?.code === 'DRY_RUN';
      return sendJson(res, ok ? 200 : 422, {
        ok,
        payload,
        result,
      });
    }

    return sendJson(res, 404, { ok: false, error: 'not_found' });
  } catch (error) {
    const status = resolveErrorStatus(error);
    return sendJson(res, status, {
      ok: false,
      error: resolveErrorCode(error),
      message: error?.message || 'unknown error'
    });
  }
});

server.listen(config.port, config.host, () => {
  console.log(`reservation_ai_parser listening on http://${config.host}:${config.port}`);
});

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 5 * 1024 * 1024) {
        reject(new Error('payload_too_large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch {
        reject(new Error('invalid_json'));
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
}

function sendMethodNotAllowed(res, methods) {
  res.writeHead(405, {
    'Content-Type': 'application/json; charset=utf-8',
    'Allow': methods.join(', ')
  });
  res.end(JSON.stringify({ ok: false, error: 'method_not_allowed' }));
}

function resolveErrorStatus(error) {
  if (error?.message === 'invalid_json') return 400;
  if (error?.message === 'payload_too_large') return 413;
  if (error?.name === 'AbortError') return 504;
  return 500;
}

function resolveErrorCode(error) {
  if (error?.message === 'invalid_json') return 'invalid_json';
  if (error?.message === 'payload_too_large') return 'payload_too_large';
  if (error?.message?.startsWith('missing required ims fields')) return 'invalid_ims_payload';
  if (error?.name === 'AbortError') return 'timeout';
  return 'parse_failed';
}

function normalizeImsReservationPayload(body = {}) {
  const payload = {
    rentalAt: String(body?.rentalAt || '').trim(),
    returnAt: String(body?.returnAt || '').trim(),
    carNumber: String(body?.carNumber || '').trim(),
    totalFee: String(body?.totalFee || '').replace(/\D+/g, ''),
    customerName: String(body?.customerName || '').trim(),
    customerPhone: String(body?.customerPhone || '').replace(/\D+/g, ''),
    address: String(body?.address || '').trim(),
    useDelivery: body?.useDelivery !== false,
    memo: String(body?.memo || '').trim(),
  };

  const required = ['rentalAt', 'returnAt', 'carNumber', 'totalFee', 'customerName', 'customerPhone'];
  const missing = required.filter((key) => !payload[key]);
  if (missing.length > 0) {
    throw new Error(`missing required ims fields: ${missing.join(', ')}`);
  }

  return payload;
}

async function runImsReservationScript(payload) {
  const scriptPath = await findFirstExistingPath([
    path.resolve(__dirname, '../../../../tools/playwright/scripts/ims-reservation-draft.js'),
    path.resolve(process.cwd(), '../../tools/playwright/scripts/ims-reservation-draft.js'),
    path.resolve(process.cwd(), '../tools/playwright/scripts/ims-reservation-draft.js'),
  ]);

  let stdout = '';
  let stderr = '';
  try {
    const result = await execFileAsync('node', [scriptPath, JSON.stringify(payload)], {
      cwd: process.cwd(),
      env: {
        ...process.env,
        IMS_SAVE: process.env.IMS_SAVE || 'false',
      },
      timeout: 1000 * 60 * 2,
      maxBuffer: 1024 * 1024,
    });
    stdout = result.stdout || '';
    stderr = result.stderr || '';
  } catch (error) {
    stdout = error.stdout || '';
    stderr = error.stderr || '';
  }

  const lines = `${stdout}\n${stderr}`
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const lastJsonLine = [...lines]
    .reverse()
    .find((line) => line.startsWith('{') && line.endsWith('}'));
  if (!lastJsonLine) {
    return { code: 'ERROR', message: stdout || stderr || 'missing ims result' };
  }

  return JSON.parse(lastJsonLine);
}

async function findFirstExistingPath(paths) {
  for (const candidate of paths) {
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // try next path
    }
  }

  throw new Error(`IMS script not found: ${paths.join(' | ')}`);
}
