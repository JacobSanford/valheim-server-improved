---
title: Sleep When Idle
description: Stop the server when nobody is playing and start it on the next connection attempt
audience: users
doc_type: how-to
tags: [sleep, idle, lazytainer, resources]
lastReviewed: 2026-11-13
---

# Sleep When Idle

Use sleep when idle to stop the server when nobody is playing and start it again on the next connection attempt. It is off by default. When it's on, a small extra container, [Lazytainer](https://github.com/vmorganp/Lazytainer), takes over ports 2456–2457 and counts the packets that arrived on them in the last 20 minutes. Once that count has stayed under 10 for another 20 minutes, it stops the server, about 40 minutes after the last player leaves. When more than 10 arrive within 20 minutes, it starts the server again. Exactly 10 keeps a running server awake but doesn't wake a sleeping one.

## Before You Turn It On

- **Lazytainer controls Docker.** It needs the Docker socket to start and stop the server, and read-only mounting doesn't limit what the socket can do. Anyone who takes over that container controls the host; see Docker's [security notes](https://docs.docker.com/engine/security/) on the daemon's attack surface.
- **A public server may never sleep.** Server browsers and internet scans also send packets to the game ports. If they reach the threshold, the server stays awake. This hasn't been tested on a server reachable from the internet. Once it's on, watch the idle count that `./logs.sh` shows. If it keeps resetting before it reaches `SLEEP_AFTER_SECONDS`, raise `SLEEP_MIN_PACKETS` in `env/valheim.env` (see [Tune It](#tune-it)), or set `SERVER_PUBLIC=false` so the server isn't listed in the server browser.

- **Crossplay needs its port in the sleep file too.** The sleep file, `docker-compose.sleep.yml`, replaces the Valheim container's ports, and its `2458:2458/udp` line is commented out. With `CROSSPLAY=true`, uncomment that line as well. Lazytainer counts only ports 2456–2457.
- **Docker Compose 2.18 or later.** The sleep file uses Compose's [`!reset` tag](https://docs.docker.com/reference/compose-file/merge/), which older versions reject.

## Turn It On

Set one variable in `env/valheim.env`, then restart the server.

1. **Turn on sleeping.** In `env/valheim.env`, set:

    ```bash
    SLEEP_WHEN_IDLE=true
    ```

2. **Restart the server.** Run `./restart.sh`, then press Ctrl+C to leave the log view.

`./logs.sh` now also shows Lazytainer counting idle time, for example `300 / 1200 seconds without an active client or sufficient traffic on running container`. While the server sleeps, `docker compose ps -a` shows it as `exited` (stop) or `paused`. Plain `docker compose ps` leaves out a stopped server. Its health reads `unhealthy` until it wakes; that's expected.

The scripts add `docker-compose.sleep.yml` for you and pass it the `SLEEP_` settings from `env/valheim.env`. To run `docker compose` yourself, add the file too, as below, and `docker-compose.override.yml` after it if you have one. Start the server with `./restart.sh`, though: a hand-run `docker compose up` doesn't read those settings and uses the defaults.

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.sleep.yml docker compose ps -a
```

## What Players See

While the server sleeps, it isn't in the **Community** list, so players join with **Join IP**. Their first attempt should wake the server; this hasn't been tested with the game itself.

On a private test server with a small world, a stopped server reached `healthy` 30–36 seconds after the first packet, and a paused server was running again 6 seconds after it. A game update at wake adds its download time. How many packets a real join attempt sends wasn't measured; if one doesn't wake the server, lower `SLEEP_MIN_PACKETS`.

| `SLEEP_METHOD` | Memory while asleep | Wake | First join attempt (expected) |
|---|---|---|---|
| `stop` (default) | Freed | About a minute, longer with a game update | Times out; join again once the server is up |
| `pause` | Kept | A few seconds | May time out; a second attempt gets in |

## How Sleeping Changes Updates and Backups

| | `stop` | `pause` |
|---|---|---|
| Game updates | Checked at every wake, which takes longer when there is one | Checked only while awake. The 40 minutes or so before sleeping are longer than the 15-minute update interval, so each sleep follows an update check |
| Backups | Every wake writes one. When nobody has played since the previous backup, the wake deletes that previous backup, so a run of idle wakes keeps only its newest backup | None while paused |
| Daily restart | Not needed: every wake is a fresh start | Skipped if the server is paused at 5:10 AM |
| World save | Saved every time it sleeps | Not saved: if the host reboots while paused, play since the last autosave is lost |
| Notifications | `server_down` at every sleep, `server_up` at every wake, and `backup` at a wake unless that wake's backup replaced an idle one | None |

Each backup, including the one at wake, deletes backups older than `BACKUPS_KEEP_DAYS` (30 in the env example) but always keeps the newest `BACKUPS_KEEP_MIN` (3). So however long the server sleeps, a wake leaves at least 3 backups. See [Backups and Wipes](backups.md).

## Tune It

| Setting | Default | Change it when |
|---|---|---|
| `SLEEP_AFTER_SECONDS` | `1200` | You want it to sleep sooner or later. Keep it above 900, so an update check runs before each sleep. The scripts refuse less than 300, because a wake must finish first. |
| `SLEEP_MIN_PACKETS` | `10` | Scans or browser queries keep waking it or keep it awake: raise it. A join attempt doesn't wake it: lower it. |
| `SLEEP_METHOD` | `stop` | You want a faster wake and can spare the memory: set it to `pause`. See [What Players See](#what-players-see) and the table above. |

Run `./restart.sh` after changing any of them.

To turn sleeping off, set `SLEEP_WHEN_IDLE=false` and run `./restart.sh`. It removes the Lazytainer container and publishes the ports from the Valheim container again.
