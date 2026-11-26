---
title: valheim-server-improved
description: A ready-to-run Docker Compose setup for the community Valheim server image, with safer defaults
audience: users
doc_type: explanation
tags: [overview]
lastReviewed: 2026-11-13
---

# valheim-server-improved

valheim-server-improved is a ready-to-run Docker Compose setup for the [community-valheim-tools/valheim-server](https://github.com/community-valheim-tools/valheim-server-docker) image. It uses that image unchanged and improves the setup around it:

- The server runs as the user and group set in `PUID` and `PGID` (default 1000), and only the ports you need are open.
- A healthcheck reports `healthy` once the game is listening, and container logs are capped at about 30 MB.
- `restart.sh` refuses to start with the example password or one the server would reject.
- A wipe archives everything first and keeps your admins; [restores are documented](guides/backups.md).
- [Discord notifications](guides/notifications.md) are built in and stay off until you turn them on.
- It can [stop the server while nobody plays](guides/sleep.md) and start it on the next connection attempt. This is also off until you turn it on.

[Improvements over Upstream](improvements.md) compares it with the upstream example point by point. Check the requirements below, then follow the [Quick Start](quickstart.md).

## Requirements

- A Linux host with [Docker Engine](https://docs.docker.com/engine/install/) and the [compose plugin](https://docs.docker.com/compose/install/linux/), and a user in the [`docker` group](https://docs.docker.com/engine/install/linux-postinstall/) to run the scripts. [Sleep When Idle](guides/sleep.md) needs the compose plugin 2.18 or later.
- About 4 GB of disk for the game server files.
- UDP ports 2456–2457 forwarded to the host. See [Players, Admins and Bans](guides/players.md).
- CPU and memory for your player count:

| Players online, or modded | CPU | Memory |
|---|---|---|
| 1–5 | 2 fast vCPUs | 4 GB |
| 6–10 | 4 fast vCPUs | 6–8 GB |
| Modded | 4 fast vCPUs to start | 8 GB to start |

Vanilla Valheim allows at most 10 players at once. Most of the server's CPU load runs on one thread, so a few fast cores beat many slow ones. These figures are starting points based on [Supercraft's hosting data](https://supercraft.host/wiki/valheim/dedicated_server_requirements/); Iron Gate publishes no server requirements. Check `docker stats` during a busy session and compare the memory use with the container limit below.

### Container Limits

By default, `docker-compose.yml` caps the container at 8 GB of memory, sets a 4 GB memory reservation (a soft limit Docker applies when the host runs short of memory), and leaves CPU unlimited. To change them, put your own `deploy.resources` for the `valheim` service in a `docker-compose.override.yml` beside `docker-compose.yml`. Compose merges that file over `docker-compose.yml`, the scripts load it in sleep mode too, and git ignores it, so `git pull` keeps your change. To remove the limits, set `deploy: !reset null` for the service there. See Docker's [merge rules](https://docs.docker.com/reference/compose-file/merge/).
