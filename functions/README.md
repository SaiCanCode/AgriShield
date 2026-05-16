# AgriShield Notification Functions

This folder contains the Firebase Functions trigger that watches Realtime Database alert writes under `/nodes/{nodeId}/alerts/{alertTs}` and sends FCM push notifications to subscribed devices.

## Install

```bash
cd functions
npm install
```

## Deploy

```bash
firebase deploy --only functions
```

## Runtime flow

- Flutter app registers its FCM token at `/notification_tokens/{uid}`.
- Flutter app subscribes itself to the nodes it should receive alerts for at `/node_subscribers/{nodeId}/{uid}`.
- The database trigger sends a push notification when a new alert is written.
