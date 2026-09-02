*This project has been created as part of the 42 curriculum by tbatis.*

# Inception - System Administration & Multi-Container Infrastructure

## Description

**Inception** is a System Administration project in the 42 curriculum designed to introduce microservice architecture, containerization, and secure deployment principles using **Docker** and **Docker Compose**.

The goal of this project is to build a complete, production-ready, and resilient web infrastructure composed of isolated microservices running inside dedicated Docker containers on **Debian 12 (Bookworm)**. Every container image is built from scratch via custom Dockerfiles without using pre-built images from DockerHub (aside from the base OS).

### Stack Overview

```
                          Host (Port 443 + FTP 21 & 21100-21110)
                                    │
                 ┌──────────────────┴──────────────────┐
                 ▼ (HTTPS: 443)                        ▼ (FTP: 21, 21100-21110)
     ┌───────────────────────┐               ┌───────────────────────┐
     │     NGINX Gateway     │               │   vsftpd FTP Bonus    │
     │  (TLSv1.2 / TLSv1.3)  │               │     (Alpine 3.23)     │
     └───┬───────────────┬───┘               └───────────┬───────────┘
         │               │                               │
FastCGI  │               │ HTTP / WebSocket (3001)       │ (wordpress_vol)
(9876)   │               ▼                               │
         │   ┌───────────────────────┐                   │
         │   │   Uptime Kuma Bonus   │                   │
         │   │     (Node.js 24)      │                   │
         │   └───────────────────────┘                   │
         ▼                                               ▼
┌────────────────────────────────────────────────────────┐
│                   WordPress Service                    │
│                     (PHP-FPM 8.2)                      │
└────────────────────────────┬───────────────────────────┘
               ┌─────────────┴─────────────┐
    TCP (3306) │                TCP (6379) │
               ▼                           ▼
    ┌───────────────────┐       ┌───────────────────┐
    │ MariaDB Service   │       │ Redis Cache Bonus │
    │   (Port 3306)     │       │   (Alpine 3.23)   │
    └───────────────────┘       └───────────────────┘

       adminer.tbatis.42.fr ──► Adminer Bonus (PHP 8.4, port 8080)
```

The infrastructure comprises core and bonus services:
1. **NGINX**: The single entrypoint to the stack, exposing **Port 443 only** over **TLSv1.2 / TLSv1.3**. Handles HTTPS termination, serves static assets from WordPress volume (mounted read-only), routes `/static/` to the static showcase service, and securely reverse-proxies `kuma.tbatis.42.fr` to Uptime Kuma with WebSocket support.
2. **WordPress (PHP-FPM 8.2)**: Configured with PHP-FPM listening on TCP port `9876`. Contains WordPress core, the Redis Object Cache plugin, and two pre-configured user accounts (administrator and author).
3. **MariaDB**: Relational database dedicated solely to WordPress, initialized with strict database user privileges and listening on internal port `3306`.
4. **Static Serv (Bonus)**: Lightweight non-PHP web server built with compiled BusyBox httpd serving a personal showcase page at `https://tbatis.42.fr/static/`.
5. **Uptime Kuma (Bonus)**: Real-time service monitoring and status dashboard built from source (v2.5.3) on Alpine 3.23, accessible at `https://kuma.tbatis.42.fr`.
6. **Adminer (Bonus)**: Lightweight MariaDB administration interface built from the official pinned Adminer 6.0.1 PHP file on Alpine 3.23, accessible through NGINX at `https://adminer.tbatis.42.fr`. Use `mariadb` as the database server when signing in.
7. **Redis (Bonus)**: Volatile WordPress object cache built from `alpine:3.23`, reachable only inside the Compose network as `redis:6379`. It has no host port, NGINX route, public domain, credentials, or persistent volume because cached data is disposable.
8. **FTP Server (Bonus)**: vsftpd FTP server built on Alpine 3.23, exposing ports `21` (control) and `21100-21110` (passive mode data) directly to the host. Directly mounts the existing `wordpress_vol` named volume at `/var/www/html` to enable authenticated file uploads, downloads, and management with strict chroot isolation.

