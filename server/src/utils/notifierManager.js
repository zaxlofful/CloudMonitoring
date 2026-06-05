const { getNotifier } = require('./notifiers');

function createNotifierManager(notificationConfigs) {
  const enabled = (notificationConfigs ?? []).filter((n) => n.enabled);

  return {
    async notify(itemName) {
      const triggered = [];
      const failed = [];

      for (const notifierConfig of enabled) {
        const type = notifierConfig.type;
        const notifier = getNotifier(type);
        if (!notifier) {
          console.warn(`[cloudmonitoring] unknown notifier type: ${type}`);
          failed.push(type);
          continue;
        }

        try {
          const ok = await notifier.notify(itemName, notifierConfig.settings);
          if (ok) triggered.push(type);
          else failed.push(type);
        } catch (error) {
          console.warn(`[cloudmonitoring][${type}] notify failed:`, error?.message ?? error);
          failed.push(type);
        }
      }

      return { triggered, failed };
    },
  };
}

module.exports = { createNotifierManager };
