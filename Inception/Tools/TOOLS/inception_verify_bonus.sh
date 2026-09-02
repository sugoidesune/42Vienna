#!/usr/bin/env bash
# Strict, non-destructive verification for the optional Inception bonus part.
# This script is called by inception_verify.sh and can also be run directly:
#   bash inception_verify_bonus.sh [path_to_inception_repo]

set -uo pipefail

BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
BLUE="\033[0;34m"

PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

pass() {
    ((PASSED++))
    ((TOTAL++))
    echo -e "  [ ${GREEN}PASS${RESET} ] $1${2:+ ($2)}"
}

fail() {
    ((FAILED++))
    ((TOTAL++))
    echo -e "  [ ${RED}FAIL${RESET} ] ${BOLD}$1${RESET}"
    [ -z "${2:-}" ] || echo -e "           ${RED}↳ $2${RESET}"
}

warn() {
    ((WARNINGS++))
    echo -e "  [ ${YELLOW}WARN${RESET} ] $1"
    [ -z "${2:-}" ] || echo -e "           ${YELLOW}↳ $2${RESET}"
}

info() {
    echo -e "  [ ${CYAN}INFO${RESET} ] $1"
}

section() {
    echo -e "\n${BOLD}${BLUE}--- $1 ---${RESET}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$SCRIPT_DIR}"
COMPOSE_FILE="$REPO_ROOT/srcs/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found" >&2
    exit 1
fi

cd "$REPO_ROOT" || exit 1
COMPOSE=(docker compose -f "$COMPOSE_FILE")

DOMAIN_NAME="$(grep -E '^[[:space:]]*DOMAIN_NAME=' srcs/.env 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d "\"'\r" | xargs || true)"
SERVICES="$("${COMPOSE[@]}" config --services 2>/dev/null || true)"

echo -e "${BOLD}${CYAN}==============================================================================${RESET}"
echo -e "${BOLD}                INCEPTION STRICT BONUS VERIFICATION SUITE${RESET}"
echo -e "${BOLD}${CYAN}==============================================================================${RESET}"
info "Repository: $REPO_ROOT"
info "Domain: ${DOMAIN_NAME:-not configured}"
info "This suite is non-destructive; it does not restart services or modify data."

if [ -z "$SERVICES" ]; then
    fail "Compose configuration could not be resolved" "Run docker compose config and fix any reported error."
fi

has_service() {
    printf '%s\n' "$SERVICES" | grep -qx "$1"
}

find_service() {
    printf '%s\n' "$SERVICES" | grep -E "$1" | head -n 1 || true
}

service_block() {
    local service="$1"
    awk -v service="$service" '
        /^services:[[:space:]]*$/ { in_services=1; next }
        in_services && /^[^[:space:]]/ { exit }
        in_services && $0 ~ "^  " service ":[[:space:]]*$" { found=1; print; next }
        found && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { exit }
        found { print }
    ' "$COMPOSE_FILE"
}

container_id() {
    "${COMPOSE[@]}" ps -q "$1" 2>/dev/null | head -n 1
}

check_running_service() {
    local service="$1"
    local id state image repository restart networks published

    id="$(container_id "$service")"
    if [ -z "$id" ]; then
        fail "Bonus container '$service' exists and is running" "No Compose container ID found."
        return 1
    fi

    state="$(docker inspect --format '{{.State.Status}}' "$id" 2>/dev/null || true)"
    if [ "$state" = "running" ]; then
        pass "Bonus container '$service' is running"
    else
        fail "Bonus container '$service' is running" "State: ${state:-unknown}"
        return 1
    fi

    image="$(docker inspect --format '{{.Config.Image}}' "$id" 2>/dev/null || true)"
    repository="${image%%:*}"
    repository="${repository##*/}"
    if [ "$repository" = "$service" ]; then
        pass "Image name matches service '$service'" "$image"
    else
        fail "Image name matches service '$service'" "Container uses '$image'."
    fi

    restart="$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$id" 2>/dev/null || true)"
    if [ -n "$restart" ] && [ "$restart" != "no" ]; then
        pass "Bonus service '$service' has a restart policy" "$restart"
    else
        fail "Bonus service '$service' has a restart policy"
    fi

    networks="$(docker inspect --format '{{range $name, $config := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$id" 2>/dev/null || true)"
    if [ -n "$networks" ]; then
        pass "Bonus service '$service' joins a Docker network" "$(echo "$networks" | xargs)"
    else
        fail "Bonus service '$service' joins a Docker network"
    fi

    published="$(docker port "$id" 2>/dev/null || true)"
    if [ -z "$published" ]; then
        pass "Bonus service '$service' has no direct host port exposure"
    else
        fail "Bonus service '$service' bypasses NGINX with a host port" "$published"
    fi
}

