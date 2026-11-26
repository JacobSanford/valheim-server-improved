# valheim-server-improved

A ready-to-run Docker Compose setup for the [community-valheim-tools/valheim-server](https://github.com/community-valheim-tools/valheim-server-docker) image.

This repository adds several [quality of life improvements](https://jacobsanford.github.io/valheim-server-improved/latest/improvements/) on top of the community image's Docker Compose stack.

**[Read the Documentation](https://jacobsanford.github.io/valheim-server-improved/)**

## Quick Start

You need a Linux host with [Docker](https://docs.docker.com/engine/install/) and the [compose plugin](https://docs.docker.com/compose/install/linux/). Clone the repository and run every command from its root:

```bash
git clone https://github.com/JacobSanford/valheim-server-improved.git
cd valheim-server-improved
cp env/valheim.env.example env/valheim.env
chmod 600 env/valheim.env
```

In `env/valheim.env`, set `SERVER_PASS` to a password of at least 5 characters that does not appear in `SERVER_NAME`; `restart.sh` exits with an error otherwise. If `id -u` or `id -g` prints a number other than 1000, set `PUID` or `PGID` to that number, because the server writes `data/` and `backups/` as that user. Then start the server:

```bash
./restart.sh
```

`restart.sh` starts the server, then follows the logs. Press Ctrl+C to leave them; the server keeps running. The first start downloads about 4 GB of game server files and takes longer than later starts. The server is ready when the log shows `Game server connected`.

Forward UDP ports 2456–2457 to the host so players can join. With `CROSSPLAY=true`, also uncomment the `2458:2458/udp` line in `docker-compose.yml` and forward UDP 2458.

## Documentation

- [Quick Start](https://jacobsanford.github.io/valheim-server-improved/latest/quickstart/)
- [Players, Admins and Bans](https://jacobsanford.github.io/valheim-server-improved/latest/guides/players/)
- [Discord Notifications](https://jacobsanford.github.io/valheim-server-improved/latest/guides/notifications/)
- [Backups and Wipes](https://jacobsanford.github.io/valheim-server-improved/latest/guides/backups/)
- [Sleep When Idle](https://jacobsanford.github.io/valheim-server-improved/latest/guides/sleep/)
- [Troubleshooting](https://jacobsanford.github.io/valheim-server-improved/latest/troubleshooting/)
- [Reference](https://jacobsanford.github.io/valheim-server-improved/latest/reference/): variables, scripts, ports and files
- [Improvements over Upstream](https://jacobsanford.github.io/valheim-server-improved/latest/improvements/)

The same pages are in [`docs/`](docs/), built with [MkDocs](https://www.mkdocs.org/). To preview them locally, install MkDocs in a virtual environment and serve the site: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/mkdocs serve`.

## Tests

`tests/run.sh` runs every test: the scripts against a fake `docker`, the notifier against a stand-in webhook, the backup hook, the Compose config, and the hooks inside the Valheim image. `tests/run.sh --no-image` skips the image tests, which pull the 1.4 GB image. No test starts a server. When Docker or the compose plugin is missing, the tests that need it print `skipped` and count as passed. GitHub Actions runs them, plus [ShellCheck](https://www.shellcheck.net/), on every push to `main` and every pull request.

## License

This project is dual-licensed under the [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html) (AGPLv3) and a commercial license. See [LICENSE](LICENSE) for the AGPLv3 terms. To use the project under different terms, for example in proprietary or commercial products, contact [jacob.josh.sanford@gmail.com](mailto:jacob.josh.sanford@gmail.com) for a commercial license.
