# FTP Server (vsftpd) — Evaluation & Architecture Guide

A complete, evaluator-ready technical guide explaining how the Inception FTP bonus service works, why specific configuration choices were made, how the entrypoint works, and how to demonstrate it during peer evaluation.

---

## 1. High-Level Architecture & Concept

### 1.1 What is FTP and Why Does It Need Multiple Ports?
Unlike HTTP/HTTPS (which uses a single TCP connection on port 80/443), FTP is a **dual-channel protocol**:
1. **Control Channel (Port 21)**: The client connects to port `21` to send commands (`USER`, `PASS`, `LIST`, `RETR`, `STOR`, `DELE`) and receive status codes (`220`, `230`, `530`, etc.).
2. **Data Channel (Dynamic Ports)**: Directory listings and file transfers do **not** travel over port 21. FTP opens a separate TCP connection for every file transfer or directory listing.

```
       Host Interface (Port 21 + Ports 21100-21110)
                             │
       Control Channel (21)  │  Data Channel (21100-21110)
       ────────────────────► │ ◄──────────────────────────
                             ▼
                 ┌───────────────────────┐
                 │    vsftpd Container   │  (Alpine 3.23)
                 │  (PID 1 in foreground)│
                 └───────────┬───────────┘
                             │
                             ▼ (Mounts /var/www/html)
                 ┌───────────────────────┐
                 │  wordpress_vol (Data) │  ◄── Shared with WordPress PHP-FPM
                 └───────────────────────┘
```

### 1.2 Active vs. Passive Mode in Docker (Why Passive Mode?)
- **Active Mode (PORT)**: The client listens on a random port and tells the server to connect back to it. This **fails behind Docker NAT and modern firewalls** because Docker cannot route inbound connections initiated by the container to the client.
- **Passive Mode (PASV)**: The client asks the server for a data port. The server responds with an IP address and port (`227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)`), and the **client initiates the connection** to the server.
- **Why `pasv_min_port=21100` and `pasv_max_port=21110`?**: By pinning the passive ports to a fixed range (`21100–21110`), we can publish them explicitly in `docker-compose.yml` (`"21100-21110:21100-21110"`).
- **Why `pasv_address`?**: Inside the container, vsftpd only knows its private Docker IP (e.g. `172.19.0.5`). If it sends `172.19.0.5` to an outside client, the client cannot connect. `pasv_address=tbatis.42.fr` tells vsftpd to advertise the host's routable domain/IP.

---

## 2. Shared Volume & Permission Model (WordPress Compatibility)

The FTP container and WordPress container share the exact same Docker named volume: `wordpress_vol`.

```
[ WordPress (PHP-FPM) ] ───► /var/www/html ───┐
                                              ├──► [ wordpress_vol ]
[ vsftpd FTP Server   ] ───► /var/www/html ───┘
```

### The Permission Challenge & Solution
- **The Problem**: If the FTP user uploads a file with strict permissions (e.g. `chmod 600`, owned only by `tbatis:tbatis`), the WordPress PHP-FPM process (running as `www-data`) will get a `Permission Denied` error when reading or modifying the file.
- **The Solution**:
  1. **GID Alignment**: In `init.sh`, the Alpine `www-data` group is aligned to **GID 33** to match Debian/WordPress `www-data` (GID 33).
  2. **Group Membership**: The FTP user (`tbatis`) is added to the `www-data` group (`--groups www-data`).
  3. **Umask `002`**: Configured in `vsftpd.conf`. When the FTP user uploads a file, it is created with permission `664` (`-rw-rw-r--`) and directories with `775` (`drwxrwxr-x`). Both `tbatis` and `www-data` have read/write access.
  4. **Initial Ownership**: `init.sh` ensures existing files and directories have group write access (`chmod -R g+rwX`).

---

## 3. Configuration Breakdown (`vsftpd.conf`)

Here are the key directives in `/etc/vsftpd.conf` and why each exists:

| Directive | Value | Purpose / Evaluation Explanation |
| :--- | :--- | :--- |
| `listen=YES` | `YES` | Runs vsftpd as a standalone daemon listening on IPv4 TCP sockets. |
| `listen_ipv6=NO` | `NO` | Disables IPv6 listener to prevent port binding conflicts with IPv4. |
| `background=NO` | `NO` | **Crucial for Docker**: Keeps vsftpd in the foreground so Docker can monitor it as PID 1 and know when the container is alive. |
| `anonymous_enable=NO` | `NO` | **Security**: Completely disables unauthenticated anonymous logins. |
| `local_enable=YES` | `YES` | Allows local Linux user accounts created inside `/etc/passwd` to authenticate. |
| `write_enable=YES` | `YES` | Enables FTP write commands (`STOR`, `DELE`, `RMD`, `MKD`, `RNFR`, `RNTO`). |
| `local_umask=002` | `002` | New files get permissions `664` (rw-rw-r--) so the WordPress `www-data` group can modify them. |
| `chroot_local_user=YES` | `YES` | **Jail Security**: Locks authenticated users inside their home directory (`/var/www/html`). |
| `allow_writeable_chroot=YES`| `YES` | Allows the root of the chroot directory (`/var/www/html`) to be writable by the user. |
| `local_root=/var/www/html` | `/var/www/html` | Sets the landing directory for authenticated users to the WordPress volume. |
| `pasv_enable=YES` | `YES` | Enables passive mode for NAT and container compatibility. |
| `pasv_min_port` / `pasv_max_port` | `21100` / `21110` | Restricts data connections to published Docker port range. |
| `pasv_address` | `tbatis.42.fr` | Tells clients the external hostname/IP to connect to for data transfers. |
| `pasv_addr_resolve=YES` | `YES` | Tells vsftpd to resolve `pasv_address` if a hostname is provided instead of a raw IP. |
| `pam_service_name=vsftpd` | `vsftpd` | Uses PAM service definition `/etc/pam.d/vsftpd` for password verification against `/etc/shadow`. |
| `seccomp_sandbox=NO` | `NO` | **Alpine/musl requirement**: Disables vsftpd's built-in Linux seccomp filter which otherwise terminates child processes on musl syscalls. |
| `secure_chroot_dir` | `/var/run/vsftpd/empty` | Empty, unwriteable sandbox directory required by vsftpd for privileged operations. |

---

## 4. Entrypoint Script Deep Dive (`init.sh`)

The entrypoint script located at `srcs/requirements/bonus/ftp/tools/init.sh` executes once when the container starts:

```sh
#!/bin/sh
set -eu
```
- `set -eu`: Enforces strict error handling (`-e` exits on command failure, `-u` treats unset variables as errors).

### Step 1: Validate Environment & Secrets
```sh
: "${FTP_USER:?FTP_USER is required}"
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
password_file=/run/secrets/ftp_password
```
- Reads the username from `.env` and checks that Docker Compose mounted the password secret at `/run/secrets/ftp_password`.

### Step 2: Synchronize `www-data` GID
```sh
if getent group www-data >/dev/null; then
    groupmod -g 33 www-data 2>/dev/null || true
else
    addgroup -g 33 -S www-data
fi
```
- Ensures the `www-data` group has GID `33` inside Alpine, perfectly matching WordPress (Debian).

### Step 3: Create the System User
```sh
if ! getent passwd "$FTP_USER" >/dev/null; then
    useradd \
        --home-dir /var/www/html \
        --no-create-home \
        --shell /bin/sh \
        --groups www-data \
        "$FTP_USER"
fi
```
- Dynamically creates the system user without hardcoding it in the Dockerfile.

### Step 4: Apply Password Securely
```sh
printf '%s:%s\n' "$FTP_USER" "$(cat "$password_file")" | chpasswd
```
- Feeds the password directly to standard input of `chpasswd`. The password never appears in process arguments (`ps aux`) or shell history.

### Step 5: Adjust Permissions on Shared Volume
```sh
chgrp -R www-data /var/www/html
find /var/www/html -type d -exec chmod g+rwx {} +
find /var/www/html -type f -exec chmod g+rw {} +
```
- Ensures that both `tbatis` and WordPress PHP-FPM can create, read, edit, and delete files.

