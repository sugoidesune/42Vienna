#!/bin/sh
clear
d=$(mktemp -d)
curl -sSL https://github.com/sugoidesune/42Vienna/archive/refs/heads/master.tar.gz|tar -xz --strip-components=4 -C "$d" 42Vienna-master/IRC/DOCS/EXP
(cd "$d"&&./pp)
rm -rf "$d"
clear
