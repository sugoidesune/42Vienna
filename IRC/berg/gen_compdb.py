import json
import os

files = [
    "main.cpp",
    "Channel/Channel.cpp",
    "Client/Client.cpp",
    "Errorhandler/Errorhandler.cpp",
    "Server/Server.cpp",
    "Server/ServerSocket.cpp",
    "Server/ServerLoop.cpp",
    "Server/ServerCommands.cpp",
    "Server/ServerChannelOps.cpp",
    "Server/ServerMessaging.cpp",
    "Server/ServerHelper.cpp"
]

cwd = "/home/tbatis/core/berg"
compdb = []

for f in files:
    compdb.append({
        "directory": cwd,
        "command": f"c++ -g -Wall -Wextra -Werror -std=c++98 -fPIE -I. -c {f}",
        "file": os.path.join(cwd, f)
    })

with open(os.path.join(cwd, "compile_commands.json"), "w") as out:
    json.dump(compdb, out, indent=2)

print("Generated compile_commands.json successfully.")
