#!/bin/bash
# Configuration générale :
# - désactivation de selinux
# - personnalisation du bash pour root
# - installation et personnalisation de vim

# Désactivation de Selinux
sed -i "s/^\(SELINUX=\).*$/\1disabled/" /etc/sysconfig/selinux
setenforce 0

# Personnalisation du bash pour root
if grep -q -e "Customize the prompt" /root/.bashrc
then
    echo "Prompt already customized"
else
    cat >> /root/.bashrc <<-EOF

# Customize the prompt
if [ \$(id -u) -eq 0 ];
then # you are root, make the prompt red
    export PS1="\[\e[00;36m\]\A\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;34m\]\u\[\e[0m\]\[\e[00;33m\]@\[\e[0m\]\[\e[00;37m\]\H \[\e[0m\]\[\e[00;32m\]\w\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;33m\]\$\[\e[0m\]\[\e[00;37m\] \[\e[0m\]"
else
    export PS1="\[\e[00;36m\]\A\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;31m\]\u\[\e[0m\]\[\e[00;33m\]@\[\e[0m\]\[\e[00;37m\]\H \[\e[0m\]\[\e[00;32m\]\w\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;33m\]\$\[\e[0m\]\[\e[00;37m\] \[\e[0m\]"
fi
EOF
fi
. /root/.bashrc
yum -y install vim
echo "set expandtab
set ts=4
set sw=4" >> /etc/vimrc

# Configuration réseau
# - installation des utilitaires réseaux tui
# - définition du nom de domaine et d'hôte
ADDRESS=192.168.1.125
PREFIX=24
GATEWAY=192.168.1.1
HOSTNAME=pcfabien
DOMAIN=toune.be
DOMAINNAME=$HOSTNAME.$DOMAIN
# yum -y install system-config-{firewall,network}-tui

# passe en adressage dynamique
sed -i "s/^\(BOOTPROTO=\).*$/\1none/" /etc/sysconfig/network-scripts/ifcfg-eth0
# supprime une éventuelle configuration existante
sed -i "/^IPADDR.*/d" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i "/^PREFIX.*/d" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i "/^GATEWAY.*/d" /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i "/^DEFROUTE.*/d" /etc/sysconfig/network-scripts/ifcfg-eth0
# définit l'adressage IP
echo "IPADDR=$ADDRESS
PREFIX=$PREFIX
GATEWAY=$GATEWAY
DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-eth0

# modifie le nom d'hôte
sed -i "s/$HOSTNAME //g" /etc/hosts
sed -i "s/^\(HOSTNAME=\).*$/\1$DOMAINNAME/" /etc/sysconfig/network
sed -i "s/^\(127\.0\.0\.1.*\)\(localhost .*\)$/\1$HOSTNAME \2/" /etc/hosts
sed -i "s/^\(::1.*\)\(localhost .*\)$/\1$HOSTNAME \2/" /etc/hosts

if grep -q "$ADDRESS" /etc/hosts
then
    sed -i "/$ADDRESS.*/d" /etc/hosts
fi
echo -e "$ADDRESS\t$DOMAINNAME $HOSTNAME" >> /etc/hosts 

# Installation d'apache 2 avec support pour xsendfile, activation des virtuals host,
# activation des sites personnels ~utilisateur, ouverture du port dans iptables et
# configuration du site virtuel par défaut
yum install -y httpd{,-devel} gcc
echo -E "<h1>Welcome to CentOS Server</h1>" > /var/www/html/index.html
# Installation de mod_xsendfile
wget --no-check-certificate https://tn123.org/mod_xsendfile/mod_xsendfile.c
apxs -cia mod_xsendfile.c
if [ ! -e /var/www/xsendfiles ] 
then
        mkdir -p -v /var/www/xsendfiles
else
        echo "/var/www/xsendfiles already exists"
fi
echo "XSendFile on
XSendFilePath /var/www/xsendfiles" > /etc/httpd/conf.d/mod_xsendfile.conf

# Activation des sites individuels
sed -i "s/^\(\s*\)\(UserDir\s*disable.*\)$/\1#\2/" /etc/httpd/conf/httpd.conf
sed -i "s/^\(\s*\)#\(\s*UserDir\s*public_html.*\)$/\1\2/" /etc/httpd/conf/httpd.conf

if grep -q -F "<Directory /home/*/public_html>" /etc/httpd/conf/httpd.conf
then
    echo "public_html folders already configured..."
else
    echo "<Directory /home/*/public_html>
        Options Indexes Includes FollowSymLinks
        AllowOverride All
        Allow from all
        Order deny,allow
</Directory>" >> /etc/httpd/conf/httpd.conf
fi

# Activation des virtual hosts
sed -i "s/^\(\s*\)#\s*\(NameVirtualHost.*\)$/\1\2/" /etc/httpd/conf/httpd.conf
if ! grep -q -e "^\s*ServerName\s*$DOMAINNAME" /etc/httpd/conf/httpd.conf
then
echo "<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAINNAME
    DocumentRoot /var/www/html
    ServerName $DOMAINNAME
    ErrorLog logs/$DOMAINNAME-error_log
    CustomLog logs/$DOMAINNAME-access_log common
</VirtualHost>" >> /etc/httpd/conf/httpd.conf
fi

# Ouverture du firewall
if ! grep -e "--dport 80" /etc/sysconfig/iptables
then
    sed  -i '/--dport 22/{h;s//--dport 80/;H;x}' /etc/sysconfig/iptables
fi
service iptables restart
service httpd restart
chkconfig httpd on

reboot
