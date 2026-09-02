# Inception — Developer Documentation

Technical reference and developer operations manual for the Inception multi-container infrastructure.

---

## 1. Quick Architecture & Service Map

```
[ Client / Browser ]  ──( HTTPS : 443 )───────────> [ NGINX Gateway ]
                                                     ├── (tbatis.42.fr) ────────► [ WordPress (PHP-FPM : 9876) ] ─┬─► [ MariaDB : 3306 ]
                                                     │                                                            └─► [ Redis : 6379 ]
                                                     ├── (tbatis.42.fr/static/) ─► [ Static Serv (HTTP : 3000) ]
                                                     ├── (kuma.tbatis.42.fr) ────► [ Uptime Kuma (HTTP/WS : 3001) ]
                                                     └── (adminer.tbatis.42.fr) ─► [ Adminer (HTTP : 8080) ] ──► [ MariaDB : 3306 ]

[ FTP Client / User ] ──( FTP : 21, 21100-21110 )─> [ vsftpd FTP Server ] ──────(wordpress_vol)──────► [ /var/www/html ]
```

| Service | Alias (`make`) | Container Name | Internal Port | Host Port | Mounted Volumes | Base Image |
| :--- | :---: | :--- | :---: | :---: | :--- | :--- |
| **NGINX** | `ng` | `nginx` | `443` | `443` | `wordpress_vol` (`:ro`) | `alpine:3.23` |
| **WordPress** | `wp` | `wordpress` | `9876` | None | `wordpress_vol` (`/var/www/html`) | `debian:12` |
| **MariaDB** | `db` | `mariadb` | `3306` | None | `mariadb_vol` (`/var/lib/mysql`) | `debian:12` |
| **Redis** | `rd` | `redis` | `6379` | None | None | `alpine:3.23` |
| **Static Serv** | `st` | `static_serv` | `3000` | None | None | `alpine:3.23` |
| **Uptime Kuma** | `km` | `uptime_kuma` | `3001` | None | `uptime_kuma_vol` (`/app/data`) | `alpine:3.23` |
| **Adminer** | `ad` | `adminer` | `8080` | None | None | `alpine:3.23` |
| **FTP Server** | `ft` | `ftp` | `21`, `21100-21110` | `21`, `21100-21110` | `wordpress_vol` (`/var/www/html`) | `alpine:3.23` |

> **Network Isolation**: All services reside in the private bridge network `inception`. NGINX binds to host port `443:443`, and the FTP bonus service publishes port `21` (control) and passive data ports `21100-21110`. Internal services (`3306`, `9876`, `6379`, `3000`, `3001`, `8080`) remain unreachable directly from host interfaces.

---

## 2. Environment Setup from Scratch

### 2.1 Prerequisites
- **Host OS**: Linux (x86_64 / Debian-based recommended)
- **Tools**: Docker Engine (`>= 24.x`), Docker Compose v2 (`docker compose`), `make`, `openssl`, `curl`
- **DNS Resolution**: Add the local domain and subdomain aliases to `/etc/hosts`:
  ```bash
  echo "127.0.0.1 tbatis.42.fr kuma.tbatis.42.fr adminer.tbatis.42.fr" | sudo tee -a /etc/hosts
  ```

---

### 2.2 Configuration Files (`srcs/.env`)
Stores **non-sensitive** runtime variables consumed by Docker Compose and container init scripts.

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `DOMAIN_NAME` | `tbatis.42.fr` | Host domain name for TLS SAN and WP routing |
| `MYSQL_DATABASE` | `wordpress` | Default database created on DB init |
| `MYSQL_USER` | `wpuser` | Database user account for WordPress |
| `WP_TITLE` | `Inception` | WordPress website title |
| `WP_ADMIN_USER` | `tbatis42` | WP administrator username (must not contain `admin`) |
| `WP_ADMIN_EMAIL`| `tbatis@student.42.fr` | WP administrator contact email |
| `WP_USER` | `tbatis` | Secondary WP author account username |
| `WP_USER_EMAIL` | `user@student.42.fr` | Secondary WP author account email |
| `KUMA_USER` | `tbatis` | Uptime Kuma dashboard administrator username |
| `FTP_USER` | `tbatis` | Authenticated FTP service username |

> **Rule**: Never store plain passwords or private keys inside `.env`.

---

### 2.3 Secrets Directory (`secrets/`)
Plaintext credential files mounted at runtime as in-memory files at `/run/secrets/` via Compose secrets.

