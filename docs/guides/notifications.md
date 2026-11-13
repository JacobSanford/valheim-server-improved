---
title: Discord Notifications
description: Post server and player events to a Discord channel
audience: users
doc_type: how-to
tags: [notifications, discord, webhooks]
lastReviewed: 2026-11-13
---

# Discord Notifications

Notifications are off until you turn them on.

## Turn Them On

1. In Discord, open **Server Settings** → **Integrations** → **Webhooks**, create a webhook for the channel you want, and copy its URL. Discord's [Intro to Webhooks](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) shows the steps.
2. In `env/valheim.env`, set the webhook and list the events you want, comma separated:

    ```bash
    NOTIFY_EVENTS=server_up,server_down,player_spawned
    NOTIFY_DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
    ```

3. Run `./restart.sh`, then press Ctrl+C to leave the log view. The server keeps running.
4. Run `./notify-test.sh`. It sends a test message whatever `NOTIFY_EVENTS` says. On success it prints `notify: discord: sent`; on failure it prints the reason, for example `discord: HTTP 401: Invalid Webhook Token`, and exits non-zero.

The webhook URL lets anyone post to your channel. Keep it in `env/valheim.env`, which git ignores and only you can read.

## Events

| Event | Sent when |
|---|---|
| `server_up` | The server starts accepting connections. |
| `server_down` | The server begins shutting down. |
| `restart` | The server restarts to apply a game update. The daily `RESTART_CRON` restart sends `server_down` and `server_up` instead. |
| `backup` | A world backup is written. See [Backups and Wipes](backups.md) for when. Not sent when the backup replaced an idle one. |
| `player_spawned` | A player spawns into the world, including after a death. |

`NOTIFY_EVENTS=all` turns on every event. Messages are posted under the server's name; set `NOTIFY_DISCORD_USERNAME` to change it (Discord rejects names containing "discord").

## When Sending Fails

The server carries on. The reason goes to the container log (`./logs.sh`), with the HTTP status and Discord's reason but never the webhook URL. Each attempt gives up after 10 seconds, and failed messages are not retried.

## Keep Your Own Hook Commands

The env example connects the image's event hooks, such as `POST_SERVER_LISTENING_HOOK`, to `notify/notify.sh`. Keep those lines when you copy settings across. To run your own command on the same event, append it after a `;`, in place of `<YOUR_COMMAND>`:

```bash
PRE_RESTART_HOOK=/opt/notify/notify.sh restart; <YOUR_COMMAND>
```

## Add Another Service

Each service is an adapter: a file in `notify/adapters/` that defines two functions.

| Function | Does |
|---|---|
| `adapter_enabled` | Exits 0 if the adapter is configured, usually because its webhook variable is set. |
| `adapter_send EVENT MESSAGE` | Delivers `MESSAGE`. Exits non-zero on failure, with the reason on stderr. |

`notify/adapters/discord.sh` is the example. `notify.sh` runs every enabled adapter for each event, so Discord and a new service can both be on at once.
