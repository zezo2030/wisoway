import { randomUUID } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { AppDataSource } from '../data-source';
import {
  CONTENT_TYPE_BY_EXTENSION,
  PRIVATE_DOCUMENT_PREFIX,
  PRIVATE_DOCUMENTS_DIR,
} from '../../modules/uploads/private-documents.service';

/**
 * Moves driver documents and payment receipts uploaded before private storage
 * out of the public `uploads/` folder, then rewrites the rows that point at
 * them.
 *
 * Reports only by default; pass --apply to move anything. Safe to run again:
 * moved documents no longer match. Car photos stay public on purpose.
 */
const COLUMNS = [
  { table: 'vehicles', column: 'nationalIdImageUrl' },
  { table: 'vehicles', column: 'licenseImageUrl' },
  { table: 'vehicles', column: 'vehicleLicenseImageUrl' },
  { table: 'vehicles', column: 'insuranceImageUrl' },
  { table: 'payments', column: 'proofImageUrl' },
];
const UPLOADS_DIR = path.join(process.cwd(), 'uploads');
const PUBLIC_FILE = /\/uploads\/((?:[\w-][\w.-]*\/)*[\w-][\w.-]*)$/;

async function exists(file: string): Promise<boolean> {
  return fs.access(file).then(
    () => true,
    () => false,
  );
}

async function main() {
  const apply = process.argv.includes('--apply');
  await AppDataSource.initialize();
  await fs.mkdir(PRIVATE_DOCUMENTS_DIR, { recursive: true });

  const urls = new Set<string>();
  for (const { table, column } of COLUMNS) {
    const rows: { url: string }[] = await AppDataSource.query(
      `SELECT DISTINCT "${column}" AS url FROM ${table}
       WHERE "${column}" IS NOT NULL AND "${column}" NOT LIKE $1`,
      [`${PRIVATE_DOCUMENT_PREFIX}%`],
    );
    rows.forEach((row) => urls.add(row.url));
  }

  let moved = 0;
  const skipped: string[] = [];

  for (const url of urls) {
    const key = PUBLIC_FILE.exec(url)?.[1];
    const source = key && path.join(UPLOADS_DIR, key);
    const rawExtension = key && path.extname(key).slice(1).toLowerCase();
    const extension = rawExtension === 'jpeg' ? 'jpg' : rawExtension;

    if (!source || !extension || !CONTENT_TYPE_BY_EXTENSION[extension]) {
      skipped.push(`unsupported: ${url}`);
      continue;
    }
    if (!(await exists(source))) {
      skipped.push(`file missing: ${url}`);
      continue;
    }

    moved += 1;
    if (!apply) continue;

    const name = `${randomUUID()}.${extension}`;
    await fs.copyFile(source, path.join(PRIVATE_DOCUMENTS_DIR, name));
    await AppDataSource.transaction(async (manager) => {
      for (const { table, column } of COLUMNS) {
        await manager.query(
          `UPDATE ${table} SET "${column}" = $1 WHERE "${column}" = $2`,
          [`${PRIVATE_DOCUMENT_PREFIX}${name}`, url],
        );
      }
    });
    await fs.unlink(source);
  }

  console.log(
    `${apply ? 'Moved' : 'Would move'} ${moved} of ${urls.size} document(s).`,
  );
  skipped.forEach((line) => console.log(`Skipped, ${line}`));
  if (!apply) console.log('Nothing changed. Run again with --apply.');
  await AppDataSource.destroy();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