| File Path | Mount Target | Consumed By | Description |
| :--- | :--- | :--- | :--- |
| `secrets/db_password.txt` | `/run/secrets/db_password` | `db`, `wp` | MariaDB password for `MYSQL_USER` |
| `secrets/db_root_password.txt` | `/run/secrets/db_root_password` | `db` | MariaDB administrative `root` password |
| `secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` | `wp` | WordPress admin login password |
| `secrets/wp_user_password.txt` | `/run/secrets/wp_user_password` | `wp` | WordPress author user login password |
| `secrets/kuma_password.txt` | `/run/secrets/kuma_password` | `uptime_kuma` | Uptime Kuma administrator login password |
| `secrets/ftp_password.txt` | `/run/secrets/ftp_password` | `ftp` | Authenticated FTP user password |
| `secrets/ca.crt` | `/run/secrets/ca_crt` | `nginx` | Local Root CA certificate (persistent) |
| `secrets/ca.key` | `/run/secrets/ca_key` | `nginx` | Local Root CA private key (persistent) |

#### Local Root CA Persistence Workflow
```
Host: secrets/ca.crt + ca.key
         │ (Mount into /run/secrets/)
         ▼
NGINX Init Script
   ├─► ca.crt exists?  ──(YES)──> Re-use existing Root CA to sign inception.crt
   └─► ca.crt missing? ──(NO)───> Generate new Root CA keypair -> Sign inception.crt
```
- **Why**: Reusing `secrets/ca.crt` prevents browser certificate invalidation when containers or images are rebuilt. Import `secrets/ca.crt` into the host trust store once.

---

## 3. Makefile & Build System

The project uses a unified root `Makefile` that delegates commands to `docker compose -f srcs/docker-compose.yml`.

### 3.1 Command Dispatch Pattern

```
                  ┌── make <target>           -> Stack-wide operation
make [target] ────┤
                  └── make <service> <target> -> Service-isolated operation
                                                 (service: ng | db | wp | rd | st | km | ad | ft)
```

- **Stack-wide syntax**: `make <command>`  
  Applies action across all stack containers.  
  *Examples*: `make up`, `make down`, `make logs`, `make ps`, `make fclean`
- **Service-targeted syntax**: `make <ng|db|wp|rd|st|km|ad|ft> <command>`
  Applies action to a single container.  
  *Examples*: `make wp logs`, `make km logs`, `make ft logs`, `make db restart`, `make ng bash`, `make db backup`

---

### 3.2 Core Lifecycle Commands

| Command | Scope | Action |
| :--- | :--- | :--- |
| `make` / `make all` / `make up` | Stack | Build missing images and start all containers in background (`-d --build`) |
| `make down` | Stack | Stop and remove containers and network (preserves volumes) |
| `make restart` | Stack | Restart all running containers |
| `make rebuild` | Stack | Stop -> Build -> Recreate and launch containers |
| `make ps` / `make status` | Stack | Show container runtime status, health, and exposed ports |
| `make logs` | Stack | Stream real-time logs from all services (`docker compose logs -f`) |
| `make log` | Stack | Print last 10 log entries across services |

---

### 3.3 Service-Specific & Debugging Commands

| Command | Target Service | Purpose |
| :--- | :--- | :--- |
| `make <ng\|db\|wp\|rd\|st\|km\|ad\|ft> sh` | Any | Open a portable interactive shell inside the target container |
| `make <db\|wp> bash` | Debian services | Open Bash inside a Debian-based container |
| `make <ng\|db\|wp\|rd\|st\|km\|ad\|ft> logs` | Any | Stream logs exclusively for that service |
| `make <ng\|db\|wp\|rd\|st\|km\|ad\|ft> restart`| Any | Restart only that service container |
| `make ng conftest` | `nginx` | Run `nginx -t` to validate configuration syntax |
| `make ng cert` | `nginx` | Inspect active TLS certificate (Subject, SAN, Expiry) |
| `make ng pingweb` | `nginx` | Perform an HTTPS `curl` test against `https://${DOMAIN_NAME}` |
| `make km pingweb` | `uptime_kuma` | Perform an HTTPS `curl` test against `https://kuma.${DOMAIN_NAME}` |
| `make km data` | `uptime_kuma` | List SQLite database and state files in `/app/data` |
| `make ad pingweb` | `adminer` | Test the Adminer HTTPS endpoint through NGINX |
| `make rd ping` | `redis` | Verify the cache server responds with `PONG` |
| `make rd info` | `redis` | Inspect Redis memory and cache statistics |
| `make rd keys` | `redis` | Scan WordPress object-cache keys |
| `make wp redis` | `wordpress` | Show the Redis Object Cache plugin connection status |
| `make ft config` | `ftp` | View active vsftpd server configuration |
| `make ft users` | `ftp` | Query configured FTP user account inside container |
| `make db wpusers` | `mariadb` | Query and dump the `wp_users` table directly via SQL |
| `make db posts` | `mariadb` | Query the 10 most recent posts from `wp_posts` |

