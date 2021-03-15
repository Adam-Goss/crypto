#!/usr/bin/bash
# script to automatically start SSL on server for HTTPS

# install mod security 
apt update && apt install libapache2-mod-security2 -y


# create unprivileged user account and group to run apache
groupadd apache
useradd -g apache apache
chown -R apache:apache /etc/apache2

# run apache with SSL configurations 
a2enmod ssl
a2enmod headers
a2ensite default-ssl
a2enconf ssl-params

# enable mod_rewrite to disable flawed HTTP 1.0 protocol
a2enmod rewrite

# enable mod_security module for added security 
#a2enmod mod-security

# check configurations are legitimate 
apache2ctl configtest

# run (or re-run) apache web server
systemctl restart apache2
