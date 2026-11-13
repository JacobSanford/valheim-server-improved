---
title: Quick Start
description: Copy the settings, set a password and start the Valheim server
audience: users
doc_type: tutorial
tags: [setup, quickstart]
lastReviewed: 2026-11-13
---

# Quick Start

Clone the repository and run every command from its root:

```bash
git clone https://github.com/JacobSanford/valheim-server-improved.git
cd valheim-server-improved
```

## Copy the Settings

The copy holds the server password, so make it readable only by you:

```bash
cp env/valheim.env.example env/valheim.env
chmod 600 env/valheim.env
```

## Set the Password and User

In `env/valheim.env`:

1. Replace `SERVER_PASS=changeme` with your own password. It must be at least 5 characters and must not appear in `SERVER_NAME`. The game server rejects both, and `restart.sh` checks them before starting.
2. The server runs as `PUID`/`PGID` and writes `data/` and `backups/` as that user. If `id -u` or `id -g` prints a number other than 1000, set the matching variable to that number.

Every other setting is in the [Reference](reference.md#environment-variables).

## Start the Server

```bash
./restart.sh
```

The script checks the password, starts the server, then follows the logs. Press Ctrl+C to leave them; the server keeps running. The first start takes longer, because it downloads the game server files.

The server is ready when the log shows `Game server connected`, and `docker compose ps` shows the container as `healthy`.

Next, [let players join](guides/players.md).
