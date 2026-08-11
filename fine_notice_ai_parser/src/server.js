import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile, parseFineNoticeInput } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
await loadEnvFile(path.resolve(__dirname, '../.env'));

const config = buildConfig(process.env);

if (process.argv.includes('--check')) {
  console.log(JSON.stringify({
    hasOpenAiApiKey: Boolean(config.openAiApiKey),
    openAiModel: config.openAiModel,
    host: config.host,
    port: config.port,
    timeoutMs: config.timeoutMs,
    storageRoot: config.storageRoot
  }, null, 2));
  process.exit(0);
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/health') {
      if (req.method !== 'GET') return sendMethodNotAllowed(res, ['GET']);
      return sendJson(res, 200, { ok: true, service: 'fine_notice_ai_parser' });
    }

    if (req.url === '/parse-fine-notice') {
      if (req.method !== 'POST') return sendMethodNotAllowed(res, ['POST']);
      const body = await readJsonBody(req);
      const result = await parseFineNoticeInput(body, config);
      return sendJson(res, 200, result);
    }

    return sendJson(res, 404, { ok: false, error: 'not_found' });
  } catch (error) {
    return sendJson(res, resolveErrorStatus(error), {
      ok: false,
      error: resolveErrorCode(error),
      message: error?.message || 'unknown error'
    });
  }
});

server.listen(config.port, config.host, () => {
  console.log(`fine_notice_ai_parser listening on http://${config.host}:${config.port}`);
});

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 12 * 1024 * 1024) {
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

function sendJson(res, status, payload) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(payload));
}

function sendMethodNotAllowed(res, allow) {
  res.writeHead(405, {
    'Content-Type': 'application/json; charset=utf-8',
    Allow: allow.join(', ')
  });
  res.end(JSON.stringify({ ok: false, error: 'method_not_allowed' }));
}

function resolveErrorStatus(error) {
  if (error?.message === 'invalid_json') return 400;
  if (error?.message === 'payload_too_large') return 413;
  if (error?.message?.startsWith('missing ')) return 503;
  return 500;
}

function resolveErrorCode(error) {
  if (error?.message === 'invalid_json') return 'invalid_json';
  if (error?.message === 'payload_too_large') return 'payload_too_large';
  if (error?.message?.startsWith('missing ')) return 'not_configured';
  return 'internal_error';
}
