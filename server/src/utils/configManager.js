const fs = require('fs');
const path = require('path');

const { loadConfigFile } = require('./configLoader');

async function createConfigManager() {
  const configPath =
    process.env.CLOUDMONITORING_CONFIG ??
    path.resolve(process.cwd(), 'cloudmonitoring-config.yaml');

  const listeners = new Set();
  let watcher = null;

  async function load() {
    const config = await loadConfigFile(configPath);
    return config;
  }

  function onChange(handler) {
    listeners.add(handler);
    return () => listeners.delete(handler);
  }

  async function startWatching() {
    if (watcher) return;

    try {
      watcher = fs.watch(configPath, { persistent: false }, async () => {
        try {
          const nextConfig = await load();
          for (const handler of listeners) {
            // Fire-and-forget so a slow handler doesn't block reload.
            Promise.resolve(handler(nextConfig)).catch((error) => {
              console.warn('[cloudmonitoring] config change handler failed:', error?.message ?? error);
            });
          }
        } catch (error) {
          console.warn('[cloudmonitoring] failed to reload config:', error?.message ?? error);
        }
      });
    } catch (error) {
      // Missing config is allowed (users may mount it later).
      console.warn('[cloudmonitoring] config watch disabled:', error?.message ?? error);
    }
  }

  await startWatching();

  return { load, onChange };
}

module.exports = { createConfigManager };
