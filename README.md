# Lütt Mööv

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
