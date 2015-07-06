#!/usr/bin/env bash

# OpenVPN protocol (tcp or udp)
SERVER_PROTO="tcp"

# OpenVPN port (8080, 443, etc.)
SERVER_PORT="443"

# OpenVPN server address (will ask if empty)
REMOTE_HOST="10.60.0.4"

# Common "name" for client certificates
# For example, generated certs will be named this way:
# client1, client2, etc.
CLIENT_COMMON="grp1_"

LOGDIR=/var/log


###############################################################
# END OF USER-ADJUSTABLE SETTINGS
###############################################################

# Define variables 
EASY_RSA="`pwd`/easy-rsa"
SERVER_COMMON="server"
SERVER_DIR="server"
CLIENT_DIR=$CLIENT_COMMON
export OPENSSL="openssl"
export KEY_CONFIG="$EASY_RSA/openssl.cnf"
export KEY_DIR="`pwd`/keys"
# Define CRT Parameters
export KEY_SIZE=1024
export CA_EXPIRE=3650
export KEY_EXPIRE=3650
export KEY_COUNTRY="NL"
export KEY_PROVINCE="N/A"
export KEY_CITY="N/A"
export KEY_ORG="MY_COMPANY"
export KEY_EMAIL="admin@example.com"

echo "##########"
$OPENSSL version
echo "##########"

### define helper functions
# generate client and os folders
function dir_gen() {
        mkdir -p "${CLIENT_DIR}${COUNT}"
}

