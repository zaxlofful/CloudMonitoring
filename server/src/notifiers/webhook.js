async function notify(itemName, settings) {
  const url = settings?.url;
  if (!url) {
    console.warn('[cloudmonitoring][webhook] missing url; skipping');
    return false;
  }

  const method = settings?.method ?? 'POST';
  const headers = { 'content-type': 'application/json', ...(settings?.headers ?? {}) };

  const payload = {
    item: itemName,
    event: 'production_stopped',
    timestamp: Math.floor(Date.now() / 1000),
  };

  const response = await fetch(url, {
    method,
    headers,
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    console.warn(`[cloudmonitoring][webhook] non-2xx response: ${response.status}`);
    return false;
  }

  return true;
}

module.exports = { notify };
