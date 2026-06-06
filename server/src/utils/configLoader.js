const fs = require('fs');
const path = require('path');

const { substituteEnvInObject } = require('./envSubstitution');

function asArray(value) {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

function normalizeNotifications(notifications) {
  return asArray(notifications)
    .map((n) => ({
      type: n?.type,
      enabled: Boolean(n?.enabled ?? true),
      settings: n?.settings ?? {},
    }))
    .filter((n) => typeof n.type === 'string' && n.type.length > 0);
}

async function loadConfigFile(configPath) {
  let raw = {};

  try {
    const text = await fs.promises.readFile(configPath, 'utf8');
    const ext = path.extname(configPath).toLowerCase();

    if (ext === '.json') {
      raw = JSON.parse(text) ?? {};
    } else if (ext === '.yaml' || ext === '.yml') {
      let YAML;
      try {
        // Optional dependency - only required when YAML config is used.
        // eslint-disable-next-line global-require
        YAML = require('yaml');
      } catch {
        console.warn('[cloudmonitoring] YAML config requested but `yaml` dependency is not installed');
        raw = {};
      }

      if (YAML) raw = YAML.parse(text) ?? {};
    } else {
      // Best-effort: try JSON, then YAML (if available).
      try {
        raw = JSON.parse(text) ?? {};
      } catch {
        let YAML;
        try {
          // eslint-disable-next-line global-require
          YAML = require('yaml');
        } catch {
          YAML = null;
        }
        raw = YAML ? (YAML.parse(text) ?? {}) : {};
      }
    }
  } catch (error) {
    console.warn('[cloudmonitoring] config read failed:', error?.message ?? error);
  }

  const substituted = substituteEnvInObject(raw);

  const gameFolder =
    substituted.game_folder ??
    process.env.CLOUDMONITORING_GAME_FOLDER ??
    '/app/gamedata';

  const outputDir =
    substituted.script_output_dir ??
    process.env.CLOUDMONITORING_OUTPUT_DIR ??
    path.join(gameFolder, 'script-output');

  const alertsLogPath =
    substituted.alerts_log_path ??
    process.env.CLOUDMONITORING_ALERT_LOG ??
    path.join(gameFolder, 'cloudmonitoring-alerts.log');

  const monitorItems = Array.isArray(substituted.monitor_items)
    ? new Set(substituted.monitor_items.map(String))
    : null;

  return {
    notifications: normalizeNotifications(substituted.notifications),
    monitorItems,
    gameFolder,
    outputDir,
    alertsLogPath,
  };
}

module.exports = { loadConfigFile };
