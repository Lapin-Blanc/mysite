#!/bin/bash
USERNAME=fabien
PASSWORD=corine
DOMAIN=fabien.toune.be
EMAIL=fabien@toune.be

useradd $USERNAME
echo $USERNAME:$PASSWORD | chpasswd

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


su - $USERNAME << EOF
cd
mkvirtualenv django16
pip install django==1.6
mkdir django
pushd django
django-admin.py startproject mysite
pushd mysite
mkdir static xsendfiles
python2.7 manage.py syncdb --noinput
echo "from django.contrib.auth.models import User; \
    User.objects.filter(username='$USERNAME').count()  \
    or User.objects.create_superuser('$USERNAME', '$EMAIL', '$PASSWORD')" | python2.7 manage.py shell
popd
popd
ln -s ~/.virtualenvs/django16/lib/python2.7/site-packages/django/contrib/admin/static/admin/ ~/django/mysite/static/admin
EOF


# Active les virtual hosts
sed -i "s/^\(\s*\)#\s*\(NameVirtualHost.*\)$/\1\2/" /etc/httpd/conf/httpd.conf
if grep -q "WSGISocketPrefix" /etc/httpd/conf/httpd.conf
then 
    echo "WSGISocketPrefix already configured"
else 
    sed -i "/^\(\s*\)\(NameVirtualHost.*\)$/a\WSGISocketPrefix /var/run/wsgi" /etc/httpd/conf/httpd.conf
fi

if grep -q "ServerName $DOMAIN" /etc/httpd/conf/httpd.conf
then 
    echo "Virtual host $DOMAIN already configured"
else 
    echo "
    <VirtualHost *:80>

        ServerAdmin webmaster@$DOMAIN
        ServerName $DOMAIN
        ErrorLog logs/$DOMAIN-error
        CustomLog logs/$DOMAIN-access common

        Alias /static/ /home/$USERNAME/django/mysite/static/
        <Directory /home/$USERNAME/django/mysite/static/>
            Order deny,allow
            Allow from all
        </Directory>

        WSGIProcessGroup $DOMAIN
        WSGIDaemonProcess $DOMAIN user=$USERNAME group=$USERNAME python-path=/home/$USERNAME/django/mysite/:/home/$USERNAME/.virtualenvs/django16/lib/python2.7/site-packages/
        WSGIScriptAlias / /home/$USERNAME/django/mysite/mysite/wsgi.py

        <Directory /home/$USERNAME/django/mysite/>
            <Files wsgi.py>
                Order deny,allow
                Allow from all
            </Files>
        </Directory>
    </VirtualHost>" >> /etc/httpd/conf/httpd.conf
fi
# echo "$USERNAME" >> /etc/vsftpd/chroot_list
