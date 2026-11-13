---
title: Players, Admins and Bans
description: Forward the ports, connect from the game, and manage admins, bans and the whitelist
audience: users
doc_type: how-to
tags: [network, joining, admins, bans]
lastReviewed: 2026-11-13
---

# Players, Admins and Bans

## Forward the Ports

Forward UDP ports 2456–2457 to the host. With `CROSSPLAY=true`, also forward UDP 2458, uncomment the `2458:2458/udp` line in `docker-compose.yml`, and run `./restart.sh`.

## Join from the Game

Players join in one of two ways, then enter the server password:

- **Join Game** → **Community**. The list loads only 200 servers at a time, so type part of your `SERVER_NAME` in the filter. The server is listed only while `SERVER_PUBLIC=true`.
- **Join Game** → **Join IP**, then enter the host's public IP address or hostname. Port 2456 is the default and can be left off. This works even when `SERVER_PUBLIC=false`.

## Manage Admins, Bans and the Whitelist

The lists are `adminlist.txt`, `bannedlist.txt` and `permittedlist.txt` in `data/`. When the permitted list has entries, only those players can join. Each entry is a platform user ID, such as `Steam_<STEAMID64>`, and is case sensitive, according to Iron Gate's server manual (`server/server/Valheim Dedicated Server Manual.pdf`, downloaded with the game server files). A player finds theirs in the F2 panel in game; it also appears in the server log when they connect.

Manage each list one of two ways, not both:

- Set `ADMINLIST_IDS`, `BANNEDLIST_IDS` or `PERMITTEDLIST_IDS` in `env/valheim.env` as IDs separated by spaces, then run `./restart.sh`. A non-empty variable replaces everything in the matching file.
- Leave the variable unset and edit the file in `data/`, one ID per line, then run `./restart.sh`.

The lists survive a wipe.
