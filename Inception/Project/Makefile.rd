CONTAINER = redis
STATUS_CMD = sh -c 'info=$$(redis-cli INFO); printf "%s\n" "$$info" | grep -E "^(redis_version|uptime_in_days|connected_clients|used_memory_human|used_memory_dataset|used_memory_dataset_perc|total_commands_processed|instantaneous_ops_per_sec|keyspace_hits|keyspace_misses|expired_keys|evicted_keys|rejected_connections):" | tr -d "\r"; hits=$$(printf "%s\n" "$$info" | sed -n "s/^keyspace_hits://p" | tr -d "\r"); misses=$$(printf "%s\n" "$$info" | sed -n "s/^keyspace_misses://p" | tr -d "\r"); total=$$((hits + misses)); if [ "$$total" -gt 0 ]; then rate=$$((10000 * hits / total)); printf "cache_hit_rate:%d.%02d%%\n" $$((rate / 100)) $$((rate % 100)); else printf "cache_hit_rate:n/a\n"; fi; printf "cached_keys:"; redis-cli DBSIZE'

include Makefile.cm

# Redis-specific cache checks
ping:
	$(COMPOSE) exec $(CONTAINER) redis-cli ping

info:
	$(COMPOSE) exec $(CONTAINER) redis-cli info memory stats

keys:
	$(COMPOSE) exec $(CONTAINER) redis-cli --scan


clients:
	$(COMPOSE) exec $(CONTAINER) redis-cli CLIENT LIST

slowlog:
	$(COMPOSE) exec $(CONTAINER) redis-cli SLOWLOG GET 10

stats: status

flushDANGEROUS:
	$(COMPOSE) exec $(CONTAINER) redis-cli FLUSHDB

.PHONY: ping info keys clients slowlog stats flushDANGEROUS