check_bonus_definition() {
    local service="$1"
    local directory="$2"
    local block from_line

    if has_service "$service"; then
        pass "Compose defines bonus service '$service'"
    else
        fail "Compose defines bonus service '$service'"
        return
    fi

    if [ -s "$directory/Dockerfile" ]; then
        pass "Bonus service '$service' has a non-empty dedicated Dockerfile"
    else
        fail "Bonus service '$service' has a non-empty dedicated Dockerfile" "$directory/Dockerfile"
        return
    fi

    block="$(service_block "$service")"
    if printf '%s\n' "$block" | grep -q '^[[:space:]]*build:'; then
        pass "Bonus service '$service' is built locally by Compose"
    else
        fail "Bonus service '$service' is built locally by Compose"
    fi

    from_line="$(grep -E '^[[:space:]]*FROM[[:space:]]+' "$directory/Dockerfile" | head -n 1)"
    if printf '%s\n' "$from_line" | grep -Eq 'FROM[[:space:]]+(alpine|debian):[^[:space:]]+'; then
        pass "Bonus service '$service' starts from Alpine or Debian" "$from_line"
    else
        fail "Bonus service '$service' starts from Alpine or Debian" "$from_line"
    fi
}

section "Bonus topology and dedicated images"

REDIS_SERVICE="$(find_service '^redis$')"
STATIC_SERVICE="$(find_service '^(static|static_serv|website_static)$')"
ADMINER_SERVICE="$(find_service '^adminer$')"
FTP_SERVICE="$(find_service '(^|_)(ftp|vsftpd)(_|$)')"

if [ -n "$REDIS_SERVICE" ]; then
    check_bonus_definition "$REDIS_SERVICE" "srcs/requirements/bonus/redis"
else
    fail "Required Redis cache bonus service is present"
fi

if [ -n "$STATIC_SERVICE" ]; then
    check_bonus_definition "$STATIC_SERVICE" "srcs/requirements/bonus/static_serv"
else
    fail "Required static website bonus service is present"
fi

if [ -n "$ADMINER_SERVICE" ]; then
    check_bonus_definition "$ADMINER_SERVICE" "srcs/requirements/bonus/adminer"
else
    fail "Required Adminer bonus service is present"
fi

if [ -n "$FTP_SERVICE" ]; then
    FTP_DIR="$(find srcs/requirements/bonus -mindepth 1 -maxdepth 1 -type d -iname '*ftp*' | head -n 1)"
    check_bonus_definition "$FTP_SERVICE" "${FTP_DIR:-srcs/requirements/bonus/ftp}"
else
    fail "Required FTP bonus service is present" "The subject bonus requires an FTP server attached to the WordPress files volume."
fi

CUSTOM_SERVICE=""
while IFS= read -r service; do
    case "$service" in
        nginx|wordpress|mariadb|redis|adminer|static|static_serv|website_static|ftp|vsftpd) ;;
        *) CUSTOM_SERVICE="$service"; break ;;
    esac
done <<< "$SERVICES"

if [ -n "$CUSTOM_SERVICE" ]; then
    CUSTOM_CONTEXT="$(service_block "$CUSTOM_SERVICE" | awk '/context:/ { print $2; exit }' | sed 's#^\./#srcs/#')"
    CUSTOM_DIR="${CUSTOM_CONTEXT:-srcs/requirements/bonus/$CUSTOM_SERVICE}"
    check_bonus_definition "$CUSTOM_SERVICE" "$CUSTOM_DIR"
    if grep -Rqi --exclude-dir=.git -E "$CUSTOM_SERVICE|uptime[[:space:]_-]*kuma" README.md USER_DOC.md DEV_DOC.md 2>/dev/null; then
        pass "Custom bonus service '$CUSTOM_SERVICE' is documented and justified"
    else
        fail "Custom bonus service '$CUSTOM_SERVICE' is documented and justified"
    fi
else
    fail "A useful custom bonus service is present"
fi

section "Redis object-cache integration"

