---
title: Backups and Wipes
description: Restore the world from a backup, or wipe it and start a new one
audience: users
doc_type: how-to
tags: [backups, restore, wipe]
lastReviewed: 2026-11-13
---

# Backups and Wipes

The server writes a backup of the world to `backups/` each time the container starts and at 5 minutes past each hour, keeping at most 12. Backups older than 30 days are deleted, but the newest 3 are always kept, however old. Backups stop an hour after the last player leaves.

A running server saves the world even when nobody is on, so every restart adds a backup that differs from the last one only by idle time. When nobody has played since the previous backup, `hooks/idle-backups.sh` deletes that previous one and keeps the new one, so restarts and idle hours can't push out backups of real play.

Run every command from the repository root, and replace the placeholders:

| Placeholder | Replace with |
|---|---|
| `<WORLD_NAME>` | The `WORLD_NAME` value in `env/valheim.env` |
| `<YYYYMMDD-HHMMSS>` | The timestamp in the name of the backup or archive you are restoring |

## Restore an Hourly Backup

Each file in `backups/` is a zip of the world, named `worlds-<YYYYMMDD-HHMMSS>.zip`. The current world is moved to `wipe-archives/`, not deleted. The commands need `unzip` installed on the host.

```bash
./stop.sh
mkdir -p restore-tmp wipe-archives
unzip -q backups/worlds-<YYYYMMDD-HHMMSS>.zip -d restore-tmp
mv "data/worlds_local/<WORLD_NAME>" "wipe-archives/<WORLD_NAME>-before-restore-$(date +%Y%m%d-%H%M%S)"
mv "restore-tmp/config/worlds_local/<WORLD_NAME>" "data/worlds_local/<WORLD_NAME>"
rm -r restore-tmp
./restart.sh
```

## Wipe the World

`wipe-restart.sh` deletes every world, not only `<WORLD_NAME>`: everything in `data/worlds_local/`, in `data/worlds/` if present, and in `backups/`. It keeps the admin, ban and permitted lists. Before deleting, it asks you to type the world name, checks it can delete everything, and saves `data/` and `backups/` to `wipe-archives/<WORLD_NAME>-<YYYYMMDD-HHMMSS>.tar.gz`. It then starts a new world.

```bash
./wipe-restart.sh
```

## Restore a Wipe Archive

A wipe archive holds `data/` and `backups/` as they were before the wipe. Restoring it deletes everything in `data/`, including the current world and the player lists, without archiving them first. The old world's backups return to `backups/`, beside any made since the wipe.

```bash
./stop.sh
rm -rf data/*
tar -xzf "wipe-archives/<WORLD_NAME>-<YYYYMMDD-HHMMSS>.tar.gz"
./restart.sh
```

After any restore, check the log shows `Game server connected`.

## Change How Long Backups Are Kept

Set these in `env/valheim.env`, then run `./restart.sh`:

| Setting | Example value | Meaning |
|---|---|---|
| `BACKUPS_KEEP_DAYS` | `30` | Deletes backups older than this many days. |
| `BACKUPS_KEEP_MIN` | `3` | Never deletes the newest this many backups for age, so a server left off for months still has them. |
| `BACKUPS_MAX_COUNT` | `12` | Keeps at most this many backups, whatever their age. |

The image's own age limit, `BACKUPS_MAX_AGE`, deletes every backup older than it, even the last one. So the env example turns it off with `BACKUPS_MAX_AGE=36500` (100 years), and `hooks/idle-backups.sh` applies `BACKUPS_KEEP_DAYS` and `BACKUPS_KEEP_MIN` after each backup instead. `restart.sh` refuses to start while either is set and `BACKUPS_MAX_AGE` is lower than 36500, or when `BACKUPS_KEEP_MIN` is larger than `BACKUPS_MAX_COUNT`.

To use the image's age limit instead, remove `BACKUPS_KEEP_DAYS` and `BACKUPS_KEEP_MIN` and set `BACKUPS_MAX_AGE` to the number of days.