Persistent data is managed through dedicated named Docker volumes:
- `wordpress_vol`: Persists the WordPress installation and uploaded content (`/var/www/html`), shared between WordPress, NGINX (read-only), and FTP (read-write).
- `mariadb_vol`: Persists the MariaDB database tables and transaction logs (`/var/lib/mysql`).
- `uptime_kuma_vol`: Persists the Uptime Kuma SQLite database and monitor configurations (`/app/data`).

---

## Architectural & Theoretical Comparisons

### 1. Virtual Machines vs. Docker Containers
| Feature | Virtual Machines (VMs) | Docker Containers |
| :--- | :--- | :--- |
| **Architecture** | Hypervisor virtualizes full physical hardware; each VM runs its own guest OS kernel. | Containers share the host Linux kernel and isolate processes using namespaces and cgroups. |
| **Resource Usage** | Heavy; requires dedicated memory, disk space, and CPU allocation per VM. | Lightweight; uses only the resources needed by running processes. |
| **Startup Time** | Minutes (full OS boot process). | Milliseconds to seconds (process launch). |
| **Isolation** | Strong hardware-level isolation. | Process-level isolation within the shared kernel. |
| **Portability** | Bulky image files (GBs), dependent on hypervisor format. | Highly portable, layered images defined deterministically by Dockerfiles. |

### 2. Docker Secrets vs. Environment Variables
| Feature | Docker Secrets | Environment Variables (`.env`) |
| :--- | :--- | :--- |
| **Storage Location** | Mounted dynamically as in-memory files (`tmpfs`) at `/run/secrets/<secret_name>`. | Stored in process memory and environment tables. |
| **Visibility** | Inaccessible to outside inspection; not visible in `docker inspect`, `docker compose ps`, or `ps aux`. | Visible via `docker inspect <container>`, system logs, error dumps, and child process trees. |
| **Security Scope** | Ideal for high-risk confidential data: passwords, private keys, API tokens. | Ideal for non-confidential configuration: domain names, port numbers, database names, usernames. |
| **Git Safety** | Kept in a dedicated directory ignored by Git (`secrets/*`). | Kept in a local `.env` file ignored by Git (`srcs/.env`). |

### 3. Docker Network vs. Host Network
| Feature | Docker User-Defined Bridge Network (`inception`) | Host Network (`network: host`) |
| :--- | :--- | :--- |
| **Network Isolation** | Containers operate inside a private subnet isolated from external traffic and host interfaces. | Containers directly share the host's networking namespace without isolation. |
| **Service Discovery** | Built-in automatic DNS resolution by service name (e.g., `mariadb`, `wordpress`). | Requires manual port allocation on `localhost`; risk of port collisions with host services. |
| **Port Exposure** | Only explicitly published ports (`ports: ["443:443"]` on NGINX) are exposed to the host. Internal services (`3306`, `9876`) remain unreachable from the host. | All open ports are immediately exposed on the host's public interfaces. |

### 4. Docker Volumes vs. Bind Mounts
| Feature | Docker Named Volumes (`mariadb_vol`, `wordpress_vol`) | Host Bind Mounts |
| :--- | :--- | :--- |
| **Management** | Completely managed by Docker engine under Docker's storage root (`/var/lib/docker/volumes/`). | Directly mounts an arbitrary directory/file from the host filesystem. |
| **Host Coupling** | Decoupled from host directory structure; highly portable across operating systems. | Heavily dependent on exact host filesystem layout and permissions. |
| **Permissions & Safety** | Managed securely by container daemons without contaminating host user permissions. | Prone to permission conflicts between host UID/GID and container processes. |
| **Performance** | Optimized I/O performance on native Docker storage drivers. | Potential performance overhead across virtualized filesystems on non-Linux hosts. |

---

## Configuration & Environment Variables

### Required Environment Variables (`srcs/.env`)
Non-sensitive configuration keys are stored in `srcs/.env` (ignored by Git). The file must define:

