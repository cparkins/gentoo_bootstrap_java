#!/bin/bash
while getopts "p:b:" OPTNAME; do
	case $OPTNAME in
		p)
			echo "Peer: ${OPTARG}"
			peer="${OPTARG}"
			;;
		b)
			echo "Bucket Name: ${OPTARG}"
			bucket_name="${OPTARG}"
			;;
	esac
done

if [ -z "${peer}" -o -z "${bucket_name}" ]; then
	echo "Usage: ${BASH_SOURCE[0]} -p peer_name:peer_ip -b bucket_name"
	exit 1
fi

ip="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
name="$(hostname)"
iam_role="$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)"
scripts="https://raw.githubusercontent.com/iVirus/gentoo_bootstrap_java/master/templates/hvm/scripts"

filename="usr/local/bin/encrypt_decrypt"
functions_file="$(mktemp)"
curl -sf -o "${functions_file}" "${scripts}/${filename}" || exit 1
source "${functions_file}"

filename="etc/hosts"
echo "--- ${filename} (append)"
cat <<EOF>>"/${filename}"

${peer#*:}	${peer%:*}.salesteamautomation.com ${peer%:*}
EOF

filename="var/lib/portage/world"
echo "--- ${filename} (append)"
cat <<'EOF'>>"/${filename}"
net-misc/rabbitmq-server
sys-fs/s3fs
EOF

dirname="etc/portage/package.keywords"
echo "--- ${dirname} (create)"
mkdir -p "/${dirname}"

filename="etc/portage/package.keywords/rabbitmq-server"
echo "--- ${filename} (replace)"
cat <<'EOF'>"/${filename}"
net-misc/rabbitmq-server
EOF

emerge -q --sync
emerge -uDN @system @world || exit 1

filename="etc/fstab"
echo "--- ${filename} (append)"
cat <<EOF>>"/${filename}"

s3fs#${bucket_name}	/mnt/s3		fuse	_netdev,allow_other,url=https://s3.amazonaws.com,iam_role=${iam_role}	0 0
EOF

dirname="mnt/s3"
echo "--- ${dirname} (mount)"
mkdir -p "/${dirname}"
mount "/${dirname}" || exit 1

filename="etc/rabbitmq/rabbitmq.config"
echo "--- ${filename} (replace)"
cat <<EOF>"/${filename}"
[
  {rabbit, [
    {cluster_nodes, {['rabbit@${name}', 'rabbit@${peer%:*}'], disc}},
    {loopback_users, []}
  ]}
].
EOF

user="rabbitmq"
app="erlang"
type="cookie"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

filename="var/lib/rabbitmq/.erlang.cookie"
echo "--- ${filename} (replace)"
cat <<EOF>"/${filename}"
${rabbitmq_erlang_cookie}
EOF
chmod 600 "/${filename}" || exit 1
chown rabbitmq: "/${filename}" || exit 1

/etc/init.d/rabbitmq start || exit 1

rc-update add rabbitmq default

rabbitmq-plugins enable rabbitmq_management rabbitmq_stomp || exit 1

curl -sf "http://10.12.16.10:8053?type=A&name=${name}&domain=salesteamautomation.com&address=${ip}" || curl -sf "http://10.12.32.10:8053?type=A&name=${name}&domain=salesteamautomation.com&address=${ip}" || exit 1
