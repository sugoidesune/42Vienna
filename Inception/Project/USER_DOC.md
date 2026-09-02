# Inception — Website Owner & Administrator Guide

A simple, non-technical operational manual for managing, inspecting, and recovering your WordPress website.

---

## 1. Quick Access & Credentials

| Resource | Address / Location | Notes |
| :--- | :--- | :--- |
| **Public Website** | [https://tbatis.42.fr](https://tbatis.42.fr) | Secure HTTPS only (port 443) |
| **Admin Dashboard** | [https://tbatis.42.fr/wp-admin](https://tbatis.42.fr/wp-admin) | Log in to manage posts and pages |
| **Static Showcase** | [https://tbatis.42.fr/static/](https://tbatis.42.fr/static/) | Non-PHP static bonus website |
| **Uptime Kuma**     | [https://kuma.tbatis.42.fr](https://kuma.tbatis.42.fr) | Real-time service monitoring dashboard (port 443) |
| **Adminer**         | [https://adminer.tbatis.42.fr](https://adminer.tbatis.42.fr) | Database UI; choose MySQL and use server `mariadb` |
| **FTP Server**     | `ftp://tbatis.42.fr:21` | Connect using FTP client (FileZilla/lftp) with `FTP_USER` |
| **Admin Password** | `secrets/wp_admin_password.txt` | View file on host to get current password |
| **Author Password**| `secrets/wp_user_password.txt` | View file on host for secondary author account |
| **Kuma Password**  | `secrets/kuma_password.txt` | Login `tbatis` password for Uptime Kuma dashboard |
| **FTP Password**   | `secrets/ftp_password.txt` | Password for FTP user account (`tbatis`) |

---

## 2. Daily Commands (Cheat Sheet)

Run these commands from the project root folder.

| Task | Command | What It Does |
| :--- | :--- | :--- |
| **Start Website** | `make up` | Starts all services in the background. |
| **Stop Website** | `make down` | Safely turns off the website without deleting your data. |
| **Restart Everything** | `make restart` | Quick reboot for all services. |
| **Check Health** | `make ps` | Shows if services are `running` and `healthy`. |
| **View Recent Logs** | `make log` | Shows the last 10 log messages across all services. |
| **Follow Live Logs** | `make logs` | Streams live events (press `Ctrl + C` to exit). |

---

## 3. ⚠️ Danger Zone & Volume Safety

Understand the difference between normal stops and destructive cleanup commands:

| Command | Is Your Data Safe? | What Actually Happens |
| :--- | :---: | :--- |
| `make down` |  **SAFE** | Stops containers. All posts, images, and settings remain intact. |
| `make clean` |  **SAFE** | Cleans up stopped containers. Data is untouched. |
| `make fclean` |  **SAFE** | Rebuilds application images. Database and media are preserved. |
| `make fcleanvolumesDANGEROUS` | ❌ **DATA DESTROYED** | **PERMANENTLY DELETES** all database records, posts, users, and uploaded files. |

> [!CAUTION]
> **NEVER run `make fcleanvolumesDANGEROUS`** unless you want to wipe the entire website back to a completely blank factory state. Always create a backup first.

---

## 4. Backup & Disaster Recovery

Your website consists of two parts: **Database** (text, settings, users) and **Files** (theme, plugins, uploaded media). Backups are stored in `../backups/`.

```
                    ┌── Database ──► make db backup ──► ../backups/mariadb_backup.sql
Complete Website ───┤
                    └── Files    ──► make wp backup ──► ../backups/wordpress_backup.tar.gz
```

### 4.1 How to Create a Full Backup
Run both commands before making major updates:
```bash
make db backup    # Saves database to ../backups/mariadb_backup.sql
make wp backup    # Saves website files to ../backups/wordpress_backup.tar.gz
```

### 4.2 How to Restore from a Backup
If something is accidentally deleted or corrupted:
```bash
make db restorebackup    # Restores all database tables from backup
make wp restorebackup    # Restores all files and uploads from backup
```

---

## 5. Troubleshooting & Fixing Broken Services

### Quick Diagnosis Flow
1. Check overall status: `make ps`
2. Look for any container marked `unhealthy` or `exited`.
3. Follow the service-specific guides below.

---

### 🌐 Service 1: Web Gateway (NGINX)
*Handles incoming web traffic and HTTPS security.*

* **Symptoms**: Website fails to load, browser connection timeout, SSL/TLS handshake error.
* **What to Check**:
  ```bash
  make ng logs        # Check recent web server error messages
  make ng conftest    # Verify NGINX configuration syntax
  make ng pingweb     # Test website connectivity from command line
  ```
* **How to Fix**:
  ```bash
  make ng restart     # Quick restart of NGINX
  make ng rebuild     # Rebuild and recreate NGINX container
  ```

---

### 📝 Service 2: WordPress Application
*Runs the WordPress engine and PHP code.*

* **Symptoms**: `502 Bad Gateway` error in browser, white screen of death, PHP execution errors.
* **What to Check**:
  ```bash
  make wp logs        # Check PHP-FPM processing and WordPress error logs
  make wp ps          # Verify WordPress container is active
  ```
* **How to Fix**:
  ```bash
  make wp restart     # Restart WordPress PHP-FPM service
  make wp rebuild     # Rebuild and recreate WordPress container
  ```

---

### 🗄️ Service 3: Database Server (MariaDB)
*Stores all articles, comments, accounts, and configuration.*

* **Symptoms**: `Error establishing a database connection` displayed on website.
* **What to Check**:
  ```bash
  make db logs        # Check database engine startup and error logs
  make db wpusers     # Test if database responds by listing users
  make db posts       # Test if database responds by listing recent posts
  ```
* **How to Fix**:
  ```bash
  make db restart     # Restart MariaDB database engine
  make db rebuild     # Rebuild and recreate MariaDB container
  ```



---

### ⚡ Service 4: Redis Object Cache
*Caches WordPress objects in memory to reduce repeated MariaDB work. It is internal and has no website or public domain.*

* **What to Check**:
  ```bash
  make rd ping        # Must print PONG
  make rd info        # Show cache and memory statistics
  make rd keys        # Show WordPress cache keys
  make wp redis       # Plugin connection status
  ```
* **How to Fix**:
  ```bash
  make rd restart
  make rd rebuild
  ```

---

### 📊 Service 5: Uptime Kuma (Monitoring Dashboard)
*Monitors infrastructure uptime and response times.*

* **Symptoms**: Dashboard unreachable at `https://kuma.tbatis.42.fr`, WebSocket disconnected banner.
* **What to Check**:
  ```bash
  make km logs        # Check Uptime Kuma Node.js application logs
  make km ps          # Verify Uptime Kuma container status
  make km pingweb     # Test HTTPS endpoint response
  ```
* **How to Fix**:
  ```bash
  make km restart     # Restart Uptime Kuma service
  make km rebuild     # Rebuild and recreate Uptime Kuma container
  ```

---

### 🛠️ Service 6: Adminer (Database Administration)
*Provides a browser interface for inspecting and managing MariaDB.*

* **Sign-in values**: Select `MySQL`, enter `mariadb` as the server, use the username from `MYSQL_USER` in `srcs/.env`, and use the password stored in `secrets/db_password.txt`.
* **What to Check**:
  ```bash
  make ad logs        # Check the Adminer PHP server logs
  make ad ps          # Verify the Adminer container is active
  make ad pingweb     # Test the HTTPS endpoint
  ```
* **How to Fix**:
  ```bash
  make ad restart     # Restart Adminer
  make ad rebuild     # Rebuild Adminer from its Dockerfile
  ```

---

### 📁 Service 7: FTP File Server (vsftpd)
*Provides FTP access to upload, download, and manage WordPress files and media.*

* **Connection details**: Host: `tbatis.42.fr` (or `localhost`), Port: `21`, Passive data ports: `21100-21110`, Username: `FTP_USER` (`tbatis`), Password: `secrets/ftp_password.txt`.
* **What to Check**:
  ```bash
  make ft status      # Check if vsftpd is active and running
  make ft logs        # Check FTP access and authentication logs
  make ft config      # Verify vsftpd active configuration
  make ft users       # Verify FTP user configuration
  ```
* **How to Fix**:
  ```bash
  make ft restart     # Restart FTP server
  make ft rebuild     # Rebuild FTP image and container
  ```

---

## 6. Single-Service Fix Cheat Sheet

To fix a single problematic service without disrupting the others:

| Problematic Service | Restart Command | Rebuild Command | View Logs Command |
| :--- | :--- | :--- | :--- |
| **Web Gateway** | `make ng restart` | `make ng rebuild` | `make ng logs` |
| **WordPress** | `make wp restart` | `make wp rebuild` | `make wp logs` |
| **Database** | `make db restart` | `make db rebuild` | `make db logs` |
| **Redis Cache** | `make rd restart` | `make rd rebuild` | `make rd logs` |
| **Static Site** | `make st restart` | `make st rebuild` | `make st logs` |
| **Uptime Kuma** | `make km restart` | `make km rebuild` | `make km logs` |
| **Adminer** | `make ad restart` | `make ad rebuild` | `make ad logs` |
| **FTP Server** | `make ft restart` | `make ft rebuild` | `make ft logs` |