| Variable | Description | Format / Expectation |
| :--- | :--- | :--- |
| `DOMAIN_NAME` | Domain name routed to the stack | `<login>.42.fr` |
| `MYSQL_DATABASE` | Name of the WordPress MariaDB database | `<database_name>` |
| `MYSQL_USER` | Non-root MariaDB database username | `<db_username>` |
| `WP_TITLE` | Title of the WordPress site | `<site_title>` |
| `WP_ADMIN_USER` | WordPress administrator username | `<admin_user>` *(cannot contain 'admin'/'Admin')* |
| `WP_ADMIN_EMAIL` | WordPress administrator email address | `<admin_email>` |
| `WP_USER` | Secondary WordPress standard user (Author role) | `<author_user>` |
| `WP_USER_EMAIL` | Secondary WordPress user email address | `<author_email>` |
| `KUMA_USER` | Uptime Kuma dashboard administrator username | `<kuma_user>` |
| `FTP_USER` | Authenticated FTP service username | `<login>` |

### Secrets in `secrets/`
All sensitive credentials, passwords, and private keys are stored in individual plain text files in the `secrets/` directory. These files are mounted into containers at `/run/secrets/` and ignored by Git.

| File | Secret Name | Target Container | Purpose |
| :--- | :--- | :--- | :--- |
| `secrets/db_password.txt` | `db_password` | `mariadb`, `wordpress` | Password for the standard database user (`wpuser`) |
| `secrets/db_root_password.txt` | `db_root_password` | `mariadb` | Password for the MariaDB `root` administrative account |
| `secrets/wp_admin_password.txt` | `wp_admin_password` | `wordpress` | Password for the WordPress administrator account |
| `secrets/wp_user_password.txt` | `wp_user_password` | `wordpress` | Password for the secondary WordPress user account |
| `secrets/kuma_password.txt` | `kuma_password` | `uptime_kuma` | Password for the Uptime Kuma administrator account (`tbatis`) |
| `secrets/ftp_password.txt` | `ftp_password` | `ftp` | Password for the authenticated FTP user account (`tbatis`) |
| `secrets/ca.crt` | `ca_crt` | `nginx` | **Local Root Certificate Authority certificate** (persisted for client trust) |
| `secrets/ca.key` | `ca_key` | `nginx` | **Local Root Certificate Authority private key** (used to sign TLS certificates) |

> **Note on Root CA Persistence (`ca.crt` and `ca.key`)**:
> The custom Local Root CA certificate and key are persisted inside `secrets/`. During container startup, NGINX uses this persisted CA to issue and sign the server certificate (`inception.crt`). Persisting `ca.crt` enables you to import the Root CA once into your browser or host OS trust store, maintaining verified HTTPS status without security warnings across VM reboots and container redeployments.

---

## Instructions & Makefile Usage

### Prerequisites
1. Linux environment (Debian/Ubuntu recommended) or VM.
2. Docker Engine & Docker Compose plugin (`docker compose`).
3. Make utility (`make`).
4. Host DNS entry in `/etc/hosts`:
   ```bash
   echo "127.0.0.1 tbatis.42.fr kuma.tbatis.42.fr adminer.tbatis.42.fr" | sudo tee -a /etc/hosts
   ```

### Makefile Syntax & Commands Overview
The project uses a modular Makefile structure:
- **Global Commands**: Executed across the entire stack using `make <target>`.
- **Service-Targeted Commands**: Executed against a specific service using the syntax `make <service> <target>`, where `<service>` is:
  - `ng` (NGINX)
  - `db` (MariaDB)
  - `wp` (WordPress)
  - `rd` (Redis)
  - `st` (Static Serv)
  - `km` (Uptime Kuma)
  - `ad` (Adminer)
  - `ft` (FTP Server)

#### General Stack Lifecycle
- `make` / `make all` / `make up`: Builds and launches all containers in detached mode.
- `make down`: Stops and removes all containers and the network.
- `make rebuild`: Gracefully stops, rebuilds, and restarts the containers.
- `make stop` / `make start` / `make restart`: Controls container runtime states.
- `make ps` / `make status`: Lists container statuses and health.
- `make logs` / `make log`: Streams full logs or displays the last 10 log entries.
- `make clean`: Stops containers and removes orphan containers.
- `make fclean`: Full clean; tears down containers, networks, and removes all built Docker images.
- `make fcleanvolumesDANGEROUS`: Complete reset; removes containers, images, and **deletes named volumes**.
- `make re`: Runs `fclean` followed by `all`.

