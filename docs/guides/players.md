---
title: Players, Admins and Bans
description: Forward the ports, connect from the game, and manage admins, bans and the whitelist
audience: users
doc_type: how-to
tags: [network, joining, admins, bans]
lastReviewed: 2026-11-13
---

# Let Players Join and Manage Admins and Bans

Use this page when players outside your network need to join your server, or when you set its admins, bans and whitelist.

## Forward the Ports

Forward UDP ports 2456–2457 to the host. To check the forward, have a player outside your network join with **Join IP**.

With `CROSSPLAY=true`, uncomment the `2458:2458/udp` line in `docker-compose.yml`, and also in `docker-compose.sleep.yml` with `SLEEP_WHEN_IDLE=true`, then run `./restart.sh`. Crossplay needs no forward: Iron Gate's server manual says a crossplay server connects through a relay.

## Join from the Game

Players join in one of two ways, then enter the server password, the `SERVER_PASS` value in `env/valheim.env`:

- **Join Game** → **Community**. Type part of your `SERVER_NAME` in the filter to find it. The server is listed only while `SERVER_PUBLIC=true`.
- **Join Game** → **Join IP**, then enter the host's public IP address or hostname followed by `:2456`. This works even when `SERVER_PUBLIC=false`.

## Manage Admins, Bans and the Whitelist

The lists are `adminlist.txt`, `bannedlist.txt` and `permittedlist.txt` in `data/`. The permitted list is the whitelist: when it has entries, only those players can join. Each entry is a case-sensitive platform user ID, such as `Steam_<STEAMID64>`. The format comes from Iron Gate's server manual, `server/server/Valheim Dedicated Server Manual.pdf`, which downloads with the game server files. A player finds theirs in the F2 panel in game. It also appears in the server log when they connect; `./logs.sh` shows the log.

Manage each list one of two ways, not both:

- Set `ADMINLIST_IDS`, `BANNEDLIST_IDS` or `PERMITTEDLIST_IDS` in `env/valheim.env` as IDs separated by spaces. A non-empty variable replaces everything in the matching file each time the container starts. The container starts on `./restart.sh` and on every wake with `SLEEP_METHOD=stop`; the daily restart leaves the file alone. Copy any IDs already in that file into the variable, including players banned in game, or the next start removes them. Then run `./restart.sh`.
- Leave the variable unset and edit the file in `data/`, one ID per line, then run `./restart.sh`.

The lists survive a wipe with `./wipe-restart.sh`; see [Backups and Wipes](backups.md#wipe-the-world).
