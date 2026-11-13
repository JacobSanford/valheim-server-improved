# valheim-server-improved

A ready-to-run Docker Compose setup for the [community-valheim-tools/valheim-server](https://github.com/community-valheim-tools/valheim-server-docker) image.

This repo adds several [quality of life improvements](https://jacobsanford.github.io/valheim-server-improved/latest/improvements/) on top of the community image's docker compose stack.

**[Read the Documentation](https://jacobsanford.github.io/valheim-server-improved/)**

## Quick Start

On a Linux host with [Docker](https://docs.docker.com/engine/install/) and the [compose plugin](https://docs.docker.com/compose/install/linux/):

```bash
cp env/valheim.env.example env/valheim.env
chmod 600 env/valheim.env
```

Set `SERVER_PASS` in `env/valheim.env` (and `PUID`/`PGID` if `id -u` or `id -g` is not 1000), then start the server:

```bash
./restart.sh
```

The server is ready when the log shows `Game server connected`. Forward UDP ports 2456–2457 to the host so players can join.

## Documentation

- [Quick Start](https://jacobsanford.github.io/valheim-server-improved/latest/quickstart/)
- [Players, Admins and Bans](https://jacobsanford.github.io/valheim-server-improved/latest/guides/players/)
- [Discord Notifications](https://jacobsanford.github.io/valheim-server-improved/latest/guides/notifications/)
- [Backups and Wipes](https://jacobsanford.github.io/valheim-server-improved/latest/guides/backups/)
- [Sleep When Idle](https://jacobsanford.github.io/valheim-server-improved/latest/guides/sleep/)
- [Troubleshooting](https://jacobsanford.github.io/valheim-server-improved/latest/troubleshooting/)
- [Reference](https://jacobsanford.github.io/valheim-server-improved/latest/reference/): variables, scripts, ports and files
- [Improvements over Upstream](https://jacobsanford.github.io/valheim-server-improved/latest/improvements/)

The same pages are in [`docs/`](docs/), built with [MkDocs](https://www.mkdocs.org/). To preview them locally: `pip install -r requirements.txt && mkdocs serve`.

## Tests

`tests/run.sh` runs every test: the scripts against a fake `docker`, the notifier against a stand-in webhook, the backup hook, the Compose config, and the hooks inside the Valheim image. `tests/run.sh --no-image` skips the image tests, which pull the 1.4 GB image. No test starts a server. GitHub Actions runs them, plus [ShellCheck](https://www.shellcheck.net/), on every push to `main` and every pull request.

## License

This project is dual-licensed under the [GNU Affero General Public License v3](https://www.gnu.org/licenses/agpl-3.0.html) (AGPLv3) and a commercial license. See [LICENSE](LICENSE) for the AGPLv3 terms. For use under different terms, for example in proprietary or commercial products, a commercial license is available: contact [jacob.josh.sanford@gmail.com](mailto:jacob.josh.sanford@gmail.com).
