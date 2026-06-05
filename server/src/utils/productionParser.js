const fs = require('fs');
const path = require('path');

function parseTimestampFromFileName(filePath) {
  const base = path.basename(filePath);
  const match = base.match(/cloudmonitoring-data-(\d+)\.json$/i);
  if (!match) return null;
  const num = Number(match[1]);
  if (!Number.isFinite(num)) return null;
  return num > 4_000_000_000 ? Math.floor(num / 1000) : num; // ms -> s (heuristic)
}

function flattenItemRates(json) {
  const items = new Map();

  function addItemRates(obj) {
    if (!obj || typeof obj !== 'object') return;
    for (const [item, rate] of Object.entries(obj)) {
      const numeric = Number(rate);
      if (!Number.isFinite(numeric)) continue;
      items.set(item, numeric);
    }
  }

  if (json?.items && typeof json.items === 'object') {
    addItemRates(json.items);
    return items;
  }

  if (json?.rates && typeof json.rates === 'object') {
    addItemRates(json.rates);
    return items;
  }

  if (json?.surfaces && typeof json.surfaces === 'object') {
    for (const surface of Object.values(json.surfaces)) {
      if (!surface || typeof surface !== 'object') continue;
      if (surface.items && typeof surface.items === 'object') addItemRates(surface.items);
      else if (surface.rates && typeof surface.rates === 'object') addItemRates(surface.rates);
      else addItemRates(surface);
    }
    return items;
  }

  // If the whole object looks like an item->rate map.
  addItemRates(json);
  return items;
}

async function parseProductionSnapshotFromFile(filePath) {
  let json;
  let lastError = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const text = await fs.promises.readFile(filePath, 'utf8');
      json = JSON.parse(text);
      lastError = null;
      break;
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
  }

  if (lastError) {
    console.warn(
      '[cloudmonitoring] malformed/unreadable data file; skipping:',
      path.basename(filePath),
      '-',
      lastError?.message ?? lastError,
    );
    return null;
  }

  const fromJsonTimestamp = Number(json?.timestamp);
  const timestamp =
    (Number.isFinite(fromJsonTimestamp)
      ? (fromJsonTimestamp > 4_000_000_000 ? Math.floor(fromJsonTimestamp / 1000) : fromJsonTimestamp)
      : null) ??
    parseTimestampFromFileName(filePath) ??
    Math.floor(Date.now() / 1000);

  const items = flattenItemRates(json);
  return { timestamp, items };
}

module.exports = { parseProductionSnapshotFromFile };
