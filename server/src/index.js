const { createAlertLogger } = require('./utils/alertLogger');
const { createConfigManager } = require('./utils/configManager');
const { createDataStore } = require('./utils/dataStore');
const { startFileWatcher } = require('./utils/fileWatcher');
const { createNotifierManager } = require('./utils/notifierManager');
const { parseProductionSnapshotFromFile } = require('./utils/productionParser');
const { createStateManager } = require('./utils/stateManager');

async function main() {
  const configManager = await createConfigManager();
  const config = await configManager.load();

  const alertLogger = createAlertLogger(config.alertsLogPath);
  const dataStore = createDataStore({ retentionSeconds: 100 * 60 * 60 });
  const stateManager = createStateManager({ monitorItems: config.monitorItems });
  let notifierManager = createNotifierManager(config.notifications);

  configManager.onChange(async (nextConfig) => {
    notifierManager = createNotifierManager(nextConfig.notifications);
    stateManager.setMonitorItems(nextConfig.monitorItems);
  });

  async function processFile(filePath, { initializing }) {
    const snapshot = await parseProductionSnapshotFromFile(filePath);
    if (!snapshot) return;

    dataStore.add(snapshot.timestamp, snapshot.items);

    const events = stateManager.applySnapshot(snapshot.items, {
      timestamp: snapshot.timestamp,
      initializing,
    });

    if (initializing) return;

    for (const stopped of events.productionStopped) {
      const notifyResult = await notifierManager.notify(stopped.item);

      await alertLogger.log({
        timestamp: snapshot.timestamp,
        item: stopped.item,
        event: 'production_stopped',
        production_rate: stopped.rate,
        notifiers_triggered: notifyResult.triggered,
        notifiers_failed: notifyResult.failed,
      });
    }

    for (const recovered of events.productionRecovered) {
      await alertLogger.log({
        timestamp: snapshot.timestamp,
        item: recovered.item,
        event: 'production_recovered',
        production_rate: recovered.rate,
        notifiers_triggered: [],
        notifiers_failed: [],
      });
    }
  }

  const processedFiles = new Set();

  // Bootstrap: scan recent files to reconstruct state without emitting alerts.
  const bootstrapCount = Number.parseInt(process.env.CLOUDMONITORING_BOOTSTRAP_FILES ?? '10', 10);
  const outputDir = config.outputDir;
  const bootstrapFiles = await startFileWatcher.listRecent(outputDir, bootstrapCount);
  for (const filePath of bootstrapFiles) {
    processedFiles.add(filePath);
    await processFile(filePath, { initializing: true });
  }

  // Periodic pruning of the in-memory window.
  setInterval(() => dataStore.prune(Date.now() / 1000), 60_000).unref();

  await startFileWatcher({
    directory: outputDir,
    pattern: /^cloudmonitoring-data-.*\.json$/i,
    onFile: (filePath) => {
      if (processedFiles.has(filePath)) return;
      processedFiles.add(filePath);
      processFile(filePath, { initializing: false });
    },
  });

  // Keep process alive.
  while (true) {
    await new Promise((resolve) => setTimeout(resolve, 60_000));
  }
}

main().catch((error) => {
  console.error('[cloudmonitoring] fatal:', error);
  process.exitCode = 1;
});
