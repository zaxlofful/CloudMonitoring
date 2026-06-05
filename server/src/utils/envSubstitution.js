function substituteEnvInString(value) {
  return value.replace(/\$\{([A-Z0-9_]+)\}/g, (_match, varName) => process.env[varName] ?? '');
}

function substituteEnvInObject(value) {
  if (typeof value === 'string') return substituteEnvInString(value);
  if (Array.isArray(value)) return value.map(substituteEnvInObject);
  if (!value || typeof value !== 'object') return value;

  const out = {};
  for (const [key, v] of Object.entries(value)) {
    out[key] = substituteEnvInObject(v);
  }
  return out;
}

module.exports = { substituteEnvInObject };
