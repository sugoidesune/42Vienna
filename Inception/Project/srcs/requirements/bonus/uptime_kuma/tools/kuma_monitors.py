import os
import sys
import time
from uptime_kuma_api import UptimeKumaApi, MonitorType, Event

KUMA_URL = os.environ.get("KUMA_URL", "http://127.0.0.1:3001")
KUMA_USER = os.environ["KUMA_USER"]

with open("/run/secrets/kuma_password", "r") as f:
    KUMA_PASSWORD = f.read().strip()

monitors = [
    {
        "type": MonitorType.PORT,
        "name": "MariaDB Database",
        "hostname": "mariadb",
        "port": 3306,
        "interval": 60,
        "maxretries": 1,
    },
    {
        "type": MonitorType.PORT,
        "name": "WordPress PHP-FPM",
        "hostname": "wordpress",
        "port": 9876,
        "interval": 60,
        "maxretries": 1,
    },
    {
        "type": MonitorType.HTTP,
        "name": "Static Website Showcase",
        "url": "http://static_serv:3000",
        "interval": 60,
        "maxretries": 1,
    },
    {
        "type": MonitorType.PORT,
        "name": "NGINX Gateway",
        "hostname": "nginx",
        "port": 443,
        "interval": 60,
        "maxretries": 1,
    },
    {
        "type": MonitorType.PORT,
        "name": "Redis Cache",
        "hostname": "redis",
        "port": 6379,
        "interval": 60,
        "maxretries": 1,
    },
    {
        "type": MonitorType.HTTP,
        "name": "Adminer Database UI",
        "url": "http://adminer:8080",
        "interval": 60,
        "maxretries": 1,
    },
    {
        "type": MonitorType.PORT,
        "name": "FTP Server",
        "hostname": "ftp",
        "port": 21,
        "interval": 60,
        "maxretries": 1,
    },
]


def add_monitor_safe(api, **kwargs):
    data = api._build_monitor_data(**kwargs)
    if "conditions" not in data or data["conditions"] is None:
        data["conditions"] = []
    with api.wait_for_event(Event.MONITOR_LIST):
        return api._call("add", data)


def seed_monitors():
    with UptimeKumaApi(KUMA_URL) as api:
        if hasattr(api, "need_setup") and api.need_setup():
            api.setup(KUMA_USER, KUMA_PASSWORD)
            print(f"Initialized admin account: {KUMA_USER}")

        api.login(KUMA_USER, KUMA_PASSWORD)
        print(f"Logged in as: {KUMA_USER}")

        existing = api.get_monitors()
        existing_names = {m["name"] for m in existing}

        for monitor in monitors:
            if monitor["name"] in existing_names:
                print(f"Already exists: {monitor['name']}")
                continue

            result = add_monitor_safe(api, **monitor)
            print(
                f"Created {monitor['name']} "
                f"(ID: {result.get('monitorID')})"
            )


for attempt in range(1, 31):
    try:
        seed_monitors()
        print("Uptime Kuma monitors initialized successfully.")
        sys.exit(0)
    except Exception as error:
        if attempt == 30:
            print(f"Monitor initialization failed after 30 attempts: {error}", file=sys.stderr)
            sys.exit(1)
        time.sleep(2)
