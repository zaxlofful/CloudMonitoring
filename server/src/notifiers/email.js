const nodemailer = require('nodemailer');

async function notify(itemName, settings) {
  const smtpHost = settings?.smtp_host;
  const smtpPort = settings?.smtp_port;
  const senderEmail = settings?.sender_email;
  const senderPassword = settings?.sender_password;
  const recipients = settings?.recipients;

  if (!smtpHost || !smtpPort || !senderEmail || !senderPassword || !Array.isArray(recipients) || recipients.length === 0) {
    console.warn('[cloudmonitoring][email] missing required settings; skipping');
    return false;
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: Boolean(settings?.secure ?? false),
    auth: { user: senderEmail, pass: senderPassword },
  });

  const subject = settings?.subject ?? `Factorio alert: ${itemName} production stopped`;
  const text = settings?.text ?? `Production for ${itemName} has dropped to 0.`;

  await transporter.sendMail({
    from: senderEmail,
    to: recipients.join(','),
    subject,
    text,
  });

  return true;
}

module.exports = { notify };
