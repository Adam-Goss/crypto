#!/bin/false
# The script has been set not to execute directly.
# create / use x509 directory and certificate structure as follows:
#
#  x509
#   |
#   +--create-x509.sh (this script)
#   |
#   +--ca
#   |   |
#   |   +--root
#   |   |   |
#   |   |   +--openssl.cnf (config for a root ca)
#   |   |   |
#   |   |   \--(various dirs, certs and keys)
#   |   |
#   |   +--webserver_ca
#   |   |   |
#   |   |   +--openssl.cnf (config for a tls ca)
#   |   |   |
#   |   |   \--(various dirs, certs and keys)
#   |   |
#   |	\--vpn_ca
#   |   	|
#   |   	+--openssl.cnf (config for a vpn ca)
#   |   	|
#   |   	\--(various certs and keys)
#   |	
#   |
#   +-- vpn1.u2086937.cyber2020.test
#   |   |
#   |   +--openssl.cnf (config for a server)
#   |   |
#   |   \--(various certs and keys)
#   |
#   +-- remote1
#   |   |
#   |   +--openssl.cnf (config for a client)
#   |   |
#   |   \--(various certs and keys)
#   |
#   +-- remote2
#   |   |
#   |   +--openssl.cnf (config for a client)
#   |   |
#   |   \--(various certs and keys)
#   |
#   +-- remote3
#   |   |
#   |   +--openssl.cnf (config for a client)
#   |   |
#   |   \--(various certs and keys)
#   |
#   \--webserver1
#       |
#       +--openssl.cnf (config for a server)
#       |
#       \--(various certs and keys)





# 
# prep the top level dirs
# mkdir x509
# cd x509
X509DIR=$PWD

# to store PEM chains of certificates in
#mkdir chains

# use SHA-256 - SHA-1 broken

# --------------------------------------------- #
# ------------------ ROOT CA ------------------ #
# --------------------------------------------- #
# prep the ca dirs
mkdir -p ./ca/root
cd ./ca/root/

mkdir certs crl newcerts private unsigned signed
chmod 700 private
touch index.txt
echo 1000 > serial

# create the root ca key "ca_secret"
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

# create the root cert
openssl req -config ./openssl.conf \
      -key private/ca.key \
      -new -x509 \
      -days 7300 \
      -sha256 \
      -extensions v3_ca \
      -out certs/ca.cert.pem

# verify the root cert
openssl x509 -noout -text -in certs/ca.cert.pem

######## create root CA CRL ################
# create a Certificate Revocation Lists (CRL)
# in case end entity certificates have to be revoked
echo 1000 > ./crlnumber

cd ${X509DIR}/ca/root/
openssl ca -config openssl.conf \
      -gencrl -out ./crl/root.crl.pem
      
# check it worked 
openssl crl -in ./crl/vpn_ca.crl.pem -noout -text
# --------------------------------------------- #


# --------------------------------------------- #
# ------------------ VPN CA ------------------- #
# --------------------------------------------- #
# prep the vpn ca dirs
cd $X509DIR
mkdir -p ./ca/vpn_ca
cd ./ca/vpn_ca/

mkdir certs crl newcerts private csr signed unsigned
chmod 700 private
touch index.txt
echo 1000 > serial

echo 1000 > ./crlnumber

# create the vpn CA key "vpn_secret"
openssl genrsa -aes256 -out private/vpn_ca.key.pem 4096
chmod 400 private/vpn_ca.key.pem

# create the vpn cert
openssl req -config ./openssl.conf \
      -new -sha256 \
      -key private/vpn_ca.key.pem \
      -out csr/vpn_ca.csr.pem

########## ROOT CA SIGNS VPN CA ##############
# send the vpn cert csr to the root ca
cd ${X509DIR}
cp ./ca/vpn_ca/csr/vpn_ca.csr.pem ./ca/root/unsigned/

# get the vpn cert signed by the root cert
cd ./ca/root/
openssl ca -config ./openssl.conf \
      -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in unsigned/vpn_ca.csr.pem \
      -out signed/vpn_ca.cert.pem
      
# verify the vpn cert
openssl x509 -noout -text -in signed/vpn_ca.cert.pem
      
