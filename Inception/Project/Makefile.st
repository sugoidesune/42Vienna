CONTAINER = static_serv
STATUS_CMD = sh -c 'wget -q -O /dev/null http://127.0.0.1:3000/ && echo "http_status: 200"'

include Makefile.cm

# static_serv-specific commands
html:
	$(COMPOSE) exec $(CONTAINER) cat /var/www/static/index.html

conf:
	$(COMPOSE) exec $(CONTAINER) cat /busybox/.config

bin:
	$(COMPOSE) exec $(CONTAINER) ls -la /busybox/_install/sbin /busybox/_install/bin


probe:
	$(COMPOSE) exec $(CONTAINER) wget -S -O /dev/null http://127.0.0.1:3000/
pinglocal:
	curl -k -I https://localhost/static/

pingweb:
	domain=$$(grep -E '^DOMAIN_NAME=' srcs/.env 2>/dev/null | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r'); \
	curl -k -I "https://$$domain/static/"

.PHONY: html conf bin probe pinglocal pingweb
