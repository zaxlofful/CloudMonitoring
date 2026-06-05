function createStateManager({ monitorItems }) {
  const states = new Map(); // item -> { state, lastRate }
  let monitor = monitorItems;

  function setMonitorItems(next) {
    monitor = next;
  }

  function allItemsInScope(snapshotItems) {
    const out = new Set();
    for (const key of snapshotItems.keys()) out.add(key);
    for (const key of states.keys()) out.add(key);
    if (monitor) for (const key of monitor) out.add(key);
    return out;
  }

  function applySnapshot(snapshotItems, { timestamp, initializing }) {
    const productionStopped = [];
    const productionRecovered = [];

    const items = allItemsInScope(snapshotItems);
    for (const item of items) {
      if (monitor && !monitor.has(item)) continue;

      const rate = snapshotItems.get(item) ?? 0;
      const prev = states.get(item) ?? { state: 'producing', lastRate: undefined };
      const prevState = prev.state;
      const prevRate = prev.lastRate;

      let nextState = prevState;

      if (prevState === 'producing') {
        if (rate === 0 && typeof prevRate === 'number' && prevRate > 0) {
          nextState = 'alerted';
          if (!initializing) productionStopped.push({ item, rate });
        }
      } else if (prevState === 'alerted') {
        if (rate > 0) {
          nextState = 'recovering';
          if (!initializing) productionRecovered.push({ item, rate });
        }
      } else if (prevState === 'recovering') {
        if (rate === 0) {
          nextState = 'alerted';
          if (!initializing) productionStopped.push({ item, rate });
        } else if (rate > 0) {
          nextState = 'producing';
        }
      } else {
        nextState = 'producing';
      }

      states.set(item, { state: nextState, lastRate: rate, lastTimestamp: timestamp });
    }

    return { productionStopped, productionRecovered };
  }

  return { applySnapshot, setMonitorItems, states };
}

module.exports = { createStateManager };
