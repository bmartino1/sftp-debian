[preview]: https://raw.githubusercontent.com/MarkusMcNugen/docker-templates/master/sftp/SFTP.png "SFTP"

![alt text][preview]

# SFTP with Fail2ban
Easy to use SFTP ([SSH File Transfer Protocol](https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol)) server with [OpenSSH](https://en.wikipedia.org/wiki/OpenSSH) and [Fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page) installed for extra hardening against brute force attacks. A Updated debian-slim runnign fail2ban and openssh server with my prepackaged whois log and jails.

---

**More Info:**  
Unraid Forum: [https://forums.unraid.net/topic/189050-support-sftp-fail2ban](https://forums.unraid.net/topic/189050-support-sftp-fail2ban)

Docker Hub: [https://hub.docker.com/r/bmmbmm01/sftp2](https://hub.docker.com/r/bmmbmm01/sftp2)

# Docker Features
* Base: Debian Forky/testing Slim (rolling; not an LTS/stable distribution)
* Hardened default ssh config
* Fail2ban
* Optional config volume can be mounted for custom ssh and fail2ban configuration and easily viewing fail2ban log

## Environment variables

| Name | Default | Description |
|---|---|---|
| `TZ` | (unset) | Container timezone, e.g. `America/Chicago`. |
| `AUTO_UPDATE` | `suite` | Update policy: `none`, `suite`, `custom`. |
| `AUTO_UPDATE_INTERVAL_HOURS` | `0` | Optional unattended APT upgrade interval in hours (`0` disables); writes a restart-required notice on OpenSSH package changes without restarting SSHD. |
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


**User accounts:** `/config/sshd/users.conf` is the sole account source. The legacy `DEFAULT_ADMIN`, `ADMIN_USER`, `ADMIN_PASS` and `SFTP_USERS` variables and command-line user specifications are no longer consumed; do not put credentials in your Compose environment. Edit `users.conf` and restart to reapply passwords/hashes. Fresh installations have no built-in username/password and refuse to expose SSHD until at least one user is configured. An SFTP chroot remains root:root (0755); bind-mounted Unraid data can retain nobody:users (65534:100), with access controlled by its host permissions/ACLs.\n\n**Notes**
- Persistent logs always in `/config/log/`.
- `AUTO_UPDATE=custom` runs `/config/updateapps.sh`.
- `MAIL_SERVER=true` lets you use your own mail actions. (advance side loading and settign with custom and udpate apps.)
- Docker default will stop mail action and force login to log folder.

# Updating and running with Docker Compose

The repository-root [docker-compose.yml](./docker-compose.yml) includes the existing configuration comments, both a local `build: .` and a Docker Hub `image:` tag, and the optional `AUTO_UPDATE_INTERVAL_HOURS` setting.

```bash
git clone https://github.com/bmartino1/sftp2.git
cd sftp2
# Edit docker-compose.yml host volume paths and create a valid users.conf.
# First boot creates a credential-free template if no users.conf exists.
docker compose up -d --build
```

Because no default credentials are supplied, you must populate `/config/sshd/users.conf` with your own account entry (e.g. `admin:STRONG_UNIQUE_PASSWORD:1000:100:sftp`) before the SFTP daemon will start. On Unraid, the sample config location is `/mnt/user/appdata/sftp-fail2ban/sshd/users.conf`. Protect it with mode `0600`. After editing credentials, run `docker compose restart` to apply them.

To use the published Docker Hub image instead, comment out the Compose `build: .` line and run `docker compose pull && docker compose up -d`.

Startup `AUTO_UPDATE=suite` updates the configured Debian suite. `AUTO_UPDATE_INTERVAL_HOURS=0` disables timed checks; choose `24` for a daily unattended APT check. The timed process does not automatically restart SSHD; it records an OpenSSH package change under `/config/debug/restart-required.txt`. Schedule image rebuilds and controlled restarts to activate updated binaries and libraries. Debian testing package updates can introduce breaking changes.

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
There is a /debug folder that has the at build what was runnign. The entrypoint script will remake the /config a Volume is not need to run this docker.
The Entypoint Script has had some updates and the Docker Log will be able to explain and show issues. 
Fail2ban and sshd have ben updated and scripts/configs updated. 
If you want to make edits to sshd, fail2ban, and jails configurations as long as they exist in /config they will be deployed and used. see docker varable opton on how to handle fail2ban and adatioanl jails outsdie of my prefereed defaults. A major edit was done to use the ubuntu package maintainers files and our edits to run are now using the.local file the preferred way...

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
Otherwise, you will need to edit the port in sshd_config and jails.local

| Port | Proto | Required | Function | Example |
|----------|----------|----------|----------|----------|
| `22` | TCP | Yes | SSH Port | `2222:22`|

# Customizing
## Sharing a directory from your computer
Mount the host path to a folder inside the user's home directory. Example shows mounting host upload directory to upload directory in user home folder. Alternatively, see the *bindmount dirs from another location* below for an example of mapping to a different directory and using scripts to mount dirs inside users home folders.
```
docker run \
    --cap-add=NET_ADMIN --cap-add=NET_RAW
    -v /host/config/path:/config \
    -v /host/upload:/home/user/upload \
    -p 22:22 -d bmmbmm01/sftp2:latest \
    user:pass:1001
```

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

Note: This hardened image defaults to `PubkeyAuthentication no`. A blank password is not a working key-only login unless you explicitly reconfigure SSHD accordingly.

Example:
```
user:pass:1001:100
user2:abc:1002:100
user3::1003:100
```

## Encrypted password
Add `:e` behind password to mark it as encrypted. Use single quotes if using a terminal instead of users config file.
```
foo:$1$0G2g0GSt$ewU0t6GXG15.0hWoOX8X9.:e:1001
```

Tip: you can use [atmoz/makepasswd](https://hub.docker.com/r/atmoz/makepasswd/) to generate encrypted passwords:  
`echo -n "your-password" | docker run -i --rm atmoz/makepasswd --crypt-md5 --clearfrom=-`

## Logging in with SSH keys
Place public keys with the user's name in /config/userkeys directory. The keys must be matched with a user's names and a .pub extension. These are copied to `.ssh/authorized_keys` for the user during container start. 

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
If you are using `--volumes-from` or just want to make a custom directory available in the user's home directory, you can add a script to `/config/sshd/scripts/` that bindmounts after container starts.
```
#!/bin/bash
# File mounted as: /config/sshd/scripts/bindmount.sh
# Just an example (make your own)

function bindmount() {
    if [ -d "$1" ]; then
        mkdir -p "$2"
    fi
    mount --bind $3 "$1" "$2"
}

# Remember permissions, you may have to fix them:
# chown -R :users /data/common

bindmount /data/admin-tools /home/admin/tools
bindmount /data/common /home/dave/common
bindmount /data/common /home/peter/common
bindmount /data/docs /home/peter/docs --read-only
```

**NOTE:** Using `mount` requires that your container runs with the `CAP_SYS_ADMIN` capability turned on. [See this answer for more information](https://github.com/atmoz/sftp/issues/60#issuecomment-332909232).

**Note:** OpenSSH and OpenSSL are provided by Debian Forky/testing packages, which are updated through APT; package versions may lag upstream releases. Rebuild and verify the container regularly. No upstream tarball is compiled during container startup.

# Building the container yourself

```bash
git clone https://github.com/bmartino1/sftp2.git
cd sftp2
docker compose up -d --build
```

Review the root [docker-compose.yml](./docker-compose.yml), adjust host paths, and populate `users.conf` before starting. To build without Compose, run `docker build -t sftp2-local .`.

