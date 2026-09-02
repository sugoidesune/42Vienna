# Inception Project Checklist

This checklist aggregates every requirement, rule, constraint, and evaluation check specified in `subject.txt` and `eval.txt` (including bonus items from `bonus.txt` and `evalbonus.txt`).

---

## Table of Contents
1. [Instant Fail / Zero-Tolerance Criteria](#1-instant-fail--zero-tolerance-criteria)
2. [Repository & Directory Structure](#2-repository--directory-structure)
3. [Makefile Requirements](#3-makefile-requirements)
4. [Docker & Container Global Rules](#4-docker--container-global-rules)
5. [Docker Compose & Networking Configuration](#5-docker-compose--networking-configuration)
6. [Volumes & Persistence (/home/login/data)](#6-volumes--persistence-homelogindata)
7. [Service 1: NGINX (TLS Entrypoint)](#7-service-1-nginx-tls-entrypoint)
8. [Service 2: WordPress + php-fpm](#8-service-2-wordpress--php-fpm)
9. [Service 3: MariaDB](#9-service-3-mariadb)
10. [Documentation Requirements (README, USER_DOC, DEV_DOC)](#10-documentation-requirements-readme-user_doc-dev_doc)
11. [Live Defense & Oral Exam Questions](#11-live-defense--oral-exam-questions)
12. [Step-by-Step Evaluation Walkthrough Simulation](#12-step-by-step-evaluation-walkthrough-simulation)
13. [Bonus Part (Optional)](#13-bonus-part-optional)

---

## 1. Instant Fail / Zero-Tolerance Criteria

Reviewers will terminate the evaluation immediately with a grade of **0** (or **-42** for cheating) if any of the following are violated:

- [ ] **No Public Credentials:** No passwords, credentials, or API keys are committed to the Git repository outside of secret files created during evaluation.
- [ ] **No Ready-Made Images:** No pulled images from DockerHub or pre-made images (e.g. `FROM wordpress`, `FROM mariadb`, `FROM nginx`). Only base OS images are permitted.
- [ ] **Base OS Constraint:** Base images in all Dockerfiles MUST use the **penultimate stable version** of Debian or Alpine (e.g., `FROM alpine:3.19` or `FROM debian:bullseye` / `debian:bookworm` depending on current releases).
- [ ] **No `latest` Tag:** Prohibited in all Dockerfiles and `docker-compose.yml`.
- [ ] **No Network Shortcuts / Prohibited Directives:**
  - [ ] NO `network: host` in `docker-compose.yml`.
  - [ ] NO `links:` in `docker-compose.yml`.
  - [ ] NO `--link` in Makefile or any helper scripts.
  - [ ] Explicit `networks:` definition MUST be present in `docker-compose.yml`.
- [ ] **No Hacky Keepalive Loops / Background Tricks:**
  - [ ] NO `tail -f` (e.g., `tail -f /dev/null`, `tail -f /dev/random`).
  - [ ] NO `sleep infinity`.
  - [ ] NO `while true` infinite loops.
  - [ ] NO background jobs in entrypoint (e.g., `nginx & bash`, background daemons).
  - [ ] NO `bash` or `sh` used as a dummy foreground process / keepalive (they can only be used to execute an entrypoint script).
- [ ] **No Passwords in Dockerfiles:** Dockerfiles must not contain hardcoded plaintext credentials.
- [ ] **Mandatory Environment Variables & `.env`:** Must use a `.env` file for environment variables and Docker secrets for sensitive data.
- [ ] **Port 80 Forbidden:** HTTP port 80 must NOT be accessible. Port 443 (HTTPS) must be the ONLY entrypoint to the infrastructure.
- [ ] **No NGINX in Other Containers:** WordPress and MariaDB containers must NOT contain or install NGINX.
- [ ] **WordPress Admin Username:** Administrator username MUST NOT contain `admin`, `Admin`, `administrator`, or `Administrator` (e.g., `admin`, `admin-123`, `Admin-user` are strictly forbidden).
- [ ] **Missing / Empty Files:** If any Dockerfile, `Makefile`, `README.md`, `USER_DOC.md`, or `DEV_DOC.md` is missing or empty, evaluation ends immediately.

---

## 2. Repository & Directory Structure

The project directory structure must strictly adhere to the subject specification:

```
.
├── DEV_DOC.md
├── Makefile
├── README.md
├── USER_DOC.md
├── secrets/                  # Ignored by Git or created locally
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env                  # Ignored by Git or stored locally
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── .dockerignore
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── nginx/
        │   ├── .dockerignore
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        └── wordpress/
            ├── .dockerignore
            ├── Dockerfile
            ├── conf/
            └── tools/
```

### Checklist:
- [ ] `Makefile` is located at the root of the repository.
- [ ] `README.md` is located at the root of the repository.
- [ ] `USER_DOC.md` is located at the root of the repository.
- [ ] `DEV_DOC.md` is located at the root of the repository.
- [ ] All project configuration and source files are inside the `srcs/` folder at root.
- [ ] `docker-compose.yml` is inside `srcs/`.
- [ ] `.env` is inside `srcs/` (and `.gitignore` ignores sensitive `.env`/secrets).
- [ ] Service requirements are organized under `srcs/requirements/<service_name>/`.
- [ ] Each service folder contains its own `Dockerfile`, `.dockerignore`, `conf/`, and `tools/` (or helper scripts).
- [ ] Git repository is clean, without unneeded binaries, build artifacts, or committed credentials.

---

## 3. Makefile Requirements

- [ ] Located at the root of the repository.
- [ ] Running `make` sets up the entire application:
  - [ ] Creates necessary host data directories (`/home/login/data/mariadb`, `/home/login/data/wordpress`).
  - [ ] Builds Docker images via `docker compose -f srcs/docker-compose.yml build` (or `up --build`).
  - [ ] Launches containers in detached mode without crashing.
- [ ] Includes standard targets:
  - [ ] `all` (default build and launch)
  - [ ] `up` / `down` (start and stop stack)
  - [ ] `start` / `stop`
  - [ ] `re` (rebuild and restart)
  - [ ] `clean` / `fclean` (stop containers, remove images, networks, volumes, and local data directories if requested)
- [ ] Makefile does NOT use `--link`.

---

## 4. Docker & Container Global Rules

- [ ] Project runs inside a dedicated Virtual Machine.
- [ ] Each service runs in its own isolated container.
- [ ] Image names match their respective service names in `docker-compose.yml` (e.g. `mariadb`, `wordpress`, `nginx`).
- [ ] Base OS is explicitly the penultimate stable release of Alpine (e.g. `alpine:3.19`) or Debian (e.g. `debian:bullseye` / `debian:bookworm`).
- [ ] Dockerfiles start with explicit version tags: `FROM alpine:X.X.X` or `FROM debian:XXXXX`.
- [ ] No `latest` tags used anywhere.
- [ ] Each container implements a restart policy in case of crash (`restart: always` or `restart: on-failure`).
- [ ] PID 1 best practices:
  - [ ] Daemons run in the foreground (e.g., `nginx -g 'daemon off;'`, `php-fpm -F`, `mariadbd` / `mysqld_safe`).
  - [ ] Entrypoint scripts properly `exec` the primary foreground daemon as PID 1.

---

## 5. Docker Compose & Networking Configuration

- [ ] `docker-compose.yml` is located in `srcs/`.
- [ ] Defines a custom bridge network (`docker-network`).
- [ ] `networks:` definition is present and shared among containers.
- [ ] NO `network: host` anywhere.
- [ ] NO `links:` anywhere.
- [ ] NGINX container is the ONLY container with host port bindings (`ports: - "443:443"`).
- [ ] WordPress and MariaDB containers expose ports only within the internal Docker network (e.g., `expose: - "9000"` and `expose: - "3306"`), NOT mapped to the host (`ports:`).
- [ ] WordPress and MariaDB containers expose ports only within the internal Docker network (e.g., `expose:`), NOT mapped to the host (`ports:`).
- [ ] Domain name configured to redirect `login.42.fr` (e.g. via `/etc/hosts` pointing `127.0.0.1 login.42.fr`) where `login` is replaced by the student's username.

---

## 6. Volumes & Persistence (`/home/login/data`)

- [ ] Uses Docker **named volumes** (not simple bind mounts) configured with host persistence.
- [ ] Two distinct named volumes exist:
  1. Volume for WordPress database files (`mariadb`).
  2. Volume for WordPress website files (`wordpress`).
- [ ] Both named volumes store their data inside `/home/login/data` on the host machine:
  - [ ] `/home/login/data/mariadb` (or `/home/login/data/database`)
  - [ ] `/home/login/data/wordpress` (or `/home/login/data/website`)
  *(Replace `login` with actual intra username)*
- [ ] Volume inspection check:
  - [ ] Command `docker volume ls` lists the project volumes.
  - [ ] Command `docker volume inspect <volume_name>` displays `/home/login/data/` in the mountpoint / driver options.
- [ ] **Data Persistence Verification:**
  - [ ] Make changes in WordPress (create/edit a post, add a comment).
  - [ ] Reboot the Virtual Machine (or stop containers and restart).
  - [ ] Relaunch with `docker compose up -d` (or `make`).
  - [ ] Verify MariaDB and WordPress start without running re-installation, and previous edits/comments remain intact.

---

## 7. Service 1: NGINX (TLS Entrypoint)

- [ ] Dedicated `Dockerfile` inside `srcs/requirements/nginx/`.
- [ ] Built from penultimate stable Alpine or Debian.
- [ ] Acts as the sole public gateway on **Port 443 (HTTPS)**.
- [ ] Port 80 (HTTP) is not mapped and rejects connections.
- [ ] Configured with TLS protocol versions **TLSv1.2 and/or TLSv1.3 ONLY** (SSLv2, SSLv3, TLSv1.0, TLSv1.1 are explicitly disabled).
- [ ] Self-signed (or valid) SSL/TLS certificate installed and referenced in NGINX configuration.
- [ ] Correctly proxies `.php` requests via FastCGI to WordPress container (`wordpress:9000`).
- [ ] Correctly proxies `.php` requests via FastCGI to the WordPress container (e.g. `fastcgi_pass` to WordPress on its configured php-fpm port, typically 9000).
- [ ] Accessing `https://login.42.fr` displays the WordPress homepage without certificate errors blocking access (self-signed warning acceptable).
- [ ] Demonstrable TLS version check (e.g., via `openssl s_client -connect login.42.fr:443 -tls1_2` / `-tls1_3` and testing that `-tls1_1` fails).

---

## 8. Service 2: WordPress + php-fpm

- [ ] Dedicated `Dockerfile` inside `srcs/requirements/wordpress/`.
- [ ] Built from penultimate stable Alpine or Debian.
- [ ] Contains WordPress and `php-fpm` (installed and configured).
- [ ] Does NOT contain NGINX.
- [ ] `php-fpm` is configured to listen over the container network for FastCGI requests from NGINX (configurable port, typically default 9000).
- [ ] WordPress is pre-configured automatically upon first run (using `wp-cli` or initialization script):
  - [ ] Users visiting `https://login.42.fr` are NOT shown the WordPress setup/installation wizard.
- [ ] **User Accounts in WordPress:**
  - [ ] **Administrator Account:** Username does NOT contain `admin`, `Admin`, `administrator`, or `Administrator`.
  - [ ] **Second / Regular Account:** Can log in and post comments.
- [ ] **Functionality Verification:**
  - [ ] Can add comments as the regular user.
  - [ ] Can sign in to `https://login.42.fr/wp-admin` with the Administrator credentials.
  - [ ] Can edit a page or post from the admin dashboard and see changes reflected live on the public site.
- [ ] Connected to the WordPress named volume.

---

## 9. Service 3: MariaDB

- [ ] Dedicated `Dockerfile` inside `srcs/requirements/mariadb/`.
- [ ] Built from penultimate stable Alpine or Debian.
- [ ] Contains MariaDB / MySQL server only.
- [ ] Does NOT contain NGINX.
- [ ] Listens on port 3306 internally on the Docker network.
- [ ] Listens on its configured database port (typically default 3306) internally on the Docker network.
- [ ] Connected to the MariaDB named volume.
- [ ] Automatically initializes database schema, database user, and tables for WordPress on first start.
- [ ] Database credentials provided via environment variables / Docker secrets (no hardcoded passwords).
- [ ] **CLI Access Demonstration:**
  - [ ] Learner can execute a command to log into the MariaDB CLI (e.g., `docker exec -it mariadb mariadb -u <user> -p<password> <dbname>` or via root).
  - [ ] Running SQL queries (`SHOW DATABASES;`, `SHOW TABLES;`, `SELECT * FROM wp_users;`) shows non-empty tables and initialized records.

---

## 10. Documentation Requirements (README, USER_DOC, DEV_DOC)

All three documentation files must be located at the root of the repository in Markdown format (`.md`) and written in English:

### A. `README.md`
- [ ] **Exact First Line (Italicized):**
  `*This project has been created as part of the 42 curriculum by <login>.*`
- [ ] **Required Sections:**
  - [ ] **Description:** Project presentation, objectives, and stack overview.
  - [ ] **Instructions:** Compilation, installation, environment setup, and execution steps.
  - [ ] **Resources:** Reference list (Docker docs, tutorials) AND an explicit description of **how AI was used** (specifying which tasks and project parts).
  - [ ] **Project Description & Comparisons:**
    - [ ] Virtual Machines vs Docker.
    - [ ] Secrets vs Environment Variables.
    - [ ] Docker Network vs Host Network.
    - [ ] Docker Volumes vs Bind Mounts.

### B. `USER_DOC.md` (End User / Administrator Documentation)
- [ ] Explains what services are provided by the stack.
- [ ] Explains how to start and stop the project.
- [ ] Explains how to access the website (`https://login.42.fr`) and administration panel (`/wp-admin`).
- [ ] Explains how to locate and manage credentials.
- [ ] Explains how to verify that all services are healthy and running correctly.

### C. `DEV_DOC.md` (Developer Documentation)
- [ ] Explains prerequisites and setting up environment from scratch (files, secrets, `.env`).
- [ ] Explains building and launching the project using `Makefile` and `docker compose`.
- [ ] Lists relevant Docker commands to inspect, monitor, and manage containers and volumes.
- [ ] Details exact host data storage paths (`/home/login/data/`) and persistence mechanism.

---

## 11. Live Defense & Oral Exam Questions

The student must be ready to explain and demonstrate the following to the evaluator:

- [ ] **Conceptual Explanations:**
  - [ ] How Docker and Docker Compose work under the hood (namespaces, cgroups, layered filesystem).
  - [ ] Difference between running a Docker image with `docker run` vs `docker compose`.
  - [ ] Benefits of containerization (Docker) compared to Virtual Machines (hypervisors, kernel sharing, resource footprint).
  - [ ] Rationale behind the repository directory structure (`srcs`, `requirements`, `conf`, `tools`).
  - [ ] How `docker-network` isolates container traffic and provides DNS resolution between services.
- [ ] **Database Inspection:**
  - [ ] Demonstrate logging into MariaDB from the terminal.
  - [ ] Run SQL queries to show existing WordPress tables and users.
- [ ] **Security & TLS Demonstration:**
  - [ ] Prove that only port 443 is exposed.
  - [ ] Prove that port 80 fails to connect.
  - [ ] Demonstrate TLSv1.2 or TLSv1.3 enforcement (e.g. using `openssl s_client`).
- [ ] **Live Configuration Modification Test:**
  - [ ] Evaluator selects a service and asks the student to modify a configuration (e.g. change an internal/exposed port, or an environment setting).
  - [ ] Student applies the modification, rebuilds/restarts the stack, and proves that the service remains operational with the new configuration.

---

## 12. Step-by-Step Evaluation Walkthrough Simulation

Use this step-by-step checklist to simulate a 100% compliant peer evaluation:

1. **Clone to Empty Directory:**
   ```bash
   git clone <repo_url> inception_eval && cd inception_eval
   ```
2. **Secret / Git Check:**
   - [ ] Verify no secrets or sensitive files are committed in Git history (`git log -p`).
   - [ ] Check `.gitignore` contains `.env` and `secrets/`.
3. **Purge Existing Docker State:**
   ```bash
   docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
   ```
4. **Static Code & Config Checks:**
   - [ ] Check `srcs/docker-compose.yml` (has `networks:`, NO `network: host`, NO `links:`).
   - [ ] Check `Makefile` and scripts (NO `--link`).
   - [ ] Check all Dockerfiles (Penultimate Debian/Alpine, NO `tail -f`, NO infinite loops, NO plaintext passwords).
   - [ ] Verify `README.md`, `USER_DOC.md`, and `DEV_DOC.md` exist and meet all section requirements.
5. **Build and Launch via Makefile:**
   ```bash
   make
   ```
   - [ ] Stack builds and starts without errors.
6. **Container & Image Verification:**
   - [ ] `docker compose ps` shows `nginx`, `wordpress`, and `mariadb` running (`Up`).
   - [ ] `docker images` shows image names matching service names.
   - [ ] `docker network ls` shows custom bridge network.
7. **Volume Verification:**
   - [ ] `docker volume ls` lists 2 named volumes.
   - [ ] `docker volume inspect <volume_name>` shows `/home/login/data/`.
8. **Web & Connectivity Checks:**
   - [ ] `curl -I http://login.42.fr` (or port 80) -> Connection refused / fails.
   - [ ] `https://login.42.fr` opens the configured WordPress site (no setup wizard).
   - [ ] SSL certificate uses TLSv1.2 / TLSv1.3.
9. **WordPress Functionality Check:**
   - [ ] Log in as regular user -> post a comment.
   - [ ] Log in as admin at `https://login.42.fr/wp-admin` (username without `admin`/`Admin`) -> edit a page.
   - [ ] Verify updated page on the live website.
10. **MariaDB Check:**
    - [ ] Access DB container via CLI -> verify tables are populated.
11. **Persistence Test:**
    - [ ] Reboot VM / restart containers (`make down` followed by `make up`).
    - [ ] Verify changes (page edit, comments) persist.
12. **Live Configuration Change Test:**
    - [ ] Change a service configuration / port as requested by evaluator.
    - [ ] Rebuild and demonstrate the stack works with the change.

---

## 13. Bonus Part (Optional)

*Note: Evaluated ONLY if the mandatory part is 100% complete and completely bug-free.*

- [ ] Each bonus service has its own dedicated `Dockerfile` inside `srcs/requirements/bonus/<service_name>/`.
- [ ] Each bonus service runs in its own dedicated container.
- [ ] Extra ports are opened only as needed for specific bonus services.
- [ ] **Bonus Service Implementations:**
  - [ ] **Redis Cache:** Redis container installed and configured as an object cache for WordPress.
  - [ ] **FTP Server:** FTP server container pointing directly to the WordPress website files volume.
  - [ ] **Static Website:** Simple static site (showcase/resume) created in any language **EXCEPT PHP**.
  - [ ] **Adminer:** Adminer web interface configured to manage the MariaDB database.
  - [ ] **Custom Extra Service:** An additional service of choice (must be justified and explained during defense).

