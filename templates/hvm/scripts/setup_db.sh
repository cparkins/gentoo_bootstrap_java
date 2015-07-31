#!/bin/bash
scripts="https://raw.githubusercontent.com/iVirus/gentoo_bootstrap_java/master/templates/hvm/scripts"

while getopts "d:i:n:o:" OPTNAME; do
	case $OPTNAME in
		d)
			echo "Server ID: ${OPTARG}"
			server_id="${OPTARG}"
			;;
		i)
			echo "Peer IP: ${OPTARG}"
			master_ip="${OPTARG}"
			;;
		n)
			echo "Peer Name: ${OPTARG}"
			master_name="${OPTARG}"
			;;
		o)
			echo "Offset: ${OPTARG}"
			offset="${OPTARG}"
			;;
	esac
done

if [ -z "${master_ip}" -o -z "${master_name}" -o -z "${server_id}" -o -z "${offset}"]; then
	echo "Usage: $0 -n master_name -i master_ip -d server_id -o offset"
	exit 1
fi

filename="/etc/hosts"
echo "--- ${filename} (append)"
cat <<EOF>>"${filename}"

${master_ip}	${master_name}.salesteamautomation.com ${master_name}
EOF

filename="/var/lib/portage/world"
echo "--- ${filename} (append)"
cat <<'EOF'>>"${filename}"
dev-db/mysql
dev-db/mytop
dev-python/mysql-python
sys-apps/pv
sys-fs/lvm2
sys-fs/s3fs
EOF

filename="/etc/portage/package.use/lvm2"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"
sys-fs/lvm2 -thin
EOF

filename="/etc/portage/package.use/mysql"
echo "--- ${filename} (modify)"
sed -i -r \
-e "s|minimal|extraengine profiling|" \
"${filename}" || exit 1

emerge -uDN @world || exit 1

filename="/tmp/my.cnf.insert.1"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"

des-key-file			= /etc/mysql/sta.key
thread_cache_size		= 64
query_cache_size		= 128M
query_cache_limit		= 32M
tmp_table_size			= 128M
max_heap_table_size		= 128M
max_connections			= 650
max_user_connections		= 600
skip-name-resolve
open_files_limit		= 65536
myisam_repair_threads		= 2
table_definition_cache		= 4096
EOF

filename="/tmp/my.cnf.insert.2"
echo "--- ${filename} (replace)"
cat <<EOF>"${filename}"

expire_logs_days		= 2
slow_query_log
relay-log			= /var/log/mysql/binary/mysqld-relay-bin
log_slave_updates
auto_increment_increment	= 2
auto_increment_offset		= ${offset}
EOF

filename="/tmp/my.cnf.insert.3"
echo "--- ${filename} (replace)"
cat <<EOF>"${filename}"

innodb_flush_method		= O_DIRECT
innodb_thread_concurrency	= 48
innodb_concurrency_tickets	= 5000
innodb_io_capacity		= 1000
EOF

filename="/etc/mysql/my.cnf"
echo "--- ${filename} (modify)"
cp "${filename}" "${filename}.orig"
sed -i -r \
-e "s|^(key_buffer_size\s+=\s+).*|\124576M|" \
-e "s|^(max_allowed_packet\s+=\s+).*|\116M|" \
-e "s|^(table_open_cache\s+=\s+).*|\116384|" \
-e "s|^(sort_buffer_size\s+=\s+).*|\12M|" \
-e "s|^(read_buffer_size\s+=\s+).*|\1128K|" \
-e "s|^(read_rnd_buffer_size\s+=\s+).*|\1128K|" \
-e "s|^(myisam_sort_buffer_size\s+=\s+).*|\164M|" \
-e "\|^lc_messages\s+=\s+|r /tmp/my.cnf.insert.1" \
-e "s|^(bind-address\s+=\s+.*)|#\1|" \
-e "s|^(log-bin)|\1\t\t\t\t= /var/log/mysql/binary/mysqld-bin|" \
-e "s|^(server-id\s+=\s+).*|\1${id}|" \
-e "\|^server-id\s+=\s+|r /tmp/my.cnf.insert.2" \
-e "s|^(innodb_buffer_pool_size\s+=\s+).*|\132768M|" \
-e "s|^(innodb_data_file_path\s+=\s+.*)|#\1|" \
-e "s|^(innodb_log_file_size\s+=\s+).*|\11024M|" \
-e "s|^(innodb_flush_log_at_trx_commit\s+=\s+).*|\12|" \
-e "\|^innodb_file_per_table|r /tmp/my.cnf.insert.3" \
"${filename}" || exit 1

