const admin = require('firebase-admin');
const { onValueCreated } = require('firebase-functions/v2/database');
const logger = require('firebase-functions/logger');

admin.initializeApp();

function buildAlertCopy(alertType, nodeId, payload) {
  const readableNode = nodeId.replace(/_/g, ' ');
  const type = String(alertType || 'unknown').toLowerCase();
  const value = payload.value ?? payload.threshold ?? '';
  const threshold = payload.threshold ?? '';

  switch (type) {
    case 'drought':
      return {
        title: 'Drought alert',
        body: `Low soil moisture detected on ${readableNode}. Value: ${value}% .`,
      };
    case 'flood':
      return {
        title: 'Flood alert',
        body: `High soil moisture detected on ${readableNode}. Value: ${value}% .`,
      };
    case 'heat':
      return {
        title: 'Heat alert',
        body: `High temperature detected on ${readableNode}. Value: ${value}°C.`,
      };
    case 'blight':
      return {
        title: 'Blight risk alert',
        body: `Humidity and temperature conditions on ${readableNode} match blight risk.`,
      };
    default:
      return {
        title: 'AgriShield alert',
        body: `New alert on ${readableNode}. Value: ${value}, threshold: ${threshold}.`,
      };
  }
}

async function collectRecipientTokens(nodeId) {
  const subscribersSnap = await admin.database().ref(`node_subscribers/${nodeId}`).get();
  if (!subscribersSnap.exists()) {
    return [];
  }

  const subscriberMap = subscribersSnap.val() || {};
  const uids = Object.keys(subscriberMap);
  if (uids.length === 0) {
    return [];
  }

  const tokenRefs = uids.map((uid) => admin.database().ref(`notification_tokens/${uid}`).get());
  const tokenSnaps = await Promise.all(tokenRefs);

  const tokens = [];
  for (let index = 0; index < tokenSnaps.length; index += 1) {
    const tokenSnap = tokenSnaps[index];
    const uid = uids[index];
    if (!tokenSnap.exists()) continue;

    const tokenData = tokenSnap.val() || {};
    if (typeof tokenData.token === 'string' && tokenData.token.length > 0) {
      tokens.push({ uid, token: tokenData.token });
    }
  }

  return tokens;
}

exports.notifyAlertCreated = onValueCreated('/nodes/{nodeId}/alerts/{alertTs}', async (event) => {
  const nodeId = event.params.nodeId;
  const alertTs = event.params.alertTs;
  const payload = event.data.val() || {};
  const alertType = payload.type || payload.alert_type || 'unknown';

  if (!nodeId || !alertTs) {
    logger.warn('Skipping alert notification because nodeId or alertTs was missing', { nodeId, alertTs });
    return;
  }

  const recipients = await collectRecipientTokens(nodeId);
  if (recipients.length === 0) {
    logger.info('No recipients configured for alert', { nodeId, alertTs });
    return;
  }

  const copy = buildAlertCopy(alertType, nodeId, payload);
  const tokens = recipients.map((recipient) => recipient.token);
  const message = {
    notification: {
      title: copy.title,
      body: copy.body,
    },
    data: {
      nodeId: String(nodeId),
      alertTs: String(alertTs),
      alertType: String(alertType),
      value: String(payload.value ?? ''),
      threshold: String(payload.threshold ?? ''),
      smsSent: String(Boolean(payload.sms_sent)),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'agrishield_alerts',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
    tokens,
  };

  const result = await admin.messaging().sendEachForMulticast(message);
  const invalidTokens = [];

  result.responses.forEach((response, index) => {
    if (!response.success) {
      const errorCode = response.error && response.error.code ? response.error.code : 'unknown';
      logger.warn('Failed to send alert notification', {
        nodeId,
        alertTs,
        uid: recipients[index].uid,
        errorCode,
      });

      if (errorCode === 'messaging/registration-token-not-registered' ||
          errorCode === 'messaging/invalid-registration-token') {
        invalidTokens.push(recipients[index]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    const updates = {};
    for (const recipient of invalidTokens) {
      updates[`notification_tokens/${recipient.uid}`] = null;
    }
    await admin.database().ref().update(updates);
  }

  await admin.database().ref(`notification_delivery/${nodeId}/${alertTs}`).set({
    sentAt: admin.database.ServerValue.TIMESTAMP,
    recipientCount: tokens.length,
    successCount: result.successCount,
    failureCount: result.failureCount,
    alertType,
  });

  logger.info('Alert notification processed', {
    nodeId,
    alertTs,
    recipientCount: tokens.length,
    successCount: result.successCount,
    failureCount: result.failureCount,
  });
});
