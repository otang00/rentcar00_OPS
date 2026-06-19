import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { buildConfig, saveOriginalImage } from './parser-core.js';

const storageRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'fine-notice-storage-'));
const imageInput = {
  dataUrl: 'data:image/jpeg;base64,/9j/2w==',
  buffer: Buffer.from('/9j/2w==', 'base64'),
  mimeType: 'image/jpeg',
  extension: 'jpg'
};

const file = await saveOriginalImage({
  imageInput,
  config: { ...buildConfig({}), storageRoot },
  now: new Date('2026-06-19T00:00:00.000Z')
});

const stat = await fs.stat(file.localPath);
console.log(JSON.stringify({
  ok: true,
  fileRole: file.fileRole,
  localPathIncludesIncoming: file.localPath.includes('/incoming/20260619/'),
  sha256: file.sha256,
  mimeType: file.mimeType,
  sizeBytes: file.sizeBytes,
  statSize: stat.size,
  backupStatus: file.backupStatus
}, null, 2));
