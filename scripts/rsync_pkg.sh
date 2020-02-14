#!/bin/sh
#rsync -vaz --delete rsync://openbsd.mirror.frontiernet.net/OpenBSD/5.4/packages/i386/ /data/pkg/
rsync -va --delete rsync://ftp.jaist.ac.jp/pub/OpenBSD/`uname -r`/packages/`machine -a`/ /data/pkg/
