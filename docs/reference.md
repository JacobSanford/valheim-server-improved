---
title: Reference
description: Environment variables, scripts, ports and files
audience: users
doc_type: reference
tags: [reference, environment, commands, ports, files]
lastReviewed: 2026-11-13
---

# Reference

## Environment Variables

Set in `env/valheim.env`. Values shown are those in `env/valheim.env.example`. *Unset* means the line is commented out there; *empty* means the line is present with no value. The `SLEEP_` lines after `SLEEP_WHEN_IDLE` are commented out, and their value shown is the default the scripts use.

| Variable | Value | Meaning |
|---|---|---|
| `SERVER_NAME` | `My Valheim Server` | The name shown in the server browser. |
| `WORLD_NAME` | `Dedicated` | The world save to load. If no save has this name, the server creates a new world. |
| `SERVER_PASS` | `changeme` | The password players enter to join. At least 5 characters, and not part of the server name. `restart.sh` refuses the example value `changeme`, and skips these checks when `SERVER_PASS_FILE` is set. |
| `SERVER_PORT` | `2456` | The game port. The server also uses the next port (2457). If you change it, change the `ports:` mapping in `docker-compose.yml` to match. With `SLEEP_WHEN_IDLE=true`, also change the `ports:` mapping and the `lazytainer.group.valheim.ports` label in `docker-compose.sleep.yml`. |
| `SERVER_PUBLIC` | `true` | Lists the server in the public server browser. |
| `CROSSPLAY` | `false` | Allows Xbox, Microsoft Store and Apple App Store players to join. |
| `TZ` | `Etc/UTC` | The [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) used for logs and the cron schedules below. |
| `PUID` / `PGID` | `1000` | The user and group the server runs as, and that own the files on the host. The image's default is `0` (root). |
| `BACKUPS` | `true` | Saves a backup of the world to `backups/` each time the container starts and at 5 minutes past each hour. |
| `BACKUPS_KEEP_DAYS` | `30` | Deletes backups older than this many days, except the newest `BACKUPS_KEEP_MIN`. Applied by `hooks/idle-backups.sh`. See [Backups and Wipes](guides/backups.md). |
| `BACKUPS_KEEP_MIN` | `3` | Age-based pruning always keeps the newest this many backups. `restart.sh` refuses a value larger than `BACKUPS_MAX_COUNT`. |
| `BACKUPS_MAX_AGE` | `36500` | The image's own age limit, which can't keep a minimum. 36500 days turns it off; `restart.sh` requires that while `BACKUPS_KEEP_DAYS` or `BACKUPS_KEEP_MIN` is set. |
| `BACKUPS_MAX_COUNT` | `12` | Keeps at most this many backups. |
| `BACKUPS_IF_IDLE` | `false` | Stops backing up an hour after the last player leaves. |
| `UPDATE_CRON` | `*/15 * * * *` | How often to check for game updates, as a [cron schedule](https://en.wikipedia.org/wiki/Cron#Overview). |
| `UPDATE_IF_IDLE` | `true` | Applies an update only when no players are online. |
| `RESTART_CRON` | `10 5 * * *` | Restarts the server every day at 5:10 AM. |
| `RESTART_IF_IDLE` | `true` | Skips the daily restart if any players are online. |
| `STATUS_HTTP` | `true` | Serves server status at `http://127.0.0.1:8456/status.json`, reachable only from the host. Reports the server only while `SERVER_PUBLIC=true`. |
| `ADMINLIST_IDS` | unset | Admins, as platform IDs such as `Steam_<STEAMID64>`, separated by spaces. Replaces `data/adminlist.txt`. |
| `BANNEDLIST_IDS` | unset | Banned players. Replaces `data/bannedlist.txt`. |
| `PERMITTEDLIST_IDS` | unset | The only players allowed to join. Replaces `data/permittedlist.txt`. |
| `NOTIFY_EVENTS` | empty | Notification events to send, comma separated: `server_up`, `server_down`, `restart`, `backup`, `player_spawned`, or `all`. Empty sends nothing. |
| `NOTIFY_DISCORD_WEBHOOK` | empty | Discord webhook URL. Empty turns the Discord adapter off. |
| `NOTIFY_DISCORD_USERNAME` | unset | The name messages are posted under. Defaults to `SERVER_NAME`. |
| `SLEEP_WHEN_IDLE` | `false` | Stops the server when nobody is playing and starts it on the next connection attempt. See [Sleep When Idle](guides/sleep.md). |
| `SLEEP_METHOD` | `stop` | `stop` frees the memory and wakes in about 35 seconds; `pause` keeps it and wakes in about 5 seconds. |
| `SLEEP_AFTER_SECONDS` | `1200` | How far back packets are counted, in seconds, and how long that count must stay below `SLEEP_MIN_PACKETS` before the server sleeps. 300 to 65535. Keep it above 900, so an update check runs before each sleep. |
| `SLEEP_MIN_PACKETS` | `10` | The number of packets on ports 2456–2457 within `SLEEP_AFTER_SECONDS` that keeps the server awake. A sleeping server wakes only when the count goes above this number. 1 to 65535. |

The env example also sets the image's event hooks (`POST_SERVER_LISTENING_HOOK`, `PRE_SERVER_SHUTDOWN_HOOK`, `PRE_RESTART_HOOK`, `POST_BACKUP_HOOK`) and two log filters (`VALHEIM_LOG_FILTER_CONTAINS_PlayerSpawned` and `VALHEIM_LOG_FILTER_CONTAINS_PlayerCount`, each with an `ON_` command). They feed notifications and the backup pruning in `hooks/idle-backups.sh`. To run your own command from a hook, append `; your-command` to its value. See [Discord Notifications](guides/notifications.md) and [Backups and Wipes](guides/backups.md).

The image's [README](https://github.com/community-valheim-tools/valheim-server-docker) lists every documented option, including those not set here. A few more are undocumented; they are listed with their defaults in the image's [`defaults`](https://github.com/community-valheim-tools/valheim-server-docker/blob/main/defaults) file.

## Commands

Run from the repository root.

| Script | Does |
|---|---|
| `restart.sh` | Checks `SERVER_PASS`, the backup settings and, with `SLEEP_WHEN_IDLE=true`, the sleep settings. Then pulls the latest image, starts or restarts the server, and follows the last 200 log lines. Restarting disconnects players. |
| `stop.sh` | Stops the server and removes the container. The world is kept. |
| `logs.sh` | Follows the server logs, starting from the last 200 lines. |
| `notify-test.sh` | Sends a test notification from the running server to every configured adapter. Fails while the server is stopped or asleep, or when no adapter is configured. |
| `wipe-restart.sh` | Archives `data/` and `backups/`, deletes every saved world (not only `WORLD_NAME`) and all backups, keeps the player lists, and starts a new world. |
| `lib.sh` | Helpers the other scripts share. Not run directly. |

## Ports

| Port | Purpose | Published |
|---|---|---|
| 2456–2457/udp | Game and query ports | On every interface |
| 2458/udp | Crossplay | Only if uncommented in `docker-compose.yml` |
| 8456/tcp | Status page (`status.json`) | On `127.0.0.1` only |

With `SLEEP_WHEN_IDLE=true`, the `lazytainer` container ([Lazytainer](https://github.com/vmorganp/Lazytainer)) in `docker-compose.sleep.yml` publishes these ports instead, and Valheim shares its network. For crossplay, uncomment the `2458:2458/udp` line there too.

## Files

| Path | Contents | In git |
|---|---|---|
| `data/` | World saves and the admin, ban and permitted lists. Mounted in the container as `/config`. | No |
| `server/` | The game server files (about 4 GB), downloaded automatically. | No |
| `backups/` | The hourly world backups. | No |
| `wipe-archives/` | Archives saved by `wipe-restart.sh` and by restores. | No |
| `env/valheim.env` | Your settings, including the server password and webhook. | No |
| `notify/` | The notification script and its adapters. Mounted read-only as `/opt/notify`. | Yes |
| `hooks/` | `idle-backups.sh`, which prunes backups taken while nobody plays and backups older than `BACKUPS_KEEP_DAYS`. Mounted read-only as `/opt/hooks`. | Yes |
| `docker-compose.yml` | The Valheim container: image, ports, mounts, health check and memory limits. | Yes |
| `env/valheim.env.example` | The example settings, copied to `env/valheim.env`. | Yes |
| `docker-compose.sleep.yml` | Added on top of `docker-compose.yml` by the scripts when `SLEEP_WHEN_IDLE=true`. | Yes |
| `data/.player-activity` | Touched when a player spawns, and every 10 minutes while players are online. `idle-backups.sh` uses its date. | No |
