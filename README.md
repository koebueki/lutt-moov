# Lütt Mööv - Little Seagull

Demo site available at: https://luttmoov.kristoffn.net

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Geofox API credentials

Station and vehicle data come from the HVV Geofox API, which requires credentials from HBT GmbH. 
The app reads them from two environment variables:

| Variable          | Description          |
|-------------------|----------------------|
| `GEOFOX_USER`     | Geofox API user name |
| `GEOFOX_PASSWORD` | Geofox API password  |

Locally, put them in an untracked `mise.local.toml` (already in `.gitignore`);
mise loads it automatically:

```toml
[env]
GEOFOX_USER = "your-user"
GEOFOX_PASSWORD = "your-password"
```

## Deploying to Fly.io

The app runs as a single Fly machine with its SQLite database on a volume
(see `fly.toml`). Migrations run when the machine boots, and the stations
table is filled from the Geofox API on first boot.

One-time setup (pick your own app name and update `app` and `PHX_HOST` in
`fly.toml` to match):

```sh
fly apps create lutt-moov
fly volumes create luttmoov_data --region fra --size 1
fly secrets set -a lutt-moov SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  GEOFOX_USER="your-user" GEOFOX_PASSWORD="your-password"
```

Deploy (keep it to one machine, since SQLite cannot be shared between
machines):

```sh
fly deploy --ha=false
```