filename="/etc/mysql/sta.key"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"
0 
1 
2 
3 
4 
5 
6 
7 
8 
9 
EOF
chmod 600 "${filename}"
chown mysql: "${filename}"

dirname="/var/log/mysql/binary"
echo "--- ${dirname} (create)"
mkdir -p "${dirname}"
chmod 700 "${dirname}"
chown mysql: "${dirname}"

filename="/usr/lib64/mysql/plugin/libmysql_strip_phone.so"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

filename="/usr/lib64/mysql/plugin/libmysql_format_phone.so"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

yes "" | emerge --config dev-db/mysql || exit 1

pvcreate /dev/xvd[fg] || exit 1
vgcreate vg0 /dev/xvd[fg] || exit 1
lvcreate -l 100%VG -n lvol0 vg0 || exit 1
mkfs.ext4 /dev/vg0/lvol0 || exit 1

filename="/etc/fstab"
echo "--- ${filename} (append)"
cat <<'EOF'>>"${filename}"

/dev/vg0/lvol0		/var/lib/mysql	ext4		noatime		0 0
EOF

dirname="/var/lib/mysql"
echo "--- ${dirname} (mount)"
mv "${dirname}" "${dirname}.bak" || exit 1
mkdir -p "${dirname}"
mount "${dirname}" || exit 1
rsync -a "${dirname}.bak/" "${dirname}/" || exit 1

/etc/init.d/mysql start || exit 1

rc-update add mysql default

mysql_secure_installation <<'EOF'

n
y
y
n
y
EOF

filename="/etc/mysql/configure_as_slave.sql"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1
sed -i -r \
-e "s|%MASTER_HOST%|${master_name}|" \
"${filename}" || exit 1

#
# TODO: Replace %BMOORMAN_PASSWORD%, %CPLUMMER_PASSWORD%, %REPLICATION_PASSWORD%, %MONITORING_PASSWORD%, %MYTOP_PASSWORD%, %MASTER_PASSWORD%
#

mysql < "${filename}" || exit 1

filename="/etc/skel/.mytop"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

#
# TODO: Replace %MYTOP_PASSWORD%
#

filename="/tmp/nrpe.cfg.insert"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"

command[check_mysql_disk]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p /var/lib/mysql
command[check_mysql_connections]=/usr/lib64/nagios/plugins/custom/check_mysql_connections
command[check_mysql_slave]=/usr/lib64/nagios/plugins/custom/check_mysql_slave
EOF

filename="/etc/nagios/nrpe.cfg"
echo "--- ${filename} (modify)"
cp "${filename}" "${filename}.orig"
sed -i -r \
-e "\|^command\[check_total_procs\]|r /tmp/nrpe.cfg.insert" \
"${filename}" || exit 1

dirname="/usr/lib64/nagios/plugins/custom/include"
echo "--- ${dirname} (create)"
mkdir -p "${dirname}"

filename="/usr/lib64/nagios/plugins/custom/check_mysql_connections"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1
chmod 755 "${filename}"

filename="/usr/lib64/nagios/plugins/custom/check_mysql_slave"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1
chmod 755 "${filename}"

filename="/usr/lib64/nagios/plugins/custom/include/settings.inc"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

#
# TODO: Replace %MONITORING_PASSWORD%
#

dirname="/usr/local/lib64/mysql/include"
echo "--- ${dirname} (create)"
mkdir -p "${dirname}"

filename="/usr/local/lib64/mysql/watch_mysql_connections.php"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1
chmod 755 "${filename}"

filename="/usr/local/lib64/mysql/watch_mysql_slave.php"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1
chmod 755 "${filename}"

filename="/usr/local/lib64/mysql/include/settings.inc"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

#
# TODO: Replace %MONITORING_PASSWORD%
#
