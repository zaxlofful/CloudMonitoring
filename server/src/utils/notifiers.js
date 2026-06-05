const email = require('../notifiers/email');
const sms = require('../notifiers/sms');
const webhook = require('../notifiers/webhook');

const notifiers = {
  email,
  webhook,
  sms,
};

function getNotifier(type) {
  return notifiers[type] ?? null;
}

module.exports = { getNotifier };
