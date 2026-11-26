---
title: Improvements over Upstream
description: How this setup differs from the community image's own Compose example
audience: users
doc_type: explanation
tags: [comparison]
lastReviewed: 2026-11-13
---

# Improvements over Upstream

valheim-server-improved runs the [community-valheim-tools/valheim-server](https://github.com/community-valheim-tools/valheim-server-docker) image unchanged. The game server, the update and backup services, and the image's settings all come from upstream. What differs is the Compose files, the defaults in `env/valheim.env.example`, the helper scripts, the hooks in `hooks/` and `notify/`, and the documentation. The optional sleep-when-idle mode adds a second image, Lazytainer (`ghcr.io/vmorganp/lazytainer`).

Comparisons below are against upstream's [`docker-compose.yaml`](https://github.com/community-valheim-tools/valheim-server-docker/blob/main/docker-compose.yaml) and the image's [`defaults`](https://github.com/community-valheim-tools/valheim-server-docker/blob/main/defaults) file.

## Safer Defaults

| | Upstream | This setup |
|---|---|---|
| User the server runs as | root (`PUID=0`, `PGID=0`) | Your user (`PUID=1000`, `PGID=1000`), so files on the host are yours |
| Supervisor web UI port 9001 | Published on every interface, although the UI is off by default | Not published |
| Crossplay port 2458/udp | Always published | Published only if you uncomment it for `CROSSPLAY=true` |
| Status page | Not published | Published on `127.0.0.1` only |
| Restart policy | `always`: a stopped server comes back after a reboot | `unless-stopped`: a stopped server stays stopped |
| Password check | The server fails to start, and the reason is in the log | `restart.sh` refuses to start with the example password, one under 5 characters, or one inside the server name |

## Fewer Ways to Lose Data

- **Wipes archive first.** `wipe-restart.sh` checks it can delete everything before it deletes anything, asks you to type the world name, then saves `data/` and `backups/` to a `.tar.gz` in `wipe-archives/`.
- **Wipes keep your admins.** The admin, ban and permitted lists survive a wipe.
- **Restores are documented.** [Backups and Wipes](guides/backups.md) has step-by-step restores from an hourly backup and from a wipe archive. Upstream documents none.
- **The newest backups survive any age limit.** The image deletes every backup older than `BACKUPS_MAX_AGE` (3 days by default), even the last one. Here, `BACKUPS_KEEP_DAYS` deletes old backups but always keeps the newest `BACKUPS_KEEP_MIN` (3 in the env example), so a server left off for months still has them.
- **Backups of the last session survive idle hours.** `BACKUPS_IF_IDLE=false` stops backups an hour after the last player leaves. The image's default (`true`) keeps backing up while nobody plays. With this setup's limit of 12 (`BACKUPS_MAX_COUNT=12`), one idle night would replace every backup of the last session. After each backup, including the one every container start takes, `hooks/idle-backups.sh` also deletes the previous backup if nobody has played since it.

## Operations

| | Upstream | This setup |
|---|---|---|
| Healthcheck | None | `healthy` once the game is listening, from the image's own status file. Works on private servers too. |
| Container logs | Unlimited | At most about 30 MB (3 × 10 MB) |
| Memory | No limits | 4 GB reserved, 8 GB cap, with sizing guidance by player count |
| Paths | Fixed to `$HOME/valheim-server` | Relative to the repository, so it runs from any folder |
| Day-to-day commands | `docker compose` by hand | `restart.sh`, `stop.sh`, `logs.sh`, `wipe-restart.sh` |
| `restart.sh` | — | Pulls the image and always restarts, even when nothing changed |
| Idle servers | Always running | Optional [sleep when idle](guides/sleep.md): stops the server when nobody plays and starts it on the next connection attempt. The Lazytainer container it adds holds the Docker socket, and with it control of the host |
| Backup history | Every container start adds a backup, and with no count limit (`BACKUPS_MAX_COUNT=0`) they pile up | [Backups](guides/backups.md) taken while nobody played replace each other |
| Notifications | Hand-written `curl` commands in hook variables, with quoting examples per shell | [Discord notifications](guides/notifications.md) built in and off by default: set a webhook and list the events. Messages are JSON-escaped, and player names can't ping `@everyone`. Other services plug in as adapters. |

## Documentation

- Admins, bans and the whitelist (the permitted list), including that `ADMINLIST_IDS` replaces the file's contents.
- Resource sizing by player count.
- How players join, and the ports to forward.
- A pointer to the image's undocumented variables in its `defaults` file.

## What Stays the Same

- **Performance.** Same image, same game server. Nothing here makes it faster.
- **Features.** Mods, hooks, crossplay and everything else come from the image. Its [README](https://github.com/community-valheim-tools/valheim-server-docker) remains the full reference.
