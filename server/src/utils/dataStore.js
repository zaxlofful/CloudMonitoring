function createDataStore({ retentionSeconds }) {
  const window = new Map(); // timestamp(seconds) -> Map(item -> rate)

  function add(timestamp, itemsMap) {
    window.set(timestamp, itemsMap);
  }

  function prune(nowSeconds) {
    const cutoff = nowSeconds - retentionSeconds;
    for (const timestamp of window.keys()) {
      if (timestamp < cutoff) window.delete(timestamp);
    }
  }

  return { add, prune, window };
}

module.exports = { createDataStore };
