# Check how compose file gets parsed and how it looks
docker compose -f inception/srcs/docker-compose.yml config


# Build Maria DB
docker compose -f srcs/docker-compose.yml build mariadb

# Start maria DB
docker compose -f srcs/docker-compose.yml up -d mariadb
// -d detatch - dont occupy termianl

# Logs Maria DB
docker compose -f srcs/docker-compose.yml logs mariadb

# Execute command inside
docker compose -f srcs/docker-compose.yml exec mariadb     ls -la /run/mysqld