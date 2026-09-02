#!/usr/bin/env bash
# ==============================================================================
# Inception Project Checklist Verification Script
# Evaluates and verifies all programmatic requirements from checklist.md,
# subject.txt, and eval.txt (Static, Docker, Network, TLS, WP, MariaDB).
#
# NOTE: This script is non-destructive and will NOT delete volumes or reboot.
# ==============================================================================

set -uo pipefail

# ------------------------------------------------------------------------------
# Color Formatting & Counters
# ------------------------------------------------------------------------------
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"

PASSED_COUNT=0
FAILED_COUNT=0
WARNING_COUNT=0
TOTAL_COUNT=0

CURRENT_SECTION=""

print_header() {
    echo -e "\n${BOLD}${CYAN}==============================================================================${RESET}"
    echo -e "${BOLD}${WHITE}  $1${RESET}"
    echo -e "${BOLD}${CYAN}==============================================================================${RESET}"
    CURRENT_SECTION="$1"
}

print_subsection() {
    echo -e "\n${BOLD}${BLUE}--- $1 ---${RESET}"
}

report_pass() {
    local test_name="$1"
    local detail="${2:-}"
    ((PASSED_COUNT++))
    ((TOTAL_COUNT++))
    if [ -n "$detail" ]; then
        echo -e "  [ ${GREEN}PASS${RESET} ] ${test_name} (${detail})"
    else
        echo -e "  [ ${GREEN}PASS${RESET} ] ${test_name}"
    fi
}

report_fail() {
    local test_name="$1"
    local reason="${2:-}"
    ((FAILED_COUNT++))
    ((TOTAL_COUNT++))
    echo -e "  [ ${RED}FAIL${RESET} ] ${BOLD}${test_name}${RESET}"
    if [ -n "$reason" ]; then
        echo -e "           ${RED}↳ Reason: ${reason}${RESET}"
    fi
}

report_warn() {
    local test_name="$1"
    local reason="${2:-}"
    ((WARNING_COUNT++))
    echo -e "  [ ${YELLOW}WARN${RESET} ] ${test_name}"
    if [ -n "$reason" ]; then
        echo -e "           ${YELLOW}↳ Note: ${reason}${RESET}"
    fi
}

report_info() {
    echo -e "  [ ${CYAN}INFO${RESET} ] $1"
}

# ------------------------------------------------------------------------------
# Locate Project Root & Setup Context
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$SCRIPT_DIR}"

if [ ! -d "$REPO_ROOT/srcs" ]; then
    # Try current working directory
    if [ -d "./srcs" ]; then
        REPO_ROOT="$(pwd)"
    fi
fi

if [ ! -d "$REPO_ROOT/srcs" ]; then
    echo -e "${RED}Error: Cannot find 'srcs/' directory in '$REPO_ROOT'.${RESET}"
    echo "Usage: $0 [path_to_inception_repo]"
    exit 1
fi

cd "$REPO_ROOT" || exit 1

# Extract domain and user from .env if present
ENV_FILE="$REPO_ROOT/srcs/.env"
DOMAIN_NAME="localhost"
WP_ADMIN_USER=""
WP_USER=""

