# Inception — Peer-Evaluation Preparation & Cheatsheet

A structured walkthrough, live command cheatsheet, and conceptual oral exam guide for defending the **Inception** project (42 Curriculum).

---

## 📌 Fast Credentials & Info Quick Reference

| Item | Value / Location | Notes |
| :--- | :--- | :--- |
| **Domain** | `https://tbatis.42.fr` | Configured in `/etc/hosts` & `.env` |
| **HTTP Access** | `http://tbatis.42.fr` (Port 80) | **MUST FAIL / Connection Refused** |
| **Admin Username** | `tbatis42` | Strictly contains **NO** `admin` / `Admin` |
| **Admin Password** | `cat secrets/wp_admin_password.txt` | Read from Docker secret |
| **Admin Panel** | `https://tbatis.42.fr/wp-login.php` | Or `/wp-admin/` |
| **User Username** | `tbatis` | Role: Author / Regular User |
| **User Password** | `cat secrets/wp_user_password.txt` | Read from Docker secret |
| **DB Name / User** | `wordpress` / `wpuser` | Configured via `.env` & secrets |
| **DB Root Pass** | `cat secrets/db_root_password.txt` | Read from Docker secret |
| **Data Root (Host)**| `/home/tbatis/data` | Persistent storage path on host |

---

## 📋 Evaluation Step-by-Step Defense Walkthrough

Follow this exact flow as requested by the 42 evaluation sheet:

```
[ 1. Clone & Purge ] ➔ [ 2. Code & Doc Audit ] ➔ [ 3. Launch Stack ] ➔ [ 4. Browser & DB Tests ] ➔ [ 5. Persistence Test ] ➔ [ 6. Live Config Change ] ➔ [ 7. Oral Questions ]
```

---

### Step 1: Preliminary Purge & Clone Check

The evaluator will check that the git repository is clean and start from a fresh Docker environment.

```bash
# 1. Check Git history & status (Ensure no secrets are committed)
git status
git log -p -n 5

# 2. Complete Docker reset command from subject (Evaluator runs this):
docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
```

---

### Step 2: Static Code & Documentation Inspection

The evaluator will inspect your configuration and documentation files:

1. **`srcs/docker-compose.yml`**:
   - `networks:` is explicitly defined (custom bridge `inception`).
   - **NO** `network: host` or `network_mode: host`.
   - **NO** `links:`.
   - Only **NGINX** has `ports: ["443:443"]`.
   - MariaDB (`3306`) and WordPress (`9876` / `9000`) have **no host port bindings**.
   - `secrets:` and `volumes:` top-level keys declared properly.

2. **Dockerfiles & Scripts**:
   - Base images are penultimate stable: `FROM debian:12` (or `alpine:3.19`).
   - **NO** `:latest` tags.
   - **NO** ready-made DockerHub images (`FROM wordpress`, `FROM mariadb`, `FROM nginx`).
   - **NO** `tail -f`, `sleep infinity`, or `while true` dummy keepalive loops.
   - **NO** `--link` in `Makefile` or shell scripts.
   - MariaDB & WordPress Dockerfiles **do NOT contain or install NGINX**.

3. **Documentation Files at Repository Root**:
   - `README.md`: First line is italicized (`*This project has been created as part of the 42 curriculum by tbatis.*`). Contains Description, Instructions, Resources (explicit **AI usage disclosure**), and the 4 comparison sections.
   - `USER_DOC.md`: Administrator instructions (start/stop, browser access, credentials).
   - `DEV_DOC.md`: Technical guide (prerequisites, setup, Docker commands, persistence details).

---

### Step 3: Build & Launch Stack

```bash
# Automated 125-point compliance audit:
./verify_checklist.sh
# or
make test

# Build and start all services via Makefile:
make
```

Check running containers and image names:
```bash
docker compose ps
docker images
```

---

### Step 4: Live Demonstrations & Functionality Checks

#### 4.1 SSL/TLS & Port Check
* **HTTP Check**:
  ```bash
  curl -I http://tbatis.42.fr
  # Expected: Connection refused (exit code 7)
  ```
* **TLS Version Verification**:
  ```bash
  # TLSv1.2 & TLSv1.3 (MUST SUCCEED):
  openssl s_client -connect tbatis.42.fr:443 -tls1_2 < /dev/null
  openssl s_client -connect tbatis.42.fr:443 -tls1_3 < /dev/null

  # TLSv1.1 & TLSv1.0 (MUST FAIL / REJECT):
  openssl s_client -connect tbatis.42.fr:443 -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' < /dev/null
  ```

#### 4.2 Browser & WordPress UI
1. Open `https://tbatis.42.fr` in the browser.
2. Accept the self-signed certificate warning.
3. Verify the WordPress homepage loads directly (**NO setup wizard**).
4. **Regular User**: Log in as `tbatis` at `https://tbatis.42.fr/wp-login.php` and post a comment on a post.
5. **Administrator**: Log in as `tbatis42` $\rightarrow$ Go to **Posts/Pages** $\rightarrow$ Edit title/content $\rightarrow$ Click **Update** $\rightarrow$ Verify live change on the site.

#### 4.3 Database Inspection via CLI
```bash
# Log into MariaDB interactive shell:
make db root
# Or:
docker exec -it mariadb mariadb -u root -p"$(cat secrets/db_root_password.txt)"

# Run inside MariaDB prompt:
SHOW DATABASES;
USE wordpress;
SHOW TABLES;
SELECT ID, user_login, user_email FROM wp_users;
SELECT ID, post_title, post_status FROM wp_posts WHERE post_type = 'post';
```

