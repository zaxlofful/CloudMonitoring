const fs = require('fs');
const path = require('path');

function createAlertLogger(logFilePath) {
  async function ensureParentDir() {
    await fs.promises.mkdir(path.dirname(logFilePath), { recursive: true });
  }

  return {
    async log(entry) {
      try {
        await ensureParentDir();
        await fs.promises.appendFile(logFilePath, `${JSON.stringify(entry)}\n`, 'utf8');
      } catch (error) {
        console.warn('[cloudmonitoring] failed to write alert log:', error?.message ?? error);
      }
    },
  };
}

module.exports = { createAlertLogger };