# verify against root cert      
openssl verify -CAfile certs/ca.cert.pem \
      signed/vpn_ca.cert.pem
      
# return it to the vpn ca
cd ${X509DIR}
cp ./ca/root/signed/vpn_ca.cert.pem ./ca/vpn_ca/certs/
chmod 444 ./ca/vpn_ca/certs/vpn_ca.cert.pem


######## create vpn CA CRL ################
# create a Certificate Revocation Lists (CRL)
# in case end entity certificates have to be revoked
cd ${X509DIR}/ca/vpn_ca/
openssl ca -config openssl.conf \
      -gencrl -out ./crl/vpn_ca.crl.pem
      
# check it worked 
openssl crl -in ./crl/vpn_ca.crl.pem -noout -text
# --------------------------------------------- #


# --------------------------------------------- #
# --- VPN 1 - vpn1.u2086937.cyber2020.test ---- #
# --------------------------------------------- #
# prep the vpn1 dirs
cd ${X509DIR}
mkdir vpn1.u2086937.cyber2020.test
cd vpn1.u2086937.cyber2020.test

# generate the vpn1 key (no aes256 this time to permit server unattended restart)
openssl genrsa -out vpn1.u2086937.cyber2020.test.key.pem 4096
chmod 400 vpn1.u2086937.cyber2020.test.key.pem

# generate the vpn1 cert
openssl req -config ./openssl.conf \
      -key vpn1.u2086937.cyber2020.test.key.pem \
      -new -sha256 \
      -out vpn1.u2086937.cyber2020.test.csr.pem

######### VPN CA SIGNS VPN 1 CSR #################
# send the vpn1 cert csr to the vpn ca
cd ${X509DIR}
cp ./vpn1.u2086937.cyber2020.test/vpn1.u2086937.cyber2020.test.csr.pem ./ca/vpn_ca/unsigned/

# get the vpn1 cert signed by the ca_vpn cert
cd ./ca/vpn_ca/
openssl ca -config ./openssl.conf \
      -extensions vpn1_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/vpn1.u2086937.cyber2020.test.csr.pem \
      -out signed/vpn1.u2086937.cyber2020.test.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/vpn1.u2086937.cyber2020.test.cert.pem

# return it to the vpn1
cd ${X509DIR}
cp ./ca/vpn_ca/signed/vpn1.u2086937.cyber2020.test.cert.pem ./vpn1.u2086937.cyber2020.test/  
chmod 444 ./vpn1.u2086937.cyber2020.test/vpn1.u2086937.cyber2020.test.cert.pem

### MOVE TO VPN ENDPOINT
# --------------------------------------------- #


# --------------------------------------------- #
# ---------- remote client - remote1 ---------- #
# --------------------------------------------- #
# prep remote1 dirs
cd ${X509DIR}
mkdir remote1
cd remote1

# generate the remote1 key
openssl genrsa -out remote1.key.pem 4096
chmod 400 remote1.key.pem

# generate the remote1 cert
openssl req -config ./openssl.conf \
      -key remote1.key.pem \
      -new -sha256 \
      -out remote1.csr.pem

######### VPN CA SIGNS remote1 CSR #################
# send the remote1 cert csr to the vpn ca
cd ${X509DIR}
cp ./remote1/remote1.csr.pem ./ca/vpn_ca/unsigned/

# get the remote1 cert signed by the vpn_ca cert
cd ./ca/vpn_ca/
openssl ca -config ./openssl.conf \
      -extensions remote1_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/remote1.csr.pem  \
      -out signed/remote1.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/remote1.cert.pem

# return it to the remote1
cd ${X509DIR}
cp ./ca/vpn_ca/signed/remote1.cert.pem ./remote1/  
chmod 444 ./remote1/remote1.cert.pem

### MOVE TO VPN ENDPOINT
# --------------------------------------------- #


# --------------------------------------------- #
# ---------- remote client - remote2 ---------- #
# --------------------------------------------- #
# prep remote2 dirs
cd ${X509DIR}
mkdir remote2
cd remote2

# generate the remote2 key
openssl genrsa -out remote2.key.pem 4096
chmod 400 remote2.key.pem

# generate the remote2 cert
openssl req -config ./openssl.conf \
      -key remote2.key.pem \
      -new -sha256 \
      -out remote2.csr.pem