if [ -n "$REDIS_SERVICE" ]; then
    if grep -q 'WP_REDIS_HOST' srcs/requirements/wordpress/tools/*.sh 2>/dev/null &&
       grep -qE 'wp[[:space:]]+redis[[:space:]]+enable|redis-cache' srcs/requirements/wordpress/tools/*.sh 2>/dev/null; then
        pass "WordPress initialization configures and enables Redis object caching"
    else
        fail "WordPress initialization configures and enables Redis object caching"
    fi

    if grep -qE '^[[:space:]]*daemonize[[:space:]]+no' srcs/requirements/bonus/redis/conf/* 2>/dev/null; then
        pass "Redis runs in the foreground"
    else
        fail "Redis runs in the foreground"
    fi

    if grep -qE '^[[:space:]]*maxmemory-policy[[:space:]]+(allkeys|volatile)-' srcs/requirements/bonus/redis/conf/* 2>/dev/null; then
        pass "Redis defines an eviction policy suitable for a cache"
    else
        fail "Redis defines an eviction policy suitable for a cache"
    fi
fi

section "Static website implementation"

if [ -n "$STATIC_SERVICE" ]; then
    if find srcs/requirements/bonus/static_serv -type f -iname '*.php' | grep -q . ||
       grep -qiE 'apk add.*php|apt-get install.*php' srcs/requirements/bonus/static_serv/Dockerfile 2>/dev/null; then
        fail "Static website is implemented without PHP"
    else
        pass "Static website is implemented without PHP"
    fi

    if find srcs/requirements/bonus/static_serv -type f \( -iname '*.html' -o -iname '*.css' -o -iname '*.js' \) | grep -q .; then
        pass "Static website contains authored web content"
    else
        fail "Static website contains authored web content"
    fi

    if grep -qE 'proxy_pass[[:space:]]+http://(static_serv|static|website_static):' srcs/requirements/nginx/conf/* 2>/dev/null; then
        pass "NGINX routes HTTPS traffic to the static website service"
    else
        fail "NGINX routes HTTPS traffic to the static website service"
    fi
fi

section "Adminer and custom-service routing"

if [ -n "$ADMINER_SERVICE" ]; then
    if grep -qE 'proxy_pass[[:space:]]+http://adminer:' srcs/requirements/nginx/conf/* 2>/dev/null; then
        pass "NGINX routes an HTTPS virtual host to Adminer"
    else
        fail "NGINX routes an HTTPS virtual host to Adminer"
    fi
fi

if [ -n "$CUSTOM_SERVICE" ]; then
    if grep -qE "proxy_pass[[:space:]]+http://${CUSTOM_SERVICE}:" srcs/requirements/nginx/conf/* 2>/dev/null; then
        pass "NGINX routes HTTPS traffic to custom service '$CUSTOM_SERVICE'"
    else
        warn "No NGINX route found for custom service '$CUSTOM_SERVICE'" "A non-web custom service may not need one."
    fi
fi

section "FTP volume and exposure"

if [ -n "$FTP_SERVICE" ]; then
    FTP_BLOCK="$(service_block "$FTP_SERVICE")"
    if printf '%s\n' "$FTP_BLOCK" | grep -qE 'wordpress(_vol)?:'; then
        pass "FTP shares the WordPress website named volume"
    else
        fail "FTP shares the WordPress website named volume"
    fi
    if printf '%s\n' "$FTP_BLOCK" | grep -qE '(^|[^0-9])21:21([^0-9]|$)'; then
        pass "FTP publishes its control port"
    else
        fail "FTP publishes its control port"
    fi
fi

section "Live bonus services"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    fail "Docker daemon is available for bonus runtime checks"
else
    for service in "$REDIS_SERVICE" "$STATIC_SERVICE" "$ADMINER_SERVICE" "$CUSTOM_SERVICE"; do
        [ -z "$service" ] || check_running_service "$service"
    done

    if [ -n "$FTP_SERVICE" ]; then
        id="$(container_id "$FTP_SERVICE")"
        state="$([ -n "$id" ] && docker inspect --format '{{.State.Status}}' "$id" 2>/dev/null || true)"
        if [ "$state" = "running" ]; then
            pass "FTP bonus container is running"
            FTP_MOUNTS="$(docker inspect --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}' "$id" 2>/dev/null || true)"
            if printf '%s\n' "$FTP_MOUNTS" | grep -qi wordpress; then
                pass "Running FTP container mounts the WordPress volume"
            else
                fail "Running FTP container mounts the WordPress volume" "$FTP_MOUNTS"
            fi
        else
            fail "FTP bonus container is running" "State: ${state:-not created}"
        fi
    fi

    if [ -n "$REDIS_SERVICE" ]; then
        REDIS_PING="$("${COMPOSE[@]}" exec -T "$REDIS_SERVICE" redis-cli PING 2>/dev/null || true)"
        if [ "$REDIS_PING" = "PONG" ]; then
            pass "Redis responds to PING"
        else
            fail "Redis responds to PING" "${REDIS_PING:-no response}"
        fi

        REDIS_KEYS="$("${COMPOSE[@]}" exec -T "$REDIS_SERVICE" redis-cli DBSIZE 2>/dev/null | tr -d '\r' || true)"
        if [[ "$REDIS_KEYS" =~ ^[0-9]+$ ]]; then
            pass "Redis cache database is queryable" "$REDIS_KEYS cached keys"
        else
            fail "Redis cache database is queryable" "${REDIS_KEYS:-no response}"
        fi

        WP_REDIS_STATUS="$("${COMPOSE[@]}" exec -T wordpress wp redis status --allow-root --path=/var/www/html 2>/dev/null || true)"
        if printf '%s\n' "$WP_REDIS_STATUS" | grep -qiE 'status:[[:space:]]*connected'; then
            pass "WordPress is actively connected to Redis"
        else
            fail "WordPress is actively connected to Redis" "${WP_REDIS_STATUS:-wp redis status returned no output}"
        fi
    fi

    if [ -n "$STATIC_SERVICE" ] && [ -n "$DOMAIN_NAME" ]; then
        STATIC_BODY="$(curl -kfsSL --resolve "${DOMAIN_NAME}:443:127.0.0.1" "https://${DOMAIN_NAME}/static/" 2>/dev/null || true)"
        if printf '%s\n' "$STATIC_BODY" | grep -qiE '<!doctype html|<html'; then
            pass "Static website is reachable through NGINX over HTTPS"
        else
            fail "Static website is reachable through NGINX over HTTPS"
        fi
    fi

    if [ -n "$ADMINER_SERVICE" ] && [ -n "$DOMAIN_NAME" ]; then
        ADMINER_BODY="$(curl -kfsSL --resolve "adminer.${DOMAIN_NAME}:443:127.0.0.1" "https://adminer.${DOMAIN_NAME}/" 2>/dev/null || true)"
        if printf '%s\n' "$ADMINER_BODY" | grep -qi 'adminer'; then
            pass "Adminer is reachable through NGINX over HTTPS"
        else
            fail "Adminer is reachable through NGINX over HTTPS"
        fi

        if "${COMPOSE[@]}" exec -T "$ADMINER_SERVICE" php84 -r '$s=@fsockopen("mariadb",3306,$e,$m,3); exit($s ? 0 : 1);' >/dev/null 2>&1; then
            pass "Adminer container can reach MariaDB on the internal network"
        else
            fail "Adminer container can reach MariaDB on the internal network"
        fi
    fi

    if [ -n "$CUSTOM_SERVICE" ] && [ -n "$DOMAIN_NAME" ]; then
        case "$CUSTOM_SERVICE" in
            uptime_kuma)
                KUMA_CODE="$(curl -k -sS -o /dev/null -w '%{http_code}' --resolve "kuma.${DOMAIN_NAME}:443:127.0.0.1" "https://kuma.${DOMAIN_NAME}/" 2>/dev/null || true)"
                if [[ "$KUMA_CODE" =~ ^(200|301|302)$ ]]; then
                    pass "Uptime Kuma is reachable through NGINX over HTTPS" "HTTP $KUMA_CODE"
                else
                    fail "Uptime Kuma is reachable through NGINX over HTTPS" "HTTP ${KUMA_CODE:-000}"
                fi
                KUMA_MOUNTS="$(docker inspect --format '{{range .Mounts}}{{println .Name .Destination}}{{end}}' "$(container_id "$CUSTOM_SERVICE")" 2>/dev/null || true)"
                if printf '%s\n' "$KUMA_MOUNTS" | grep -q '/app/data'; then
                    pass "Uptime Kuma state is persisted in a named volume"
                else
                    fail "Uptime Kuma state is persisted in a named volume" "$KUMA_MOUNTS"
                fi
                ;;
            *)
                warn "No service-specific live probe for custom service '$CUSTOM_SERVICE'"
                ;;
        esac
    fi
fi

section "Manual defense checks that automation must not mutate"
warn "FTP upload/download and WordPress-volume write test require evaluator credentials" "Demonstrate interactively if FTP is implemented."
warn "Bonus is evaluated only when the mandatory part is perfect" "Resolve every mandatory failure before claiming bonus points."

echo -e "\n${BOLD}${CYAN}==============================================================================${RESET}"
echo -e "  Bonus checks: $TOTAL  Passed: ${GREEN}$PASSED${RESET}  Failed: ${RED}$FAILED${RESET}  Warnings: ${YELLOW}$WARNINGS${RESET}"
echo -e "${BOLD}${CYAN}==============================================================================${RESET}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All automated bonus requirements passed.${RESET}"
    exit 0
fi

echo -e "${RED}${BOLD}$FAILED bonus check(s) failed. Bonus compliance is incomplete.${RESET}"
exit 1