#### Service-Specific Utilities
- `make <service> sh`: Opens a portable interactive shell in any container; `make <service> bash` is available in Debian-based containers.
- `make ng conftest`: Runs NGINX configuration syntax verification (`nginx -t`).
- `make ng cert`: Displays active TLS certificate subject and expiration dates.
- `make ng pingweb`: Sends a test HTTPS request to `https://tbatis.42.fr`.
- `make ng tls2` / `make ng tls3`: Verifies TLSv1.2 and TLSv1.3 handshakes using OpenSSL.
- `make db root` / `make db wpuser`: Opens an interactive MariaDB client session.
- `make db posts`: Directly queries and lists recent WordPress posts from the database.
- `make db wpusers`: Directly queries and displays registered WordPress users.
- `make rd ping`: Verifies Redis replies with `PONG`.
- `make rd info`: Shows Redis memory and cache statistics.
- `make rd keys`: Lists cached WordPress keys (prefixed with `${DOMAIN_NAME}:`).
- `make wp redis`: Shows the WordPress plugin, drop-in, and Redis connection status.
- `make ft config`: Displays the active vsftpd server configuration.
- `make ft users`: Queries the configured FTP user account inside the container.

### Backup & Restore Feature
The stack includes dedicated backup and restore targets for both the database and website volume data, saving archives into `../backups/`:

- **MariaDB Database Backup**:
  - `make db backup`: Dumps all databases using `mariadb-dump` with the secure root secret into `../backups/mariadb_backup.sql`.
  - `make db restorebackup`: Restores all databases from `../backups/mariadb_backup.sql`.
- **WordPress Volume Backup**:
  - `make wp backup`: Spawns a temporary Debian container to archive the named volume `srcs_wordpress_vol` into `../backups/wordpress_backup.tar.gz`.
  - `make wp restorebackup`: Extracts the archive back into `srcs_wordpress_vol`.

---

## Resources & AI Usage

### References
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Specification](https://docs.docker.com/compose/)
- [NGINX HTTP SSL Module Documentation](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [Adminer Documentation](https://www.adminer.org/)
- [WordPress CLI Command Reference](https://developer.wordpress.org/cli/commands/)
- [Redis Documentation](https://redis.io/docs/latest/)
- [Redis Object Cache plugin documentation](https://wordpress.org/plugins/redis-cache/)
- [vsftpd Documentation & Man Page](https://security.appspot.com/vsftpd/vsftpd_conf.html)
- [OpenSSL PKI & TLS Best Practices](https://www.openssl.org/docs/)
- [The Smallest Docker Image to Serve Static Websites - Lipanski](https://lipanski.com/posts/smallest-docker-image-static-website)
- [How to Run Uptime Kuma in Docker for Status Monitoring - OneUptime](https://oneuptime.com/blog/post/2026-02-08-how-to-run-uptime-kuma-in-docker-for-status-monitoring/view)

### AI Usage Disclosure
In compliance with 42 curriculum requirements, artificial intelligence was utilized during the development of this project for:
1. **Architectural & Scripting Design**: Assisting with the structure of entrypoint initialization scripts (`init.sh`) to guarantee proper PID 1 signal forwarding with `exec "$@"` without relying on background loops or daemon hacks.
2. **Makefile Dispatcher Logic**: Structuring the modular Makefile command router (`Makefile.cm`, `Makefile.ng`, `Makefile.db`, `Makefile.wp`, `Makefile.ft`) and volume backup recipes.
3. **Documentation Generation**: Drafting and formatting technical documentation (`README.md`, `USER_DOC.md`, `DEV_DOC.md`).
4. **Bonus Service Integration**: Assisting with the Alpine 3.23 Adminer, Redis, and vsftpd FTP server containers with passive port ranges and `wordpress_vol` integration, WordPress object-cache integration, NGINX reverse proxy, TLS SAN, and validation checks.