---

### Step 5: Data Persistence Test

Prove that data survives when containers or the machine restarts:

```bash
# Option A: Stack Restart
make down
make up

# Option B: Full Virtual Machine Reboot (if requested by evaluator)
sudo reboot
```

After restarting:
1. Reload `https://tbatis.42.fr`.
2. Confirm no installation prompt appears.
3. Confirm the **edited post and comment from Step 4 are still intact**.
4. Confirm volume mount paths on host:
   ```bash
   docker volume ls
   docker volume inspect srcs_mariadb_vol srcs_wordpress_vol
   ls -la /home/tbatis/data
   ```

---

### Step 6: Live Configuration Modification Test

The evaluator will ask you on the spot to modify a service configuration (e.g. change an internal FastCGI or Database port):

#### Scenario: Change PHP-FPM Port (`9876` ➔ `9000`)
1. **Edit WordPress PHP-FPM config** (`srcs/requirements/wordpress/conf/www.conf`):
   ```ini
   listen = 9000
   ```
2. **Edit NGINX FastCGI upstream** (`srcs/requirements/nginx/conf/nginx.conf.template`):
   ```nginx
   fastcgi_pass wordpress:9000;
   ```
3. **Rebuild and restart the stack**:
   ```bash
   make re
   ```
4. **Demonstrate**: Reload `https://tbatis.42.fr` to prove the site operates smoothly with the new port.

---

## 🧠 Oral Defense Exam — Concepts & Answers

### 1. How Docker and Docker Compose work under the hood
* **Docker Engine**: A client-server application where the Docker CLI communicates via Unix socket/REST API with the `dockerd` daemon.
* **Linux Namespaces (Isolation)**:
  * `pid` (process isolation — container PID 1 is distinct from host PID).
  * `net` (isolated network interfaces, routing tables, port bindings).
  * `mnt` (independent filesystem mount points).
  * `ipc` (isolated inter-process communication).
  * `uts` (isolated hostnames and domain names).
* **Control Groups (cgroups)**: Control, meter, and limit hardware resource consumption (CPU, memory, disk I/O).
* **OverlayFS / Layered Filesystem**: Read-only image layers stacked together with a single thin read-write container layer on top.
* **Docker Compose**: A declarative orchestration tool that parses YAML definitions to create networks, volume mounts, secrets, and manage multi-container build/dependency lifecycles (`depends_on`).

### 2. Difference between `docker run` and `docker compose`
* `docker run`: Imperative, single-container tool. Requires manually specifying every network, volume, port, env, and secret flag on the command line every time.
* `docker compose`: Declarative multi-container management. Defines the entire infrastructure topology (relationships, networks, secrets, startup order) in version-controlled YAML.

### 3. Benefits of Docker Containers vs. Virtual Machines (VMs)
* **Virtual Machines**: Emulate physical hardware via a Hypervisor (Type 1 or Type 2). Every VM runs a complete, heavy guest operating system kernel with allocated RAM/disk overhead and slow boot times.
* **Docker Containers**: Share the **host Linux kernel** directly. There is no hypervisor overhead, memory footprint is minimal, processes run at near-native CPU speeds, and startup takes milliseconds.

### 4. Docker Network (`inception` Bridge)
* A user-defined bridge network providing process-level isolation.
* Containers attached to the same custom bridge have access to Docker's **embedded internal DNS server** (`127.0.0.11`).
* Services resolve each other by container name (e.g., NGINX reaches WordPress via `wordpress:<port>`, WordPress reaches MariaDB via `mariadb:3306`) without exposing ports to the host interface.

### 5. Docker Volumes vs. Bind Mounts
* **Bind Mounts**: Directly mount a host file/folder path into the container. Dependent on host directory structure and permissions.
* **Docker Volumes**: Managed by Docker under the engine data-root (or configured driver options). Decoupled from container lifecycles, isolated from host file alterations, and safely reused across rebuilds.

### 6. Secrets vs. Environment Variables (`.env`)
* **Environment Variables (`.env`)**: Useful for non-sensitive configuration (`DOMAIN_NAME`, `WP_TITLE`). However, environment variables leak via `docker inspect`, process listings (`ps e`), and image metadata.
* **Docker Secrets**: Sensitive credentials (passwords, TLS private keys) are mounted as read-only, in-memory files at `/run/secrets/` with strict permissions (`tmpfs`). They never get baked into image layers or committed to source control.

### 7. Rationale for Repository & Directory Structure
* `srcs/`: Encapsulates all Docker infrastructure definitions.
* `requirements/<service>/`: Isolates each service’s build context (`Dockerfile`, `conf/`, `tools/init.sh`) so each container image builds cleanly and independently.
* `secrets/`: Kept separate at the root and ignored by Git to ensure zero credential leakage.

---

## 🛠️ Handy Makefile Commands Cheatsheet

```bash
# Lifecycle
make                # Build and launch stack in background (make up)
make down           # Stop and remove containers and networks
make re             # Full rebuild & restart (make fclean + make all)
make logs           # View logs from all services
make ps             # List container statuses

# Verification
make test           # Run complete 125-check automated audit

# MariaDB Specific Helpers
make db root        # Open interactive MariaDB CLI as root
make db wpusers     # Query all registered WordPress users
make db posts       # Query latest WordPress posts

# NGINX Specific Helpers
make ng conftest    # Run nginx -t inside container
make ng pingweb     # Curl https://tbatis.42.fr
make ng tls1        # Test TLSv1.1 rejection
make ng tls2        # Test TLSv1.2 acceptance
make ng tls3        # Test TLSv1.3 acceptance
```