if [ -f "$ENV_FILE" ]; then
    DOMAIN_NAME=$(grep -E '^[[:space:]]*DOMAIN_NAME=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' | xargs || echo "localhost")
    WP_ADMIN_USER=$(grep -E '^[[:space:]]*WP_ADMIN_USER=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' | xargs || echo "")
    WP_USER=$(grep -E '^[[:space:]]*WP_USER=' "$ENV_FILE" | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' | xargs || echo "")
fi

USER_LOGIN=$(whoami)
if [ -n "$DOMAIN_NAME" ] && [[ "$DOMAIN_NAME" =~ ^([a-zA-Z0-9_-]+)\.42\.fr$ ]]; then
    INTRA_LOGIN="${BASH_REMATCH[1]}"
else
    INTRA_LOGIN="$USER_LOGIN"
fi

echo -e "${BOLD}${WHITE}==============================================================================${RESET}"
echo -e "${BOLD}${WHITE}               INCEPTION PROJECT VERIFICATION & COMPLIANCE SUITE              ${RESET}"
echo -e "${BOLD}${WHITE}==============================================================================${RESET}"
report_info "Repository Root : ${BOLD}${REPO_ROOT}${RESET}"
report_info "Current User    : ${BOLD}${USER_LOGIN}${RESET} (Intra Login: ${INTRA_LOGIN})"
report_info "Target Domain   : ${BOLD}${DOMAIN_NAME}${RESET}"
report_info "Timestamp       : $(date)"

# ==============================================================================
# SECTION 1: INSTANT FAIL / ZERO-TOLERANCE CRITERIA (STATIC CHECKS)
# ==============================================================================
print_header "1. Instant Fail / Zero-Tolerance Criteria & Static Code Audit"

print_subsection "Git & Secret Files Audit"

# Check 1.1: .gitignore exists and ignores .env & secrets
if [ -f ".gitignore" ]; then
    report_pass ".gitignore file exists at repository root"
    
    if grep -q -E '(^|/)secrets(/|\*|$|\.txt)' .gitignore; then
        report_pass ".gitignore ignores secrets directory/files"
    else
        report_fail ".gitignore missing rule for secrets/" "Secrets directory must be explicitly ignored"
    fi
else
    report_fail ".gitignore missing" "A .gitignore file is required to prevent accidental secret leakage"
fi

# Check 1.2: Check if secrets/ are tracked in git index, and verify .env has NO plaintext passwords
if [ -d ".git" ]; then
    TRACKED_SECRETS=$(git ls-files secrets/ 2>/dev/null || true)
    if [ -z "$TRACKED_SECRETS" ]; then
        report_pass "No files in secrets/ are tracked in Git"
    else
        report_fail "Secrets tracked in Git!" "Found committed secret files: $TRACKED_SECRETS"
    fi

    # Check if .env contains any secrets/passwords if tracked
    TRACKED_ENV=$(git ls-files srcs/.env .env 2>/dev/null || true)
    if [ -n "$TRACKED_ENV" ]; then
        if grep -i -E '(password|passwd|secret_key|api_key|token)[[:space:]]*=[[:space:]]*[^[:space:]]+' "$ENV_FILE" 2>/dev/null; then
            report_fail "Committed .env contains sensitive passwords/credentials!" "Passwords must only be in Docker secrets, not in git"
        else
            report_pass "Committed .env is clean (contains only non-sensitive variables: domain, usernames, db name)"
        fi
    else
        report_pass ".env is local / ignored by Git"
    fi
else
    report_warn "Not a git repository or .git not present" "Skipping git tracking checks"
fi

print_subsection "Required Files & Non-Empty Check"
REQUIRED_CORE_FILES=(
    "Makefile"
    "README.md"
    "USER_DOC.md"
    "DEV_DOC.md"
    "srcs/docker-compose.yml"
    "srcs/requirements/mariadb/Dockerfile"
    "srcs/requirements/wordpress/Dockerfile"
    "srcs/requirements/nginx/Dockerfile"
)

for file in "${REQUIRED_CORE_FILES[@]}"; do
    if [ -f "$file" ]; then
        if [ -s "$file" ]; then
            report_pass "File exists and is non-empty: $file"
        else
            report_fail "Empty required file: $file" "Subject terminates eval if required files are empty"
        fi
    else
        report_fail "Missing required file: $file" "File must exist according to directory structure"
    fi
done

print_subsection "Base OS & Prohibited Directives in Dockerfiles"
DOCKERFILES=$(find srcs/requirements -name "Dockerfile" 2>/dev/null || true)

if [ -z "$DOCKERFILES" ]; then
    report_fail "No Dockerfiles found in srcs/requirements/"
else
    for df in $DOCKERFILES; do
        service_name=$(basename "$(dirname "$df")")
        
        # Check FROM line
        FROM_LINE=$(grep -E '^[[:space:]]*FROM[[:space:]]+' "$df" | head -n 1)
        
        # Prohibit ready-made images
        if echo "$FROM_LINE" | grep -q -E 'FROM[[:space:]]+(wordpress|mariadb|mysql|nginx|httpd|php)'; then
            report_fail "$df uses prohibited pre-made image" "$FROM_LINE"
        else
            report_pass "$df does not use pre-made ready images ($service_name)"
        fi

        # Check 'latest' tag
        if echo "$FROM_LINE" | grep -q -E ':latest\b'; then
            report_fail "$df uses prohibited 'latest' tag" "$FROM_LINE"
        else
            report_pass "$df does not use ':latest' tag ($service_name)"
        fi

        # Check Base OS (Debian 11/12 or Alpine 3.18/3.19/3.20)
        if echo "$FROM_LINE" | grep -q -E 'FROM[[:space:]]+(debian:(11|12|bullseye|bookworm)|alpine:(3\.[0-9]+))'; then
            report_pass "$df uses penultimate/stable Debian or Alpine base" "$FROM_LINE"
        else
            report_warn "$df base image version" "Found '$FROM_LINE' (Subject specifies penultimate stable Debian/Alpine)"
        fi

        # Check forbidden keepalive hacks in Dockerfile
        if grep -q -E '(tail[[:space:]]+-f|sleep[[:space:]]+infinity|while[[:space:]]+true)' "$df"; then
            report_fail "$df contains forbidden keepalive loop / hack" "Found tail -f, sleep infinity, or while true"
        else
            report_pass "$df has no forbidden keepalive loops ($service_name)"
        fi

        # Check no hardcoded passwords in Dockerfile
        if grep -i -E '(password|passwd|secret)[[:space:]]*=[[:space:]]*[a-zA-Z0-9_]{3,}' "$df" | grep -v -E '(ARG|ENV[[:space:]]+[A-Z_]+_FILE)'; then
            report_fail "$df contains potential hardcoded plaintext credentials"
        else
            report_pass "$df free of obvious hardcoded plaintext passwords"
        fi
    done
fi

# Check that WordPress and MariaDB Dockerfiles DO NOT install NGINX
if [ -f "srcs/requirements/wordpress/Dockerfile" ]; then
    if grep -q -i -E '\bnginx\b' srcs/requirements/wordpress/Dockerfile; then
        report_fail "WordPress Dockerfile contains NGINX package!" "WordPress container must NOT contain NGINX"
    else
        report_pass "WordPress container does not install NGINX"
    fi
fi

if [ -f "srcs/requirements/mariadb/Dockerfile" ]; then
    if grep -q -i -E '\bnginx\b' srcs/requirements/mariadb/Dockerfile; then
        report_fail "MariaDB Dockerfile contains NGINX package!" "MariaDB container must NOT contain NGINX"
    else
        report_pass "MariaDB container does not install NGINX"
    fi
fi

print_subsection "Docker Compose Configuration Audit (srcs/docker-compose.yml)"
COMPOSE_FILE="srcs/docker-compose.yml"
if [ -f "$COMPOSE_FILE" ]; then
    # Check no 'network: host' / 'network_mode: host'
    if grep -q -E 'network(_mode)?:[[:space:]]*host' "$COMPOSE_FILE"; then
        report_fail "docker-compose.yml uses prohibited 'network: host'"
    else
        report_pass "docker-compose.yml does NOT use host networking mode"
    fi

    # Check no 'links:'
    if grep -q -E '^[[:space:]]*links:' "$COMPOSE_FILE"; then
        report_fail "docker-compose.yml uses prohibited 'links:' directive"
    else
        report_pass "docker-compose.yml does NOT use legacy 'links:'"
    fi

    # Check explicit 'networks:'
    if grep -q -E '^[[:space:]]*networks:' "$COMPOSE_FILE"; then
        report_pass "docker-compose.yml defines custom bridge network(s)"
    else
        report_fail "docker-compose.yml is missing explicit 'networks:' section"
    fi

    # Check no 'latest' tag in compose
    if grep -E 'image:[[:space:]]*[^:]+:latest\b' "$COMPOSE_FILE"; then
        report_fail "docker-compose.yml contains prohibited ':latest' tag"
    else
        report_pass "docker-compose.yml does NOT use ':latest' tags"
    fi

    # Check port mappings (Only NGINX should have host ports, port 80 must not be mapped)
    if grep -E '["'\'' ]80:80["'\'' ]' "$COMPOSE_FILE" | grep -v '^[[:space:]]*#'; then
        report_fail "Port 80 is mapped to host in docker-compose.yml!" "HTTP port 80 is forbidden"
    else
        report_pass "Port 80 is NOT mapped to host in docker-compose.yml"
    fi

    if grep -E '["'\'' ]443:443["'\'' ]' "$COMPOSE_FILE" | grep -v '^[[:space:]]*#'; then
        report_pass "Port 443 (HTTPS) is mapped in docker-compose.yml"
    else
        report_fail "Port 443 mapping missing in docker-compose.yml" "NGINX must expose port 443"
    fi

    # Check MariaDB & WordPress port exposure
    if grep -A 10 'mariadb:' "$COMPOSE_FILE" | grep -E '^[[:space:]]*ports:' | grep -v '^[[:space:]]*#'; then
        report_fail "MariaDB service has host 'ports:' exposed in docker-compose.yml" "Should only expose internally"
    else
        report_pass "MariaDB does not expose host ports in docker-compose.yml"
    fi

    if grep -A 10 'wordpress:' "$COMPOSE_FILE" | grep -E '^[[:space:]]*ports:' | grep -v '^[[:space:]]*#'; then
        report_fail "WordPress service has host 'ports:' exposed in docker-compose.yml" "Should only expose internally"
    else
        report_pass "WordPress does not expose host ports in docker-compose.yml"
    fi

    # Check restart policies
    if grep -q -E 'restart:[[:space:]]*(always|unless-stopped|on-failure)' "$COMPOSE_FILE"; then
        report_pass "docker-compose.yml implements container restart policy"
    else
        report_warn "docker-compose.yml restart policy missing or non-standard"
    fi

    # Check secrets section
    if grep -q -E '^[[:space:]]*secrets:' "$COMPOSE_FILE"; then
        report_pass "docker-compose.yml defines Docker secrets"
    else
        report_fail "docker-compose.yml missing top-level 'secrets:' definition"
    fi

    # Check volumes section
    if grep -q -E '^[[:space:]]*volumes:' "$COMPOSE_FILE"; then
        report_pass "docker-compose.yml defines Docker named volumes"
    else
        report_fail "docker-compose.yml missing top-level 'volumes:' definition"
    fi
fi

print_subsection "Makefile & Script Audit"
# Check no '--link' in Makefile or any makefiles / scripts (exclude verification script itself)
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
LINK_MATCHES=$(grep -rn --include="Makefile*" --include="*.sh" --exclude="$SCRIPT_NAME" --exclude-dir=".git" -- "--link\b" . || true)
if [ -n "$LINK_MATCHES" ]; then
    report_fail "Prohibited '--link' flag found in files" "$LINK_MATCHES"
else
    report_pass "No prohibited '--link' flag in Makefile or helper scripts"
fi

# Entrypoint/helper scripts may not keep containers alive with dummy processes
# or infinite loops. Exclude verification scripts from auditing themselves.
KEEPALIVE_MATCHES=$(grep -rnE \
    --include="*.sh" \
    --exclude="inception_verify.sh" \
    --exclude="inception_verify_bonus.sh" \
    --exclude-dir=".git" \
    '(tail[[:space:]]+-f|sleep[[:space:]]+infinity|while[[:space:]]+(true|:)|[;&][[:space:]]*(bash|sh)([[:space:]]|$))' \
    srcs Makefile* 2>/dev/null || true)
if [ -n "$KEEPALIVE_MATCHES" ]; then
    report_fail "Prohibited keepalive/background pattern found in project scripts" "$KEEPALIVE_MATCHES"
else
    report_pass "Entrypoint and helper scripts contain no prohibited keepalive hacks"
fi

print_subsection "WordPress Admin Username Constraint"
if [ -n "$WP_ADMIN_USER" ]; then
    if echo "$WP_ADMIN_USER" | grep -i -q "admin"; then
        report_fail "WP_ADMIN_USER contains forbidden keyword 'admin' ('$WP_ADMIN_USER')" "Subject strictly prohibits admin, Admin, administrator, etc."
    else
        report_pass "WP_ADMIN_USER ('$WP_ADMIN_USER') is valid and does NOT contain 'admin'"
    fi
else
    report_warn "WP_ADMIN_USER not found in srcs/.env" "Check .env variable naming"
fi

# ==============================================================================
# SECTION 2: REPOSITORY & DIRECTORY STRUCTURE
# ==============================================================================
print_header "2. Repository & Directory Structure Verification"

EXPECTED_DIRS=(
    "srcs"
    "srcs/requirements"
    "srcs/requirements/mariadb"
    "srcs/requirements/mariadb/conf"
    "srcs/requirements/mariadb/tools"
    "srcs/requirements/wordpress"
    "srcs/requirements/wordpress/conf"
    "srcs/requirements/wordpress/tools"
    "srcs/requirements/nginx"
    "srcs/requirements/nginx/conf"
    "srcs/requirements/nginx/tools"
)

for dir in "${EXPECTED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        report_pass "Directory exists: $dir"
    else
        report_fail "Missing directory: $dir"
    fi
done

# Check .dockerignore files
for svc in mariadb wordpress nginx; do
    if [ -f "srcs/requirements/$svc/.dockerignore" ]; then
        report_pass ".dockerignore exists for $svc"
    else
        report_warn ".dockerignore recommended for $svc (found in checklist)"
    fi
done

# ==============================================================================
# SECTION 3: MAKEFILE REQUIREMENTS & TARGETS
# ==============================================================================
print_header "3. Makefile Targets & Rules Verification"

if [ -f "Makefile" ]; then
    # Test required targets without executing them via dry-run (-n / -q) or make target queries
    REQUIRED_TARGETS=("all" "up" "down" "start" "stop" "re" "clean" "fclean")
    
    for target in "${REQUIRED_TARGETS[@]}"; do
        if make -n "$target" &>/dev/null; then
            report_pass "Makefile implements target: '$target'"
        else
            # Check if target name appears in Makefile or included makefiles
            if grep -E "^[[:space:]]*${target}[[:space:]]*:" Makefile* 2>/dev/null | grep -v '^\s*#'; then
                report_pass "Makefile defines target: '$target'"
            else
                report_fail "Makefile missing required target: '$target'" "Subject requires $target target"
            fi
        fi
    done
else
    report_fail "Makefile missing at root of repository"
fi

# ==============================================================================
# SECTION 4: DOCUMENTATION REQUIREMENTS
# ==============================================================================
print_header "4. Documentation Verification (README, USER_DOC, DEV_DOC)"

# 4.1 README.md
if [ -f "README.md" ]; then
    # Check exact first line format: *This project has been created as part of the 42 curriculum by <login>.*
    FIRST_LINE=$(head -n 1 README.md | tr -d '\r')
    if [[ "$FIRST_LINE" =~ ^\*This\ project\ has\ been\ created\ as\ part\ of\ the\ 42\ curriculum\ by\ .+\.\*$ ]]; then
        report_pass "README.md first line matches required italicized format" "$FIRST_LINE"
    else
        report_fail "README.md first line does not match required format" "Expected '*This project has been created as part of the 42 curriculum by <login>.*', got: '$FIRST_LINE'"
    fi

    # Check required sections
    for sec in "Description" "Instructions" "Resources"; do
        if grep -i -q -E "^#{1,3}[[:space:]]+.*${sec}" README.md; then
            report_pass "README.md contains section: $sec"
        else
            report_fail "README.md missing section: $sec"
        fi
    done

    # Check AI usage disclosure in Resources
    if grep -i -q -E '(artificial intelligence|\bai\b|copilot|chatgpt|claude|gemini)' README.md; then
        report_pass "README.md contains AI usage disclosure"
    else
        report_fail "README.md missing explicit AI usage description in Resources"
    fi

    # Check comparison sections
    COMPARISONS=(
        "Virtual Machines.*Docker"
        "Secrets.*Environment Variables"
        "Docker Network.*Host Network"
        "Docker Volumes.*Bind Mounts"
    )
    for comp in "${COMPARISONS[@]}"; do
        if grep -i -q -E "$comp" README.md; then
            report_pass "README.md contains comparison: $(echo "$comp" | sed 's/\.\*/ vs /g')"
        else
            report_fail "README.md missing comparison: $(echo "$comp" | sed 's/\.\*/ vs /g')"
        fi
    done
fi

# 4.2 USER_DOC.md
if [ -f "USER_DOC.md" ]; then
    for item in "start" "stop" "credential" "healthy|health"; do
        if grep -i -q -E "$item" USER_DOC.md; then
            report_pass "USER_DOC.md covers topic matching: '$item'"
        else
            report_warn "USER_DOC.md could expand on topic: '$item'"
        fi
    done
fi

# 4.3 DEV_DOC.md
if [ -f "DEV_DOC.md" ]; then
    for item in "prerequisite|setup" "build|launch" "volume|persist" "docker"; do
        if grep -i -q -E "$item" DEV_DOC.md; then
            report_pass "DEV_DOC.md covers topic matching: '$item'"
        else
            report_warn "DEV_DOC.md could expand on topic: '$item'"
        fi
    done
fi

# ==============================================================================
# SECTION 5: DOCKER RUNTIME & CONTAINER AUDIT (NON-DESTRUCTIVE)
# ==============================================================================
print_header "5. Docker Runtime & Running Containers Audit"

DOCKER_AVAILABLE=0
if command -v docker &>/dev/null && docker info &>/dev/null; then
    DOCKER_AVAILABLE=1
    report_pass "Docker daemon is running and accessible"
else
    report_fail "Docker daemon not running or not accessible" "Cannot perform runtime container checks"
fi

if [ "$DOCKER_AVAILABLE" -eq 1 ]; then
    CORE_CONTAINERS=("nginx" "wordpress" "mariadb")

    for c in "${CORE_CONTAINERS[@]}"; do
        STATUS=$(docker inspect --format '{{.State.Status}}' "$c" 2>/dev/null || echo "not_found")
        if [ "$STATUS" = "running" ]; then
            report_pass "Container '$c' is RUNNING"
            
            # Check container image name
            IMG=$(docker inspect --format '{{.Config.Image}}' "$c" 2>/dev/null || echo "")
            IMAGE_REPOSITORY="${IMG%%:*}"
            IMAGE_REPOSITORY="${IMAGE_REPOSITORY##*/}"
            if [ "$IMAGE_REPOSITORY" = "$c" ]; then
                report_pass "Container '$c' image name matches its service" "$IMG"
            else
                report_fail "Container '$c' image name matches its service" "Expected repository '$c', found '$IMG'"
            fi

            # Check restart policy
            RESTART_POLICY=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$c" 2>/dev/null || echo "")
            if [ -n "$RESTART_POLICY" ] && [ "$RESTART_POLICY" != "no" ]; then
                report_pass "Container '$c' restart policy: $RESTART_POLICY"
            else
                report_fail "Container '$c' has no restart policy configured"
            fi

            # Check PID 1 / Running process (No tail -f / sleep)
            TOP_CMD=$(docker top "$c" 2>/dev/null | awk 'NR>1 {print $NF}' | tr '\n' ' ' || echo "")
            if echo "$TOP_CMD" | grep -q -E '(tail|sleep)'; then
                report_fail "Container '$c' has suspicious keepalive process running" "$TOP_CMD"
            else
                report_pass "Container '$c' process table looks clean (no tail/sleep hacks)"
            fi
        else
            report_fail "Container '$c' is NOT running (Status: $STATUS)" "Run 'make' to start the containers before re-running"
        fi
    done

    # Check container isolation: WordPress and MariaDB containers must NOT have NGINX binary
    if docker inspect wordpress &>/dev/null; then
        if docker exec wordpress which nginx &>/dev/null; then
            report_fail "Container 'wordpress' contains 'nginx' binary!" "NGINX must only be in nginx container"
        else
            report_pass "Container 'wordpress' does NOT contain NGINX"
        fi
    fi

    if docker inspect mariadb &>/dev/null; then
        if docker exec mariadb which nginx &>/dev/null; then
            report_fail "Container 'mariadb' contains 'nginx' binary!" "NGINX must only be in nginx container"
        else
            report_pass "Container 'mariadb' does NOT contain NGINX"
        fi
    fi

    # Check MariaDB Health Status
    if docker inspect mariadb &>/dev/null; then
        HEALTH=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' mariadb 2>/dev/null || echo "none")
        if [ "$HEALTH" = "healthy" ]; then
            report_pass "MariaDB container healthcheck status: HEALTHY"
        elif [ "$HEALTH" = "none" ]; then
            report_info "MariaDB has no healthcheck configured (optional, but healthy is better)"
        else
            report_warn "MariaDB healthcheck status: $HEALTH"
        fi
    fi
fi

# ==============================================================================
# SECTION 6: VOLUMES & HOST PERSISTENCE (NON-DESTRUCTIVE)
# ==============================================================================
print_header "6. Volumes & Host Persistence Inspection (Non-Destructive)"

if [ "$DOCKER_AVAILABLE" -eq 1 ]; then
    VOLUMES_LIST=$(docker volume ls -q 2>/dev/null || true)
    
    # Check for MariaDB and WordPress volumes
    for vol_pattern in "mariadb" "wordpress"; do
        MATCHING_VOL=$(echo "$VOLUMES_LIST" | grep -E "${vol_pattern}" | head -n 1 || true)
        if [ -n "$MATCHING_VOL" ]; then
            report_pass "Named volume for $vol_pattern exists: $MATCHING_VOL"
            
            # Inspect mountpoint
            MOUNTPOINT=$(docker volume inspect --format '{{.Mountpoint}}' "$MATCHING_VOL" 2>/dev/null || echo "")
            DEVICE_PATH=$(docker volume inspect --format '{{if .Options}}{{index .Options "device"}}{{end}}' "$MATCHING_VOL" 2>/dev/null || echo "")
            if printf '%s\n%s\n' "$MOUNTPOINT" "$DEVICE_PATH" | grep -q -E "^/home/${INTRA_LOGIN}/data(/|$)"; then
                report_pass "Volume $MATCHING_VOL persists inside /home/${INTRA_LOGIN}/data" "${DEVICE_PATH:-$MOUNTPOINT}"
            else
                report_fail "Volume $MATCHING_VOL is not backed by /home/${INTRA_LOGIN}/data" "Mountpoint='$MOUNTPOINT', device='${DEVICE_PATH:-unset}'"
            fi
        else
            report_fail "Named volume for $vol_pattern not found in 'docker volume ls'"
        fi
    done

    # Check Host data directory
    HOST_DATA_DIR="/home/$USER_LOGIN/data"
    if [ -d "$HOST_DATA_DIR" ]; then
        report_pass "Host data directory exists at $HOST_DATA_DIR"
    elif [ -d "/home/$INTRA_LOGIN/data" ]; then
        report_pass "Host data directory exists at /home/$INTRA_LOGIN/data"
    else
        report_warn "Host data directory /home/$USER_LOGIN/data does not exist yet"
    fi
fi

# ==============================================================================
# SECTION 7: NETWORKING, PORT ISOLATION & TLS CONFIGURATION
# ==============================================================================
print_header "7. Networking, Port Isolation & TLS Protocol Verification"

# 7.1 DNS & /etc/hosts check
if grep -q -E "[[:space:]]+${DOMAIN_NAME}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
    report_pass "/etc/hosts contains domain entry for '$DOMAIN_NAME'"
else
    report_fail "/etc/hosts missing entry for '$DOMAIN_NAME'" "Add '127.0.0.1 $DOMAIN_NAME' to /etc/hosts"
fi

# 7.2 Port Accessibility checks on Host
print_subsection "Host Port Exposure Audit"

# Helper for testing TCP port
check_tcp_port() {
    local host="127.0.0.1"
    local port="$1"
    timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
}

# Port 80 must be CLOSED
if check_tcp_port 80; then
    report_fail "Port 80 (HTTP) is OPEN on host!" "Port 80 must NOT be open or accessible"
else
    report_pass "Port 80 (HTTP) is CLOSED / BLOCKED (as required)"
fi

# Port 443 must be OPEN
if check_tcp_port 443; then
    report_pass "Port 443 (HTTPS) is OPEN on host"
else
    report_fail "Port 443 (HTTPS) is NOT reachable on 127.0.0.1" "NGINX should be listening on port 443"
fi

# Port 3306 (MariaDB) must be CLOSED on host
if check_tcp_port 3306; then
    report_fail "Port 3306 (MariaDB) is EXPOSED to host!" "Database port must only be internal"
else
    report_pass "Port 3306 (MariaDB) is NOT exposed to host (Internal only)"
fi

# FastCGI Port (9000 or 9876) must be CLOSED on host
for wp_port in 9000 9876; do
    if check_tcp_port $wp_port; then
        report_fail "Port $wp_port (PHP-FPM) is EXPOSED to host!" "FastCGI port must only be internal"
    fi
done
report_pass "WordPress FastCGI port is NOT exposed to host (Internal only)"

# 7.3 TLS Protocol Version Enforcement
print_subsection "TLS Protocol Version Audit (OpenSSL)"

test_tls_version() {
    local flag="$1"
    local cipher_arg="${2:-}"
    local output
    output=$(openssl s_client -connect 127.0.0.1:443 $flag $cipher_arg </dev/null 2>&1 || true)
    
    if echo "$output" | grep -q -E '(Cipher is \(NONE\)|handshake failure|no protocols available|error:)'; then
        return 1
    elif echo "$output" | grep -q -E '(Protocol[[:space:]]*:[[:space:]]*TLS|Cipher is )'; then
        return 0
    else
        return 1
    fi
}

# TLSv1.2 MUST SUCCEED
if test_tls_version "-tls1_2"; then
    report_pass "TLSv1.2 is SUPPORTED and accepted by NGINX"
else
    report_fail "TLSv1.2 handshake failed!" "Subject requires TLSv1.2 or TLSv1.3"
fi

# TLSv1.3 MUST SUCCEED
if test_tls_version "-tls1_3"; then
    report_pass "TLSv1.3 is SUPPORTED and accepted by NGINX"
else
    report_warn "TLSv1.3 handshake did not succeed (TLSv1.2 is active)"
fi

# TLSv1.1 MUST FAIL / REJECT
if test_tls_version "-tls1_1" "-cipher DEFAULT:@SECLEVEL=0"; then
    report_fail "TLSv1.1 is ACCEPTED by NGINX!" "TLSv1.1 must be strictly disabled"
else
    report_pass "TLSv1.1 is REJECTED by NGINX (as required)"
fi

# TLSv1.0 MUST FAIL / REJECT
if test_tls_version "-tls1" "-cipher DEFAULT:@SECLEVEL=0"; then
    report_fail "TLSv1.0 is ACCEPTED by NGINX!" "TLSv1.0 must be strictly disabled"
else
    report_pass "TLSv1.0 is REJECTED by NGINX (as required)"
fi

# SSLv3 MUST FAIL / REJECT
if test_tls_version "-ssl3"; then
    report_fail "SSLv3 is ACCEPTED by NGINX!" "SSLv3 must be strictly disabled"
else
    report_pass "SSLv3 is REJECTED by NGINX (as required)"
fi

# 7.4 HTTPS Web Response
print_subsection "HTTPS Web Connectivity & WordPress Response"

HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --resolve "${DOMAIN_NAME}:443:127.0.0.1" "https://${DOMAIN_NAME}" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    report_pass "HTTPS request to 'https://${DOMAIN_NAME}' returns HTTP $HTTP_CODE"
else
    report_fail "HTTPS request to 'https://${DOMAIN_NAME}' failed (HTTP Code: $HTTP_CODE)"
fi

# Check that response is not the WordPress install wizard
PAGE_CONTENT=$(curl -k -s -L --resolve "${DOMAIN_NAME}:443:127.0.0.1" "https://${DOMAIN_NAME}" 2>/dev/null || echo "")
if echo "$PAGE_CONTENT" | grep -q -i "wp-admin/install.php"; then
    report_fail "WordPress is showing the initial setup wizard!" "WordPress must be pre-configured"
else
    report_pass "WordPress site is pre-configured (no setup wizard)"
fi

# Check wp-login.php returns 200
LOGIN_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --resolve "${DOMAIN_NAME}:443:127.0.0.1" "https://${DOMAIN_NAME}/wp-login.php" 2>/dev/null || echo "000")
if [ "$LOGIN_CODE" = "200" ]; then
    report_pass "WordPress login page (wp-login.php) accessible (HTTP 200)"
