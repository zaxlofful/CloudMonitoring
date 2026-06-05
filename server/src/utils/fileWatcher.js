const fs = require('fs');
const path = require('path');

async function ensureDir(directory) {
  try {
    await fs.promises.mkdir(directory, { recursive: true });
  } catch (error) {
    console.warn('[cloudmonitoring] failed to create output dir:', error?.message ?? error);
  }
}

function isMatch(fileName, pattern) {
  return pattern.test(fileName);
}

async function listRecent(directory, limit) {
  try {
    const entries = await fs.promises.readdir(directory, { withFileTypes: true });
    const matched = entries
      .filter((e) => e.isFile() && isMatch(e.name, /^cloudmonitoring-data-.*\.json$/i))
      .map((e) => path.join(directory, e.name));

    const stats = await Promise.all(
      matched.map(async (filePath) => {
        const stat = await fs.promises.stat(filePath);
        return { filePath, mtimeMs: stat.mtimeMs };
      }),
    );

    stats.sort((a, b) => a.mtimeMs - b.mtimeMs);
    return stats.slice(Math.max(0, stats.length - limit)).map((s) => s.filePath);
  } catch {
    return [];
  }
}

async function scan(directory, pattern) {
  try {
    const entries = await fs.promises.readdir(directory, { withFileTypes: true });
    return entries
      .filter((e) => e.isFile() && isMatch(e.name, pattern))
      .map((e) => path.join(directory, e.name));
  } catch (error) {
    console.warn('[cloudmonitoring] failed to scan output dir:', error?.message ?? error);
    return [];
  }
}

async function startFileWatcher({ directory, pattern, onFile }) {
  await ensureDir(directory);

  const seen = new Set();

  async function scanAndEmit() {
    const files = await scan(directory, pattern);
    for (const filePath of files) {
      if (seen.has(filePath)) continue;
      seen.add(filePath);
      Promise.resolve(onFile(filePath)).catch((error) => {
        console.warn('[cloudmonitoring] file handler failed:', error?.message ?? error);
      });
    }
  }

  // Initial scan.
  await scanAndEmit();

  // Best-effort watcher (fs.watch can drop events, so we also poll).
  try {
    fs.watch(directory, { persistent: false }, () => {
      scanAndEmit().catch(() => {});
    });
  } catch (error) {
    console.warn('[cloudmonitoring] fs.watch unavailable; falling back to polling:', error?.message ?? error);
  }

  setInterval(() => scanAndEmit(), 5_000).unref();
}

startFileWatcher.listRecent = listRecent;

module.exports = { startFileWatcher };