### Step 6: Template Replacement & Domain Resolution
```sh
pasv_addr="${FTP_PASV_ADDRESS:-$DOMAIN_NAME}"
if ! getent hosts "$pasv_addr" >/dev/null 2>&1; then
    echo "127.0.0.1 $pasv_addr" >> /etc/hosts || true
fi

sed "s/__PASV_ADDRESS__/$pasv_addr/g" \
    /etc/vsftpd.conf.template > /etc/vsftpd.conf
```
- Injects the domain name into `vsftpd.conf` and ensures it resolves locally so vsftpd does not fail startup checks.

### Step 7: Process Hand-off (`exec "$@"`)
```sh
exec "$@"
```
- Replaces the shell process with `vsftpd /etc/vsftpd.conf`. This guarantees **`vsftpd` is PID 1**, receives OS termination signals (`SIGTERM`, `SIGINT`) properly, and avoids background loops or `tail -f` hacks.

---

## 5. Step-by-Step Defense & Evaluation Checklist

Follow these exact steps during your peer evaluation to explain and demonstrate the FTP service:

### Step 1: Show Container State & Process (PID 1)
```bash
# Show container is running and healthy with published ports
make ft ps

# Verify PID 1 is vsftpd in foreground (no tail -f or loops)
make ft pid
# Output: PID 1 -> /usr/sbin/vsftpd /etc/vsftpd.conf
```

### Step 2: Show Configuration & User
```bash
# Show clean active vsftpd configuration
make ft config

# Show the dynamically created user account and group membership (GID 33)
make ft users
```

### Step 3: Demonstrate Live File Upload & WordPress Synchronization
Connect with any FTP client (or using Python / `lftp` / `curl`):

```bash
# 1. Upload a test file via FTP
python3 -c '
import ftplib
ftp = ftplib.FTP()
ftp.connect("tbatis.42.fr", 21)
with open("secrets/ftp_password.txt") as f:
    passwd = f.read().strip()
ftp.login("tbatis", passwd)
import io
ftp.storbinary("STOR eval_test.txt", io.BytesIO(b"Created via FTP during evaluation!\n"))
ftp.quit()
'

# 2. Verify the file immediately appears inside WordPress container with proper permissions
docker compose -f srcs/docker-compose.yml exec wordpress ls -la /var/www/html/eval_test.txt

# 3. Read content from WordPress container
docker compose -f srcs/docker-compose.yml exec wordpress cat /var/www/html/eval_test.txt

# 4. Clean up / delete file via FTP
python3 -c '
import ftplib
ftp = ftplib.FTP()
ftp.connect("tbatis.42.fr", 21)
with open("secrets/ftp_password.txt") as f:
    passwd = f.read().strip()
ftp.login("tbatis", passwd)
ftp.delete("eval_test.txt")
ftp.quit()
print("File successfully deleted via FTP!")
'
```

### Step 4: Demonstrate Security (Negative Tests)
```bash
# Test 1: Anonymous login is REJECTED
python3 -c '
import ftplib
try:
    ftp = ftplib.FTP()
    ftp.connect("tbatis.42.fr", 21)
    ftp.login("anonymous", "")
    print("FAIL: Anonymous logged in!")
except Exception as e:
    print("PASS: Anonymous rejected ->", e)
'

# Test 2: Wrong password is REJECTED
python3 -c '
import ftplib
try:
    ftp = ftplib.FTP()
    ftp.connect("tbatis.42.fr", 21)
    ftp.login("tbatis", "badpassword")
    print("FAIL: Bad password logged in!")
except Exception as e:
    print("PASS: Bad password rejected ->", e)
'
```

### Step 5: Run Automated Verification Suites
```bash
# Run strict bonus verification suite (61/61 checks passed)
bash inception_verify_bonus.sh

# Run full project verification suite (151/151 checks passed)
bash inception_verify.sh
```

---

## 6. Quick Reference: Makefile Commands for FTP

| Command | Action |
| :--- | :--- |
| `make ft up` | Build and launch FTP container in background |
| `make ft down` | Stop and remove FTP container |
| `make ft restart` | Restart vsftpd service |
| `make ft rebuild` | Rebuild image and recreate container |
| `make ft ps` / `make ft status` | Check running state and health |
| `make ft logs` / `make ft log` | Stream logs or display last 10 entries |
| `make ft config` | Display active `vsftpd.conf` without comments |
| `make ft users` | Query the `tbatis` user entry in container `/etc/passwd` |
| `make ft sh` | Open interactive shell inside the FTP container |