# pack each set
function pack_client() {
        cd "${CLIENT_DIR}${COUNT}/"
        tar -czf "${CLIENT_DIR}${COUNT}.tar.gz" ./*
        cd ../
        mv "${CLIENT_DIR}${COUNT}/${CLIENT_DIR}${COUNT}.tar.gz" .
}

# generate client config
function ovpn_conf_gen() {
echo "client
dev tun
proto $SERVER_PROTO
remote $REMOTE_HOST $SERVER_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
ca $CLIENT_COMMON$COUNT.ca.crt
cert $CLIENT_COMMON$COUNT.crt
key $CLIENT_COMMON$COUNT.key
comp-lzo yes
verb 3
" > ${CLIENT_DIR}${COUNT}/$CLIENT_COMMON$COUNT.ovpn
}

# generate server config
function server_conf_gen() {
echo "local $REMOTE_HOST
port $SERVER_PORT
proto $SERVER_PROTO
dev tun
ca ${SERVER_COMMON}.ca.crt
cert ${SERVER_COMMON}.crt
key ${SERVER_COMMON}.key  # This file should be kept secret
dh ${SERVER_COMMON}.dh${KEY_SIZE}.pem
#crl-verify crl.pem
server 10.8.0.0 255.255.255.0
push \"redirect-gateway\"
push \"dhcp-option DNS 10.8.0.1\"
push \"dhcp-option DNS 78.140.179.9\"
push \"dhcp-option DNS 78.140.128.205\"
duplicate-cn
keepalive 10 120
max-clients 20
user ${DAEMON_USER-'root'}
group ${DAEMON_GROUP-'nogroup'}
persist-key
persist-tun
status $LOGDIR/openvpn-${CLIENT_COMMON}-status.log
log-append $LOGDIR/openvpn-${CLIENT_COMMON}.log
verb 4
mute 20
comp-lzo
sndbuf 131072
rcvbuf 131072
" > ${SERVER_DIR}/server_${SERVER_COMMON}.conf
}

# build crt & key
function crt_key_gen() {   
        "$EASY_RSA/pkitool" $* ${CLIENT_COMMON}${COUNT}
        cp "${KEY_DIR}/${CLIENT_COMMON}${COUNT}.crt" "${CLIENT_DIR}${COUNT}/"
        cp "${KEY_DIR}/${CLIENT_COMMON}${COUNT}.key" "${CLIENT_DIR}${COUNT}/"
}

### define main functions
# create new certs and configs
function main_create_certs() {

echo 'How many client certificates you need to create?'
echo 'Enter desired total number:'
read CERTS
if [ -z "$REMOTE_HOST" ]; then
    echo 'Specify Openvpn server IP:'
    read REMOTE_HOST
fi

#checking certs number
if [[ ${CERTS} =~ ^[0-9]+$ ]]
then
if [ "$KEY_DIR" ]; then
    mkdir -p "$KEY_DIR"
    chmod go-rwx "$KEY_DIR"
    touch "$KEY_DIR/index.txt"
    echo 01 > "$KEY_DIR/serial"
fi
#build CA
"${EASY_RSA}/pkitool" --initca $*
#Build server crt/key
"$EASY_RSA/pkitool" --server $* ${SERVER_COMMON}
#work
COUNT=0
while [ ${COUNT} -ne ${CERTS} ]
do COUNT=$(expr ${COUNT} + 1)
	echo "dir_gen"
        dir_gen
        echo "crt_key_gen"
        crt_key_gen
        echo "ovpn_conf_gen"
        ovpn_conf_gen
done
echo "Build Diffie Hellman parameters"
if [ -d "$KEY_DIR" ] && [ $KEY_SIZE ]; then
    openssl dhparam -out "${KEY_DIR}/dh${KEY_SIZE}.pem" ${KEY_SIZE}
fi
# compile together server keys & config file"
mkdir -p "${SERVER_DIR}"
# CA"
cp "${KEY_DIR}/ca.crt" "${SERVER_DIR}/${SERVER_COMMON}.ca.crt"
# Server cert"
mv "${KEY_DIR}/${SERVER_COMMON}.crt" "${SERVER_DIR}"
# Server key"
mv "${KEY_DIR}/${SERVER_COMMON}.key" "${SERVER_DIR}"
# DH"
mv "${KEY_DIR}/dh${KEY_SIZE}.pem" "${SERVER_DIR}/${SERVER_COMMON}.dh${KEY_SIZE}.pem"
# put server config to 'server.conf'"
server_conf_gen

# create client keys
COUNT=0
while [ ${COUNT} -ne ${CERTS} ]
do COUNT=$(expr ${COUNT} + 1)
        cp "${KEY_DIR}/ca.crt" "${CLIENT_DIR}${COUNT}/${CLIENT_DIR}${COUNT}.ca.crt"
        echo ${COUNT} > "${CLIENT_DIR}${COUNT}/serial"
        pack_client
done
else
    echo 
    echo 'Numbers of certificates should be numeric!'
exit
fi
}

# add certs to existing setup
function main_add_certs() {
INDEX=$(cat keys/index.txt|wc -l)
echo 'You have '$(expr $INDEX - 1)' certificates.
So you should start from number'$INDEX', apparently'
echo 'Enter starting number:'
read CERTS_BEG
echo 'Enter ending number:'
read CERTS_END
if [ -z $REMOTE_HOST ]; then
    echo 'Specify Openvpn server IP:'
    read REMOTE_HOST
fi

# checking certs number
if [[ ${CERTS_BEG} =~ ^[0-9]+$ ]]
then

# Generate requested additional certs
COUNT=$(expr $CERTS_BEG - 1)
while [ ${COUNT} -ne ${CERTS_END} ]
do COUNT=$(expr ${COUNT} + 1)  
        dir_gen
        crt_key_gen
        ovpn_conf_gen
done

# create packed archives of client configs + keys
COUNT=$(expr $CERTS_BEG - 1)
while [ ${COUNT} -ne ${CERTS_END} ]
    do COUNT=$(expr ${COUNT} + 1)
	echo "Packing for "$COUNT
	        cp "${KEY_DIR}/ca.crt" "${CLIENT_DIR}${COUNT}/"
	        echo ${COUNT} > "${CLIENT_DIR}${COUNT}/serial"
	        pack_client
    done
else
    echo
    echo 'Numbers of certificates should be numeric!'
exit

fi
}

# revoke a certificate
function main_revoke_cert() {
echo 'Please copy the .crt and .key files of required client to ./keys folder first!'
echo 'Please enter client certificate name to deny access:'
read CLIENT_ID

"$EASY_RSA/revoke-full" $CLIENT_ID
echo "
## if you see \"error 23\" - this is OK! It means all went well, and cert is revoked.

if all went well, please do not forget to copy file \"$KEY_DIR/crl.pem\" to OpenVPN server dir and add line
crl-verify crl.pem
to server config file (if not already there)."
}

# backup existing certs and configs
# and clean the folder
function clean_files() {
    BKP_FILE="ovpn_keys.tar.gz"
    tar --remove-files -czpf $BKP_FILE server keys $CLIENT_COMMON* && echo "Current keys and configs archived to $BKP_FILE. Original files have been removed."
}

# help
function show_help() {
    echo "Usage : $0   new | create | add | revoke | clean"
    exit
}

###############################################################
# main logic
case "$1" in
    "new" | "create" )
	clean
	main_create_certs
	;;
    "add" )
	main_add_certs
	;;
    "revoke" )
	main_revoke_cert
	;;
    "clean" )
	clean_files
	;;
    "-h" | "help" )
	show_help
	;;
    * )
	echo 'Please enter correct command.'
	show_help
	exit 0
	;;
esac
