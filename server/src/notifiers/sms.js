async function notify(itemName, settings) {
  const provider = settings?.provider ?? 'twilio';
  if (provider !== 'twilio') {
    console.warn(`[cloudmonitoring][sms] unsupported provider: ${provider}`);
    return false;
  }

  const accountSid = settings?.account_sid;
  const authToken = settings?.auth_token;
  const from = settings?.phone_from;
  const toList = settings?.phone_to;

  if (!accountSid || !authToken || !from || !Array.isArray(toList) || toList.length === 0) {
    console.warn('[cloudmonitoring][sms] missing required settings; skipping');
    return false;
  }

  let twilio;
  try {
    // Optional dependency - only required when SMS is enabled.
    // eslint-disable-next-line global-require
    twilio = require('twilio');
  } catch (error) {
    console.warn('[cloudmonitoring][sms] twilio dependency not installed');
    return false;
  }

  const client = twilio(accountSid, authToken);
  const body = settings?.text ?? `Factorio alert: ${itemName} production stopped (0/min).`;

  for (const to of toList) {
    await client.messages.create({ body, from, to });
  }

  return true;
}

module.exports = { notify };
