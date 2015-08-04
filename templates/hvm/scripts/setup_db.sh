#!/bin/bash
while getopts "m:i:o:b:" OPTNAME; do
	case $OPTNAME in
		m)
			echo "Master: ${OPTARG}"
			master="${OPTARG}"
			;;
		i)
			echo "Server ID: ${OPTARG}"
			server_id="${OPTARG}"
			;;
		o)
			echo "Offset: ${OPTARG}"
			offset="${OPTARG}"
			;;
		b)
			echo "Bucket Name: ${OPTARG}"
			bucket_name="${OPTARG}"
			;;
	esac
done

if [ -z "${master}" -o -z "${server_id}" -o -z "${offset}" ]; then
	echo "Usage: ${BASH_SOURCE[0]} -m master_name:master_ip -i server_id -o offset"
	exit 1
fi

scripts="https://raw.githubusercontent.com/iVirus/gentoo_bootstrap_java/master/templates/hvm/scripts"

filename="/tmp/encrypt_decrypt_text"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1
source "${filename}"

filename="/etc/hosts"
echo "--- ${filename} (append)"
cat <<EOF>>"${filename}"

${master#*:}	${master%:*}.salesteamautomation.com ${master%:*}
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

emerge -uDN @system @world || exit 1

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
sql-mode			= NO_AUTO_CREATE_USER
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
-e "s|^(server-id\s+=\s+).*|\1${server_id}|" \
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

filename="/tmp/configure_as_slave.sql"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

user="bmoorman"
app="mysql"
type="hash"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="cplummer"
app="mysql"
type="hash"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="ecall"
app="mysql"
type="hash"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="jstubbs"
app="mysql"
type="hash"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="tpurdy"
app="mysql"
type="hash"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="npeterson"
app="mysql"
type="hash"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="replication"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="monitoring"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="mytop"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

user="master"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

filename="/tmp/configure_as_slave.sql"
echo "--- ${filename} (modify)"
sed -i -r \
-e "s|%BMOORMAN_HASH%|${bmoorman_mysql_hash}|" \
-e "s|%CPLUMMER_HASH%|${cplummer_mysql_hash}|" \
-e "s|%ECALL_HASH%|${ecall_mysql_hash}|" \
-e "s|%JSTUBBS_HASH%|${jstubbs_mysql_hash}|" \
-e "s|%TPURDY_HASH%|${tpurdy_mysql_hash}|" \
-e "s|%NPETERSON_HASH%|${npeterson_mysql_hash}|" \
-e "s|%REPLICATION_AUTH%|${replication_mysql_auth}|" \
-e "s|%MONITORING_AUTH%|${monitoring_mysql_auth}|" \
-e "s|%MYTOP_AUTH%|${mytop_mysql_auth}|" \
-e "s|%MASTER_HOST%|${master%:*}|" \
-e "s|%MASTER_AUTH%|${master_mysql_auth}|" \
"${filename}" || exit 1

filename="/tmp/configure_as_slave.sql"
echo "--- ${filename} (run)"
mysql < "${filename}" || exit 1

filename="/etc/skel/.mytop"
echo "--- ${filename} (replace)"
curl -sf -o "${filename}" "${scripts}${filename}" || exit 1

user="mytop"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

filename="/etc/skel/.mytop"
echo "--- ${filename} (modify)"
sed -i -r \
-e "s|%MYTOP_AUTH%|${mytop_mysql_auth}|" \
"${filename}" || exit 1

filename="/tmp/nrpe.cfg.insert"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"

command[check_mysql_disk]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p /var/lib/mysql
command[check_mysql_connections]=/usr/lib64/nagios/plugins/custom/check_mysql_connections
command[check_mysql_slave]=/usr/lib64/nagios/plugins/custom/check_mysql_slave
EOF

filename="/etc/nagios/nrpe.cfg"
echo "--- ${filename} (modify)"
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

user="monitoring"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

filename="/usr/lib64/nagios/plugins/custom/include/settings.inc"
echo "--- ${filename} (modify)"
sed -i -r \
-e "s|%MONITORING_AUTH%|${monitoring_mysql_auth}|" \
"${filename}" || exit 1

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

user="monitoring"
app="mysql"
type="auth"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

filename="/usr/local/lib64/mysql/include/settings.inc"
echo "--- ${filename} (modify)"
sed -i -r \
-e "s|%MONITORING_AUTH%|${monitoring_mysql_auth}|" \
"${filename}" || exit 1
