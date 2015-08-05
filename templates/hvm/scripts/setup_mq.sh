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

if [ -z "${peer}" ]; then
	echo "Usage: ${BASH_SOURCE[0]} -p peer_name:peer_ip -b bucket_name"
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

${peer#*:}	${peer%:*}.salesteamautomation.com ${peer%:*}
EOF

filename="/var/lib/portage/world"
echo "--- ${filename} (append)"
cat <<'EOF'>>"${filename}"
net-misc/rabbitmq-server
EOF

dirname="/etc/portage/package.keywords"
echo "--- $dirname (create)"
mkdir -p "${dirname}"

filename="/etc/portage/package.keywords/rabbitmq-server"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"
net-misc/rabbitmq-server
EOF

emerge -uDN @system @world || exit 1

rabbitmq-plugins enable rabbitmq_management rabbitmq_stomp || exit 1

filename="/etc/rabbitmq/rabbitmq.config"
echo "--- ${filename} (replace)"
cat <<'EOF'>"${filename}"
[{rabbit, [{loopback_users, []}]}].
EOF

user="rabbitmq"
app="erlang"
type="cookie"
echo "-- ${user} ${app}_${type} (decrypt)"
declare "${user}_${app}_${type}=$(decrypt_user_text "${app}_${type}" "${user}")"

filename="/var/lib/rabbitmq/.erlang.cookie"
echo "--- ${filename} (replace)"
cat <<EOF>"${filename}"
${rabbitmq_erlang_cookie}
EOF

/etc/init.d/rabbitmq start || exit 1

rc-update add rabbitmq default

counter=0
sleep=30
timeout=1800

echo -n "Sleeping..."
sleep $(bc <<< "${RANDOM} % 30")
echo "done! :)"

echo -n "Waiting for ${peer%:*}..."

while true; do
	rabbitmqctl stop_app &> /dev/null || exit 1

	if rabbitmqctl join_cluster rabbit@${peer%:*} &> /dev/null; then
		rabbitmqctl start_app &> /dev/null || exit 1
		break
	else [ "${counter}" -ge "${timeout}" ]; then
		echo "failed! :("
		exit 1
	fi

	rabbitmqctl start_app &> /dev/null || exit 1

	echo -n "."
	sleep ${sleep}
	counter=$(bc <<< "${counter} + ${sleep}")
done

echo "connected! :)"

echo -n "Sleeping..."
sleep $(bc <<< "${RANDOM} % 30")
echo "done! :)"