######### VPN CA SIGNS remote2 CSR #################
# send the remote2 cert csr to the vpn ca
cd ${X509DIR}
cp ./remote2/remote2.csr.pem ./ca/vpn_ca/unsigned/

# get the remote2 cert signed by the vpn_ca cert
cd ./ca/vpn_ca/
openssl ca -config ./openssl.conf \
      -extensions remote2_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/remote2.csr.pem  \
      -out signed/remote2.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/remote2.cert.pem

# return it to the remote2 
cd ${X509DIR}
cp ./ca/vpn_ca/signed/remote2.cert.pem ./remote2/  
chmod 444 ./remote2/remote2.cert.pem

### MOVE TO VPN ENDPOINT
# --------------------------------------------- #


# --------------------------------------------- #
# ---------- remote client - remote3 ---------- #
# --------------------------------------------- #
# prep remote3 dirs
cd ${X509DIR}
mkdir remote3
cd remote3

# generate the remote3 key
openssl genrsa -out remote3.key.pem 4096
chmod 400 remote3.key.pem

# generate the remote3 cert
openssl req -config ./openssl.conf \
      -key remote3.key.pem \
      -new -sha256 \
      -out remote3.csr.pem

######### VPN CA SIGNS remote3 CSR #################
# send the remote3 cert csr to the vpn ca
cd ${X509DIR}
cp ./remote3/remote3.csr.pem ./ca/vpn_ca/unsigned/

# get the remote3 cert signed by the vpn_ca cert
cd ./ca/vpn_ca/
openssl ca -config ./openssl.conf \
      -extensions remote3_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/remote3.csr.pem  \
      -out signed/remote3.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/remote3.cert.pem

# return it to the remote3
cd ${X509DIR}
cp ./ca/vpn_ca/signed/remote3.cert.pem ./remote3/  
chmod 444 ./remote3/remote3.cert.pem

### MOVE TO VPN ENDPOINT
# --------------------------------------------- #


# --------------------------------------------- #
# ---------- remote client - remote4 ---------- #
# --------------------------------------------- #
# prep remote4 dirs
cd ${X509DIR}
mkdir remote4
cd remote4

# generate the remote4 key
openssl genrsa -out remote4.key.pem 4096
chmod 400 remote4.key.pem

# generate the remote4 cert
openssl req -config ./openssl.conf \
      -key remote4.key.pem \
      -new -sha256 \
      -out remote4.csr.pem

######### VPN CA SIGNS remote4 CSR #################
# send the remote4 cert csr to the vpn ca
cd ${X509DIR}
cp ./remote4/remote4.csr.pem ./ca/vpn_ca/unsigned/

# get the remote4 cert signed by the vpn_ca cert
cd ./ca/vpn_ca/
openssl ca -config ./openssl.conf \
      -extensions remote4_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/remote4.csr.pem  \
      -out signed/remote4.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/remote4.cert.pem

# return it to the remote4
cd ${X509DIR}
cp ./ca/vpn_ca/signed/remote4.cert.pem ./remote4/  
chmod 444 ./remote4/remote4.cert.pem

### MOVE TO VPN ENDPOINT
# --------------------------------------------- #


# --------------------------------------------- #
# ---------- remote client - remote5 ---------- #
# --------------------------------------------- #
# prep remote5 dirs
cd ${X509DIR}
mkdir remote5
cd remote5

# generate the remote5 key
openssl genrsa -out remote5.key.pem 4096
chmod 400 remote5.key.pem

# generate the remote5 cert
openssl req -config ./openssl.conf \
      -key remote5.key.pem \
      -new -sha256 \
      -out remote5.csr.pem

######### VPN CA SIGNS remote5 CSR #################
# send the remote5 cert csr to the vpn ca
cd ${X509DIR}
cp ./remote5/remote5.csr.pem ./ca/vpn_ca/unsigned/

# get the remote5 cert signed by the vpn_ca cert
cd ./ca/vpn_ca/
openssl ca -config ./openssl.conf \
      -extensions remote5_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/remote5.csr.pem  \
      -out signed/remote5.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/remote5.cert.pem

