const fs = require('fs');
const path = require('path');

const { loadConfigFile } = require('./configLoader');

function resolveDefaultConfigPath() {
  const candidates = [
    'cloudmonitoring-config.json',
    'cloudmonitoring-config.yaml',
    'cloudmonitoring-config.yml',
  ];

  for (const fileName of candidates) {
    const fullPath = path.resolve(process.cwd(), fileName);
    try {
      fs.accessSync(fullPath, fs.constants.R_OK);
      return fullPath;
    } catch {
      // keep searching
    }
  }

  // Default to JSON for dependency-free usage.
  return path.resolve(process.cwd(), 'cloudmonitoring-config.json');
}

async function createConfigManager() {
  const configPath =
    process.env.CLOUDMONITORING_CONFIG ??
    resolveDefaultConfigPath();

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
