# SFTP with Fail2Ban

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-bmmbmm01%2Fsftp2-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/r/bmmbmm01/sftp2)
[![GitHub](https://img.shields.io/badge/Source-bmartino1%2Fsftp2-181717?logo=github&logoColor=white)](https://github.com/bmartino1/sftp2)

SFTP-only file transfer using **Debian Forky/testing**, **OpenSSH**, **OpenSSL**, **Fail2Ban**, and **rsyslog**. Includes hardened SSH settings, persistent configuration, file-based security logs, and four Fail2Ban jails.

[Unraid support forum](https://forums.unraid.net/topic/189050-support-sftp-fail2ban)

> **Distribution note:** Debian Forky/testing is rolling, not stable/LTS. Package versions can change between builds; test updates before public-facing deployment.

# Docker Features
* Base: Debian Forky/testing Slim (rolling; not an LTS/stable distribution)
* Hardened default ssh config
* Fail2ban
* Persistent `/config` for user accounts, host keys, logs, Fail2Ban configuration and runtime diagnostics
* Four polling-based Fail2Ban jails, tested with actual firewall ban enforcement
* Optional timed APT updates and restart-required notices

## Environment variables

| Name | Default | Description |
|---|---|---|
| `TZ` | `America/Chicago` | Container timezone, e.g. `America/Chicago`. |
| `AUTO_UPDATE` | `suite` | Update policy: `none`, `suite`, `custom`. |
| `DEFAULT_ADMIN` | `true` | Set `false` to disable Unraid ADMIN_USER/ADMIN_PASS synchronization. |
| `ADMIN_USER` | `admin` | Admin account name synchronized into `users.conf` when the Unraid environment changes. |
| `ADMIN_PASS` | (unset) | Admin password synchronized into `users.conf` when supplied or changed; known default/placeholder passwords are rejected. |
| `SFTP_USERS` | (unset) | Legacy whitespace-separated inline account definitions, merged into `users.conf` when changed. Each account follows `user:pass[:e][:uid][:gid][:dirs]`. |
| `AUTO_UPDATE_INTERVAL_HOURS` | `0` (including when omitted) | Optional unattended APT upgrade interval in hours. `0` disables periodic updates; a positive integer enables them. OpenSSH package changes write `/config/debug/restart-required.txt` without automatically restarting SSHD. |
| `PASSWORD_AUTH` | (unset) | Force OpenSSH password auth policy: `yes`/`no`. |
| `ALLOW_USERS` | (unset) | Space-separated allowlist of SSH users (e.g. `admin alice`). |
| `F2B_CONFIG_MODE` | `symlink` | Populate `/etc/fail2ban` from `/config/fail2ban`: `symlink` \| `overlay` \| `noclobber` \| `replace`. |
| `DISABLE_IMKLOG` | `true` | Disable rsyslog `imklog` module (avoids `/proc/kmsg` noise in containers). |
| `MODE` | `start` | `start` = normal boot; `seed` = prepare configs then exit. |
| `TAIL_LOGS` | `true` | Mirror selected logs to `docker logs` (files are always written to `/config/log/…`). |
| `LOG_STREAMS` | `auth,fail2ban` | Comma-separated selection for `TAIL_LOGS`: any of `auth`, `fail2ban`, `whois`. |
| `DEBUG_TESTING` | `false` | When true, runs fail2ban dry-run and dumps effective sshd config to `/config/debug/`. |
| `MAIL_SERVER` | `false` | When true, **keeps** Fail2Ban mail actions; otherwise writes `zz-nomail.local` to disable mail. |
| `CLEAR_LOGS` | `false` | When true, archives previous run logs to `/config/log/archive/<name>.<UTC-timestamp>.log` and truncates current logs on boot. |


**User accounts:** `/config/sshd/users.conf` remains the persistent source of truth. The existing Unraid template's `ADMIN_USER` and `ADMIN_PASS` variables are supported again: on first boot or when these environment values **change**, the entrypoint synchronizes the named account into `users.conf`. An existing account retains its UID, GID and share directory settings; a new admin uses `1000:100:sftp` to match `/home/admin/sftp`. Other users are kept. A protected `/config/sshd/.unraid-admin-state` tracks the last applied environment settings, so editing `users.conf` manually and restarting does not get undone by an **unchanged** Unraid password. If the Unraid WebUI password is changed later, that new setting takes precedence and updates the managed account on the next container start. Use `DEFAULT_ADMIN=false` to disable this synchronization. The legacy `ADMIN_PASS=password` template default is deliberately rejected; set a unique password. `SFTP_USERS` is also supported for legacy inline users; changes are merged into `users.conf` on restart, while unchanged environment values do not overwrite later manual edits. Command-line account specifications remain unsupported. SFTP chroot homes must remain `root:root` (`0755`), while host-mounted shares can keep `nobody:users` (`65534:100`) with appropriate permissions.

**Notes**
- Persistent logs always in `/config/log/`.
- `AUTO_UPDATE=custom` runs `/config/updateapps.sh`.
- `MAIL_SERVER=true` allows custom mail actions when mail delivery is separately configured.
- By default, mail actions are disabled, but events continue to be logged.

# Updating and running with Docker Compose

The repository-root [docker-compose.yml](./docker-compose.yml) includes the existing configuration comments, both a local `build: .` and a Docker Hub `image:` tag, and the optional `AUTO_UPDATE_INTERVAL_HOURS` setting.

```bash
git clone https://github.com/bmartino1/sftp2.git
cd sftp2
# Edit docker-compose.yml host volume paths and create a valid users.conf.
# First boot creates a credential-free template unless explicit Unraid admin settings seed it.
docker compose up -d --build
```

Unless you provide valid Unraid ADMIN_USER/ADMIN_PASS settings on a fresh config, you must populate `/config/sshd/users.conf` with your own account entry (e.g. `admin:STRONG_UNIQUE_PASSWORD:1000:100:sftp`) before the SFTP daemon will start. On Unraid, the sample config location is `/mnt/user/appdata/sftp-fail2ban/sshd/users.conf`. Protect it with mode `0600`. After editing credentials, run `docker compose restart` to apply them.

To use the published Docker Hub image instead, comment out the Compose `build: .` line and run `docker compose pull && docker compose up -d`.

Startup `AUTO_UPDATE=suite` updates the configured Debian suite. **`AUTO_UPDATE_INTERVAL_HOURS` is optional: if it is not supplied, its default is `0`, so periodic checks are disabled.** Set `24` to opt into a check approximately every 24 hours. The timed process does not automatically restart SSHD; it records an OpenSSH package change under `/config/debug/restart-required.txt`. Schedule image rebuilds and controlled restarts to activate updated binaries and libraries. Debian testing package updates can introduce breaking changes.

The updater is stored at [scripts/update-inplace.sh](./scripts/update-inplace.sh) and installed into the image as `/usr/local/bin/update-inplace.sh`. `AUTO_UPDATE=custom` executes `/config/updateapps.sh` if present.

# Run container from Docker registry

Use a dedicated `/config` mount, create a valid `/config/sshd/users.conf`, and then start:

```bash
docker run -d --name sftp-fail2ban \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v /host/config/path:/config \
  -p 22:22 bmmbmm01/sftp2:latest
```

Inline user arguments are intentionally ignored; `users.conf` controls user creation and password synchronization.

# Volumes, Paths, and Ports
## Volumes
| Volume | Required | Function | Example |
|----------|----------|----------|----------|
| `config` | Yes | SSH and Fail2ban config files | `/your/config/path/:/config`|

## Paths/Files
Build-time diagnostics are under `/opt/debug/` (including `build-versions.txt`); persistent runtime diagnostics go to `/config/debug/`. Mount `/config` to retain accounts, keys, logs and Fail2Ban state across container replacements. The entrypoint seeds missing files and respects existing persistent configurations. `F2B_CONFIG_MODE` controls how packaged and persistent Fail2Ban settings are wired.

The entrypoint seeds missing configuration files, but SSHD will not start until `users.conf` contains a valid account. Existing persisted configuration files are not silently replaced.

### SSH
| Path | Required | Function |
|----------|----------|----------|
| `/config/sshd/keys` | Yes* | SSH host keys directory |
| `/config/sshd/sshd_config` | Yes* | SSH server configuration file |
| `/config/sshd/users.conf` | Yes | SSH users config file |
| `/config/userkeys` | No | SSH user keys directory |

### Fail2Ban
| Path | Required | Function |
|----------|----------|----------|
| `/config/fail2ban` | Yes | Fail2ban config and log directory |
| `/config/fail2ban/fail2ban.local` | No* | Fail2Ban config file |
| `/config/fail2ban/jail.local` | No* | Fail2Ban jail config file |
| `/config/fail2ban/fail2ban.sqlite3` | No* | Auto generated Fail2Ban SQLite DB for persistent bans between reboots |

*These files are automatically created if they are not present when the container is started

## Ports
The OpenSSH server runs by default on port 22. You can forward the container's port 22 to any host port if using the docker bridge network and docker NAT system. 
Changing only the Docker host port (for example, `2222:22`) does not require changing SSHD or Fail2Ban. If you change the internal SSHD port, update the corresponding Fail2Ban port.

| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `22` | TCP | Yes | SSH Port | `2222:22`|

# Customizing
## Sharing a directory from your computer
Mount the host path to a folder inside the user's home directory. Example shows mounting host upload directory to upload directory in user home folder. Alternatively, see the *bindmount dirs from another location* below for an example of mapping to a different directory and using scripts to mount dirs inside users home folders.
```bash
docker run -d --name sftp-fail2ban \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v /host/config/path:/config \
  -v /host/upload:/home/user/upload \
  -p 2222:22 bmmbmm01/sftp2:latest
```

Create the account in `/host/config/path/sshd/users.conf` (for example `user:YOUR_STRONG_PASSWORD:1001:100:upload`). User arguments passed to `docker run` are ignored.

## Add SSH users
Add users to /config/sshd/users.conf with the following pattern:
```
user:pass:UID:GID
```

Example:
```
user:pass:1001:100
user2:abc:1002:100
user3:xyz:1003:100
```

**Password updates:** Edit `users.conf` and restart the container; configured passwords are reapplied. The hardened default has `PubkeyAuthentication no`. Blank-password, key-only accounts require explicitly changing SSHD configuration.

## Encrypted password
Add `:e` behind password to mark it as encrypted. Use single quotes if using a terminal instead of users config file.
```
foo:$1$0G2g0GSt$ewU0t6GXG15.0hWoOX8X9.:e:1001
```

Prefer a modern SHA-512 crypt hash, generated with `openssl passwd -6`, and keep `users.conf` at mode `0600`.

## Optional SSH public-key authentication
The default hardened profile disables public-key authentication. If you explicitly enable it in SSHD, place public keys with the user's name in /config/userkeys directory. The keys must be matched with a user's names and a .pub extension. These are copied to `.ssh/authorized_keys` for the user during container start. 

Example:
```
user.pub
```

## Providing your own SSH host key (recommended)
This container will generate new SSH host keys at first run in /config/sshd/keys. You can place your own sshd keys in this folder, and they will be copied to /etc/ssh/ when the container runs.

Tip: you can generate your keys with these commands:

```
ssh-keygen -t ed25519 -f ssh_host_ed25519_key < /dev/null
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key < /dev/null
```

## Execute custom scripts or applications
Put your programs in `/config/sshd/scripts` and it will automatically run when the container starts.
See next subsection for an example.

### Bindmount dirs from another location
Prefer ordinary Docker bind mounts for sharing directories. An advanced custom script under `/config/sshd/scripts/` can use `mount --bind` with suitable privileges, but review this carefully.
```bash
#!/usr/bin/env bash
# Example only; requires CAP_SYS_ADMIN. Prefer Docker volumes instead.
mkdir -p /home/admin/tools
mount --bind /data/admin-tools /home/admin/tools
```

**NOTE:** Using `mount` requires `CAP_SYS_ADMIN` and compatible container security policy. [See this answer for more information](https://github.com/atmoz/sftp/issues/60#issuecomment-332909232).

**Note:** OpenSSH and OpenSSL are provided by Debian Forky/testing packages, which are updated through APT; package versions may lag upstream releases. Rebuild and verify the container regularly. No upstream tarball is compiled during container startup.

# Building the container yourself

```bash
git clone https://github.com/bmartino1/sftp2.git
cd sftp2
docker compose up -d --build
```

Review the root [docker-compose.yml](./docker-compose.yml), adjust host paths, and populate `users.conf` before starting. To build without Compose, run `docker build -t sftp2-local .`.