else
    report_warn "WordPress login page returned HTTP $LOGIN_CODE"
fi

# ==============================================================================
# SECTION 8: WORDPRESS ACCOUNTS & MARIADB DATABASE VERIFICATION
# ==============================================================================
print_header "8. WordPress Accounts & MariaDB Data Verification"

if [ "$DOCKER_AVAILABLE" -eq 1 ] && docker inspect wordpress &>/dev/null; then
    print_subsection "WordPress User Accounts Audit"
    
    WP_USERS_JSON=$(docker exec wordpress wp user list --format=json --allow-root 2>/dev/null || echo "")
    
    if [ -n "$WP_USERS_JSON" ] && [ "$WP_USERS_JSON" != "[]" ]; then
        USER_COUNT=$(echo "$WP_USERS_JSON" | grep -o '"user_login"' | wc -l)
        report_pass "WordPress has $USER_COUNT configured user(s)"
        
        # Check if at least 2 users exist
        if [ "$USER_COUNT" -ge 2 ]; then
            report_pass "At least 2 user accounts exist in WordPress"
        else
            report_fail "Fewer than 2 user accounts in WordPress (Found: $USER_COUNT)" "Must have 1 admin and 1 regular user"
        fi

        # Check admin username for forbidden 'admin'
        ADMIN_LOGIN=$(docker exec wordpress wp user list --role=administrator --field=user_login --allow-root 2>/dev/null || echo "")
        if [ -n "$ADMIN_LOGIN" ]; then
            if echo "$ADMIN_LOGIN" | grep -i -q "admin"; then
                report_fail "Administrator username '$ADMIN_LOGIN' contains forbidden keyword 'admin'!" "Subject strictly prohibits admin, Admin, administrator, etc."
            else
                report_pass "Administrator username '$ADMIN_LOGIN' does NOT contain 'admin' (Strict Rule Compliant)"
            fi
        else
            report_fail "No user with administrator role found in WordPress!"
        fi

        # Check regular / non-admin user
        NON_ADMIN=$(docker exec wordpress wp user list --fields=user_login,roles --format=csv --allow-root 2>/dev/null | grep -v 'administrator' | grep -v 'roles' | head -n 1 || echo "")
        if [ -n "$NON_ADMIN" ]; then
            report_pass "Regular/non-admin user exists: $NON_ADMIN"
        else
            report_warn "Could not confirm secondary non-admin user role"
        fi
    else
        report_fail "Unable to query WordPress users via wp-cli"
    fi
