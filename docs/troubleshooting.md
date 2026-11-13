---
title: Troubleshooting
description: Fix a server that won't start, stays unhealthy, or can't send notifications
audience: users
doc_type: how-to
tags: [troubleshooting]
lastReviewed: 2026-11-13
---

# Troubleshooting

## `restart.sh` Refuses to Start

It checks `env/valheim.env` before starting and names the problem:

| Message | Fix |
|---|---|
| `env/valheim.env not found` | Copy the example. See the [Quick Start](quickstart.md). |
| `SERVER_PASS ... is still the example value` | Set your own password. |
| `SERVER_PASS ... must be at least 5 characters` | Use a longer password. |
| `SERVER_PASS must not appear in SERVER_NAME` | Change one of them. |
| `With BACKUPS_KEEP_DAYS or BACKUPS_KEEP_MIN set, set BACKUPS_MAX_AGE=36500` | Set `BACKUPS_MAX_AGE=36500`, as in the env example. An older env file has a smaller value. See [Backups and Wipes](guides/backups.md). |
| `BACKUPS_KEEP_MIN ... is larger than BACKUPS_MAX_COUNT` | Lower `BACKUPS_KEEP_MIN` or raise `BACKUPS_MAX_COUNT`. |
| `BACKUPS_KEEP_DAYS ... must be a whole number of days` or `BACKUPS_KEEP_MIN ... must be a whole number` | Fix the value in `env/valheim.env`. |
| `SLEEP_METHOD`, `SLEEP_AFTER_SECONDS` or `SLEEP_MIN_PACKETS ... must be` | Fix the value; the message gives the allowed range. See [Sleep When Idle](guides/sleep.md). |

## The Server Stays Unhealthy

If `docker compose ps` shows `unhealthy`, or still shows `health: starting` a few minutes after the download finishes, read the log with `./logs.sh`. The healthcheck allows the first start 15 minutes for the download. With `SLEEP_WHEN_IDLE=true`, `unhealthy` is also expected while the server sleeps; see [Sleep When Idle](guides/sleep.md).

If the log shows `Steamcmd needs to be online to update`, the container can't reach the internet, so it can't download the game. Check from inside the container:

```bash
docker compose exec valheim curl -sS -o /dev/null -w '%{http_code}\n' https://api.steampowered.com/
```

Any HTTP status, such as `404`, means it can connect. A timeout means something on the host blocks traffic from Docker networks, such as a VPN client or a firewall that only allows Docker's default bridge.

## The Server Doesn't Wake

With `SLEEP_WHEN_IDLE=true`, a join attempt has to send more than `SLEEP_MIN_PACKETS` packets to ports 2456–2457 to wake the server. Lower `SLEEP_MIN_PACKETS` and run `./restart.sh`. Players must use **Join IP**, because a sleeping server isn't in the **Community** list. See [Sleep When Idle](guides/sleep.md).

## The Status Page Shows an Error

`status.json` reports `error` until the server answers status queries, so expect one for the first minute. It reports the server only while `SERVER_PUBLIC=true`, so for a private server, use `docker compose ps` instead.

## `wipe-restart.sh` Says a Folder Is Not Writable

Some files under `data/` or `backups/` belong to another user, often root from a run without `PUID`/`PGID`. Nothing was deleted. Take ownership, then run the wipe again:

```bash
sudo chown -R "$(id -u):$(id -g)" data backups
```

## Notifications Don't Arrive

Run `./notify-test.sh`. It prints the reason a send failed:

| Output | Fix |
|---|---|
| `notify: no adapter is configured` | Set `NOTIFY_DISCORD_WEBHOOK` in `env/valheim.env` and run `./restart.sh`. |
| `discord: HTTP 401` or `HTTP 404`, `Invalid Webhook Token` or `Unknown Webhook` | The webhook URL is wrong or the webhook was deleted. Copy it again from Discord. |
| `Could not resolve host` | The container can't reach the internet. See [The Server Stays Unhealthy](#the-server-stays-unhealthy). |

If the test arrives but events don't, check the event is listed in `NOTIFY_EVENTS` and the hook lines from `env/valheim.env.example` are in your `env/valheim.env`.
