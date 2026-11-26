---
title: Discord Notifications
description: Post server and player events to a Discord channel
audience: users
doc_type: how-to
tags: [notifications, discord, webhooks]
lastReviewed: 2026-11-13
---

# Post Server Events to Discord

Use this guide when you want the server to post events, such as starting, shutting down and a player spawning, to a Discord channel. Notifications are off until you turn them on. These steps start from a server set up with the [Quickstart](../quickstart.md).

## Turn Them On

Create a webhook in Discord, set it in `env/valheim.env`, restart the server, then send a test message.

1. **Create a Discord webhook.** Open **Server Settings** → **Integrations** → **Webhooks**, create a webhook for the channel you want, and copy its URL. **Integrations** requires the **Manage Webhooks** permission on that Discord server. Discord's [Intro to Webhooks](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) shows the steps.
2. **Set the webhook and events in `env/valheim.env`.** List the [events](#events) you want, comma separated, and paste the webhook URL:

    ```bash
    NOTIFY_EVENTS=server_up,server_down,player_spawned
    NOTIFY_DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
    ```

3. **Restart the server.** Run `./restart.sh`, then press Ctrl+C to leave the log view. The server keeps running.
4. **Send a test message.** Run `./notify-test.sh`. It sends the message whatever `NOTIFY_EVENTS` says. On success it prints `notify: discord: sent`; on failure it prints the reason, for example `discord: HTTP 401: Invalid Webhook Token`, and exits non-zero. If it fails, see [Notifications Don't Arrive](../troubleshooting.md#notifications-dont-arrive).

The webhook URL lets anyone post to your channel. Keep it in `env/valheim.env`, which git ignores and only you can read.

## Events

| Event | Sent when |
|---|---|
| `server_up` | The server starts accepting connections. |
| `server_down` | The server begins shutting down. |
| `restart` | The server restarts to apply a game update. `server_down` and `server_up` follow it. The daily `RESTART_CRON` restart sends only `server_down` and `server_up`. |
| `backup` | A world backup is written. See [Backups and Wipes](backups.md) for when. Not sent when the backup replaced an idle one. |
| `player_spawned` | A player spawns into the world, including after a death. |

`NOTIFY_EVENTS=all` turns on every event. Messages are posted under the server's name; set `NOTIFY_DISCORD_USERNAME` to change it (Discord rejects names containing "discord").

## When Sending Fails

The server keeps running. The reason goes to the container log (`./logs.sh`), with the HTTP status and Discord's reason but never the webhook URL. Each attempt times out after 10 seconds, and failed messages are not retried.

## Keep Your Own Hook Commands

The env example connects the image's event hooks, such as `POST_SERVER_LISTENING_HOOK`, to `notify/notify.sh`. Keep those lines in `env/valheim.env`; without them, those events send nothing. To run your own command on the same event, append it after a `;`, in place of `<YOUR_COMMAND>`:

```bash
PRE_RESTART_HOOK=/opt/notify/notify.sh restart; <YOUR_COMMAND>
```

## Add Another Service

Each service is an adapter: a `.sh` file in `notify/adapters/` that defines two functions. `notify.sh` sources every `.sh` file there for each event.

| Function | Does |
|---|---|
| `adapter_enabled` | Exits 0 if the adapter is configured, usually because its webhook variable is set. |
| `adapter_send EVENT MESSAGE` | Delivers `MESSAGE`. Exits 1 on failure, with the reason on stderr. `notify.sh` reads exit status 2 as "not configured" and logs nothing. |

`notify/adapters/discord.sh` is the example. `notify.sh` runs every configured adapter for each event, so Discord and a new service can both be on at once. After you set the new adapter's variable in `env/valheim.env`, run `./restart.sh` and then `./notify-test.sh`, which sends the test message through every configured adapter.