---

## 4. Container & Volume Management

### 4.1 Teardown Levels

| Command | Containers & Networks | Images (`--rmi all`) | Volumes (`--volumes`) | Use Case |
| :--- | :---: | :---: | :---: | :--- |
| `make down` | ❌ Removed | Preserved | Preserved | Standard daily stop |
| `make clean` | ❌ Removed (+ orphans) | Preserved | Preserved | Clean dangling state |
| `make fclean` | ❌ Removed | ❌ Removed | Preserved | Full image rebuild |
| `make fcleanvolumesDANGEROUS` | ❌ Removed | ❌ Removed | ❌ **PURGED** | Complete factory reset |

> [!CAUTION]
> `make fcleanvolumesDANGEROUS` permanently destroys all database tables and WordPress uploads. Always run backups first.

---

## 5. Storage & Persistence Architecture

Data persistence is managed via Docker **named volumes** rather than bind mounts to ensure filesystem isolation and permission consistency across environments.

| Volume Name | Container Mount | Stored Data | Persistence Guarantee |
| :--- | :--- | :--- | :--- |
| `mariadb_vol` | `mariadb:/var/lib/mysql` | Raw InnoDB tablespaces, database schemas, user grants | Survives container rebuilds, host reboots, and `make fclean` |
| `wordpress_vol`| `wordpress:/var/www/html`<br>`nginx:/var/www/html:ro`<br>`ftp:/var/www/html` | WordPress core files, plugins, themes, and user uploads (`wp-content/uploads`) | Shared between PHP-FPM (write), NGINX (read-only), and vsftpd (read-write); persistent |
| `uptime_kuma_vol`| `uptime_kuma:/app/data` | SQLite database, monitor configurations, status metrics | Dedicated persistence for Uptime Kuma monitoring; survives rebuilds |

Redis intentionally has no volume: it is an LRU object cache, so losing its keys only causes WordPress to repopulate them from MariaDB. WordPress configures `WP_REDIS_HOST=redis`, port `6379`, database `0`, and the `${DOMAIN_NAME}:` key prefix during startup.

### Data Lifecycle Behavior
```
make down / make up           ──► Volumes untouched. Data immediately available.
make fclean                   ──► Images rebuilt. Data preserved in named volumes.
make fcleanvolumesDANGEROUS   ──► Volumes destroyed. Stack reinitializes from scratch on next `make up`.
```

---

## 6. Backup & Disaster Recovery

The project includes automated backup and restore targets storing artifacts in `../backups/`.

| Component | Backup Command | Restore Command | Artifact Location | Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| **MariaDB** | `make db backup` | `make db restorebackup` | `../backups/mariadb_backup.sql` | `mariadb-dump` via root secret |
| **WordPress** | `make wp backup` | `make wp restorebackup` | `../backups/wordpress_backup.tar.gz` | Ephemeral `debian:12` container tar archive |

### 6.1 Database Backup Flow (`make db backup`)
1. Executes `mariadb-dump` non-interactively inside the running `mariadb` container.
2. Authenticates automatically using `/run/secrets/db_root_password`.
3. Streams the full SQL dump directly to `../backups/mariadb_backup.sql`.
4. **Restore**: `make db restorebackup` pipes the SQL file back into the running database server.

### 6.2 Volume Backup Flow (`make wp backup`)
1. Spawns an ephemeral `debian:12` container mounting `srcs_wordpress_vol` (`/vol`) and `../backups` (`/backup`).
2. Archives and compresses `/vol` into `/backup/wordpress_backup.tar.gz`.
3. Immediately terminates and deletes the temporary container (`--rm`).
4. **Restore**: `make wp restorebackup` wipes `/vol/*` and unpacks the archive into the named volume.
