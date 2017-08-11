#!/bin/bash
#
# Container entrypoint: bring up the Searchdaimon appliance WITHOUT systemd.
#
# CentOS 7's systemd (v219) only supports cgroup v1, so `/usr/sbin/init` will not
# boot on a cgroup-v2 host (Docker Desktop, modern Linux). This script starts the
# same services systemd would, in the same order, so the image runs anywhere. It
# reuses the appliance's own init.d scripts to launch (and everrun-supervise) the
# daemons; only the orchestration differs.
#
# (A real cgroup-v1 host can still run the systemd path instead — see the
#  commented `/usr/sbin/init` CMD in the Dockerfile.)

export BOITHOHOME=/home/boitho/boithoTools
log() { echo "[entrypoint] $*"; }

log "starting MariaDB"
if [ ! -d /var/lib/mysql/mysql ]; then
	mysql_install_db --user=mysql >/dev/null 2>&1
fi
mkdir -p /var/run/mariadb && chown mysql:mysql /var/run/mariadb
mysqld_safe >/var/log/mariadb/mariadb-safe.log 2>&1 &
for i in $(seq 1 60); do
	mysqladmin ping --silent 2>/dev/null && break
	sleep 1
done
log "MariaDB: $(mysqladmin ping 2>&1 | head -1)"

log "starting rpcbind (required by suggest_server's SunRPC registration)"
/sbin/rpcbind 2>/dev/null || rpcbind 2>/dev/null || true

log "seeding database (blackbox/boithodbsetup)"
sh "$BOITHOHOME/blackbox/boithodbsetup" || true

log "starting httpd"
# Route Apache's logs to files (the appliance vhost logs to syslog:local6, which
# is lost in a container without rsyslog) so they can be streamed to stdout
# below. This rewrites only the in-container config copy; the image/source vhost
# is unchanged.
sed -ri 's#^[[:space:]]*ErrorLog .*#ErrorLog /var/log/httpd/error_log#; s#^[[:space:]]*CustomLog .*#CustomLog /var/log/httpd/access_log common#' \
	/etc/httpd/conf.d/bbdemo.boitho.com.conf
# httpd needs its runtime dir for the pid/lock; with no systemd-tmpfiles here it
# is not created automatically, and httpd then fails to start. (Don't hide the
# error — let it surface in the streamed logs.)
mkdir -p /run/httpd
/usr/sbin/httpd -k start || log "WARNING: httpd failed to start"

log "starting Searchdaimon daemons"
for s in boithoad boitho-bbdn searchdbb crawlManager suggest crawl_watch; do
	"$BOITHOHOME/init.d/$s" start || true
done

log "startup complete; streaming logs to stdout (docker logs / CloudWatch)."
# Stream the key logs to PID 1's stdout so they appear in `docker logs` and on
# any platform that captures container stdout (AWS ECS awslogs -> CloudWatch,
# Kubernetes, etc.) — no files to scrape. -F retries files not present yet;
# daemon logs land under $BOITHOHOME/logs and $BOITHOHOME/var.
touch /var/log/httpd/error_log /var/log/httpd/access_log
LOGS="/var/log/httpd/error_log /var/log/httpd/access_log /var/log/mariadb/mariadb.log"
for f in "$BOITHOHOME"/logs/*.log "$BOITHOHOME"/var/*.log; do [ -f "$f" ] && LOGS="$LOGS $f"; done
exec tail -n0 -F $LOGS 2>/dev/null
