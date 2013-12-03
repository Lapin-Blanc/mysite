#!/bin/bash

function usage {
    echo "$0 [OPTIONS] où les options sont :
        -u | --user        : nom d'utilisateur
        -m | --mail        : adresse mail
        -d | --domain      : domaine de l'hôte virtuel
        -p | --password    : mot de passe
        -h | --help        : cette aide
    "
}

while [ "$1" != "" ]; do
    case $1 in
        -u | --user )           shift
                                USERNAME=$1
                                ;;
        -m | --mail )           shift
                                EMAIL=$1
                                ;;
        -d | --domain )         shift
                                DOMAIN=$1
                                ;;
        -p | --password )       shift
                                PASSWORD=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done
while [ -z $USERNAME ]
do
        read -p "$(echo -e "Nom d'utilisateur : ")" USERNAME
done
while [ -z $EMAIL ]
do
        read -p "$(echo -e "Adresse email : ")" EMAIL
done

while [ -z $DOMAIN ]
do
        read -p "$(echo -e "Domaine : ")" DOMAIN
done

while [ -z $PASSWORD ]
do
        read -s -p "$(echo -e "Mot de passe : ")" PASS1
        read -s -p "$(echo -e "\nMot de passe (vérification): ")" PASS2
        while [ "$PASS1" != "$PASS2" ]
        do
                echo -e "\nles mots de passe ne concordent pas..."
                read -s -p "$(echo -e "Mot de passe : ")" PASS1
                read -s -p "$(echo -e "\nMot de passe (vérification): ")" PASS2
        done
        PASSWORD=$PASS1
        echo -e "\n"
done

# echo 1.$USERNAME
# echo 2.$PASSWORD
# echo 3.$DOMAIN
# echo 4.$EMAIL

useradd $USERNAME
echo $USERNAME:$PASSWORD | chpasswd

# Configuration générale de l'utilisateur
# - Configuration du prompt
# - Configuration de python et des virtualenvs
# - Configuration du site personnel

chmod 711 /home/$USERNAME
cat >> /home/$USERNAME/.bashrc <<-EOF
# Turn the prompt symbol red if the user is root
if [ \$(id -u) -eq 0 ];
then # you are root, make the prompt red
    export PS1="\[\e[00;36m\]\A\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;34m\]\u\[\e[0m\]\[\e[00;33m\]@\[\e[0m\]\[\e[00;37m\]\H \[\e[0m\]\[\e[00;32m\]\w\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;33m\]\$\[\e[0m\]\[\e[00;37m\] \[\e[0m\]"
else
    export PS1="\[\e[00;36m\]\A\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;31m\]\u\[\e[0m\]\[\e[00;33m\]@\[\e[0m\]\[\e[00;37m\]\H \[\e[0m\]\[\e[00;32m\]\w\[\e[0m\]\[\e[00;37m\] \[\e[0m\]\[\e[00;33m\]\$\[\e[0m\]\[\e[00;37m\] \[\e[0m\]"
fi

alias python=\$(which python2.7)

export VIRTUALENVWRAPPER_PYTHON=\$(which python2.7)
source /usr/local/bin/virtualenvwrapper.sh
EOF

if ! grep -s "$USERNAME" /etc/vsftpd/chroot_list
then
    echo "$USERNAME" >> /etc/vsftpd/chroot_list
fi

# Configuration du site personnel
mkdir -p /home/$USERNAME/public_html
echo "<h2>Page d'accueil de $USERNAME</h2>" >> /home/$USERNAME/public_html/index.html
chmod 711 /home/$USERNAME
chmod 755 /home/$USERNAME/public_html
chown -R $USERNAME:$USERNAME /home/$USERNAME/public_html
service httpd restart

# Configuration des répertoires virtuels
if ! grep -s -e "<Directory /home/*/public_html>" /etc/httpd/conf/httpd.conf
then echo "<Directory /home/*/public_html>
    Options Indexes Includes FollowSymLinks
    AllowOverride All
    Allow from all
    Order deny,allow
</Directory>" >> /etc/httpd/conf/httpd.conf
fi

exit 0
