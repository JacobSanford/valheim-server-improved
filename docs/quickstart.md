---
title: Quick Start
description: Copy the settings, set a password and start the Valheim server
audience: users
doc_type: how-to
tags: [setup, quickstart]
lastReviewed: 2026-11-13
---

# Set Up and Start the Server

Use this page to set up and start the server on a host that meets the [Requirements](index.md#requirements). Clone the repository and run every command from its root:

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

1. **Set the server password.** Replace `SERVER_PASS=changeme` with your own password. It must be at least 5 characters and must not appear in `SERVER_NAME`.
2. **Match the server's user and group to yours.** The server runs as `PUID`/`PGID` and writes `data/`, `server/` and `backups/` as that user. If `id -u` or `id -g` prints a number other than 1000, set the matching variable to that number. Otherwise, leave both unchanged.

Every other setting is in the [Reference](reference.md#environment-variables).

## Start the Server

```bash
./restart.sh
```

The script checks the settings, pulls the latest image, starts the server, then follows the logs. Press Ctrl+C to stop following the logs; the server keeps running. The first start downloads about 4 GB of game server files, and the healthcheck allows it 15 minutes.

The server is ready when the log shows `Game server connected`, and `docker compose ps` shows the container as `healthy`. If `restart.sh` refuses to start or the container stays `unhealthy`, see [Troubleshooting](troubleshooting.md).

Next, [let players join](guides/players.md).