fi

if [ "$DOCKER_AVAILABLE" -eq 1 ] && docker inspect mariadb &>/dev/null; then
    print_subsection "MariaDB Database & Tables Audit"
    
    # Try querying tables via MariaDB container
    DB_TABLES=$(docker exec mariadb sh -c '
        if [ -f /run/secrets/db_root_password ]; then
            mariadb -u root -p"$(cat /run/secrets/db_root_password)" -e "USE wordpress; SHOW TABLES;" 2>/dev/null
        fi
    ' || true)

    if [ -n "$DB_TABLES" ]; then
        report_pass "MariaDB is accessible and 'wordpress' database exists"
        
        for req_table in "wp_users" "wp_posts" "wp_comments" "wp_options"; do
            if echo "$DB_TABLES" | grep -q "$req_table"; then
                report_pass "Database table exists: $req_table"
            else
                report_fail "Missing expected WordPress table: $req_table"
            fi
        done
    else
        report_warn "Could not directly query MariaDB tables (check root secret mount or credentials)"
    fi
fi

# ==============================================================================
# SECTION 9: BONUS SERVICES (IF PRESENT)
# ==============================================================================
print_header "9. Bonus Services Audit (Strict Subject Mode)"

BONUS_VERIFIER="$SCRIPT_DIR/inception_verify_bonus.sh"
if [ -f "$BONUS_VERIFIER" ]; then
    report_info "Running dedicated bonus verifier: $BONUS_VERIFIER"
    if bash "$BONUS_VERIFIER" "$REPO_ROOT"; then
        report_pass "All automated bonus requirements passed"
    else
        report_fail "Bonus verification failed" "Review the detailed bonus report above"
    fi
else
    report_fail "Dedicated bonus verifier is missing" "$BONUS_VERIFIER"
fi

print_header "10. Manual Defense Checks (Evaluator Action Required)"
report_warn "Confirm the project is running inside the required virtual machine"
report_warn "Have the learner explain Docker, Compose, images, networks, volumes, and containers"
report_warn "Create a WordPress comment as the regular user and edit a page as the administrator"
report_warn "Reboot the VM, relaunch the stack, and confirm WordPress and MariaDB persistence"
report_warn "Request a live service configuration change, rebuild, and verify continued operation"
report_info "These checks are intentionally not automated because they require human explanation, credentials, mutation, or a VM reboot."

# ==============================================================================
# SUMMARY & SCORECARD
# ==============================================================================
print_header "Evaluation Summary & Scorecard"

echo -e "  Total Checks Executed : ${BOLD}${TOTAL_COUNT}${RESET}"
echo -e "  Checks Passed         : ${BOLD}${GREEN}${PASSED_COUNT}${RESET}"
echo -e "  Checks Failed         : ${BOLD}${RED}${FAILED_COUNT}${RESET}"
echo -e "  Warnings / Notes      : ${BOLD}${YELLOW}${WARNING_COUNT}${RESET}"

echo ""
if [ "$FAILED_COUNT" -eq 0 ]; then
    echo -e "${BOLD}${GREEN}==============================================================================${RESET}"
    echo -e "${BOLD}${GREEN}  >>> ALL PROGRAMMATIC CHECKS PASSED SUCCESSFULLY! 100% COMPLIANT <<<        ${RESET}"
    echo -e "${BOLD}${GREEN}==============================================================================${RESET}"
    echo -e "Ready for Peer Evaluation & Live Defense."
    exit 0
else
    echo -e "${BOLD}${RED}==============================================================================${RESET}"
    echo -e "${BOLD}${RED}  >>> WARNING: ${FAILED_COUNT} CHECK(S) FAILED. REVIEW THE ISSUES ABOVE! <<<          ${RESET}"
    echo -e "${BOLD}${RED}==============================================================================${RESET}"
    exit 1
fi