# return it to the remote5
cd ${X509DIR}
cp ./ca/vpn_ca/signed/remote5.cert.pem ./remote5/  
chmod 444 ./remote5/remote5.cert.pem

### MOVE TO VPN ENDPOINT
# --------------------------------------------- #




# --------------------------------------------- #
# --------------- WEB SERVER CA --------------- #
# --------------------------------------------- #
# prep the webserver ca dirs
cd $X509DIR
mkdir -p ./ca/webserver_ca
cd ./ca/webserver_ca/

mkdir certs crl newcerts private csr signed unsigned
chmod 700 private
touch index.txt
echo 1000 > serial

echo 1000 > ./crlnumber

# create the webserver CA key "webserver_ca_secret"
openssl genrsa -aes256 -out private/webserver_ca.key.pem 4096
chmod 400 private/vpn_ca.key.pem

# create the webserver cert
openssl req -config ./openssl.conf \
      -new -sha256 \
      -key private/webserver_ca.key.pem \
      -out csr/webserver_ca.csr.pem

########## ROOT CA SIGNS WEB SERVER CA ##############
# send the webserver ca cert csr to the root ca
cd ${X509DIR}
cp ./ca/webserver_ca/csr/webserver_ca.csr.pem ./ca/root/unsigned/

# get the webserver ca cert signed by the root cert
cd ./ca/root/
openssl ca -config ./openssl.conf \
      -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in unsigned/webserver_ca.csr.pem \
      -out signed/webserver_ca.cert.pem
      
# verify the webserver ca cert
openssl x509 -noout -text -in signed/webserver_ca.cert.pem
      
# verify against root cert      
openssl verify -CAfile certs/ca.cert.pem \
      signed/webserver_ca.cert.pem
      
# return it to the webserver ca
cd ${X509DIR}
cp ./ca/root/signed/webserver_ca.cert.pem ./ca/webserver_ca/certs/
chmod 444 ./ca/webserver_ca/certs/webserver_ca.cert.pem


######## create webserver CA CRL ################
# create a Certificate Revocation Lists (CRL)
# in case end entity certificates have to be revoked
cd ${X509DIR}/ca/webserver_ca/
openssl ca -config openssl.conf \
      -gencrl -out ./crl/webserver_ca.crl.pem
      
# check it worked 
openssl crl -in ./crl/webserver_ca.crl.pem -noout -text
# --------------------------------------------- #


# --------------------------------------------------------- #
# --- covid web server - covid.u2086937.cyber2020.test  --- #
# prep the covid web server dirs
cd ${X509DIR}
mkdir covid.u2086937.cyber2020.test
cd covid.u2086937.cyber2020.test

# generate the covid web server key (no aes256 this time to permit server unattended restart)
openssl genrsa -out covid.u2086937.cyber2020.test.key.pem 4096
chmod 400 covid.u2086937.cyber2020.test.key.pem

# generate the covid web server cert
openssl req -config ./openssl.conf \
      -key covid.u2086937.cyber2020.test.key.pem \
      -new -sha256 \
      -out covid.u2086937.cyber2020.test.csr.pem

######### webserver_ca CA SIGNS covid web server CSR #################
# send the covid web server cert csr to the webserver_ca
cd ${X509DIR}
cp ./covid.u2086937.cyber2020.test/covid.u2086937.cyber2020.test.csr.pem ./ca/webserver_ca/unsigned/

# get the covid web server cert signed by the webserver_ca cert
cd ./ca/webserver_ca/
openssl ca -config ./openssl.conf \
      -extensions covid.webserver_cert \
      -days 375 \
      -notext -md sha256 \
      -in unsigned/covid.u2086937.cyber2020.test.csr.pem \
      -out signed/covid.u2086937.cyber2020.test.cert.pem

# verify the cert
openssl x509 -noout -text -in signed/covid.u2086937.cyber2020.test.cert.pem
 
# return it to the covid web server
cd ${X509DIR}
cp ./ca/webserver_ca/signed/covid.u2086937.cyber2020.test.cert.pem ./covid.u2086937.cyber2020.test/  
chmod 444 ./covid.u2086937.cyber2020.test/covid.u2086937.cyber2020.test.cert.pem

### MOVE TO WEB SERVER
# --------------------------------------------------------- #

