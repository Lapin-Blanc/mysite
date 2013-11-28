#!/bin/bash
yum install -y system-config-{firewall,network}-tui

pushd /usr/src

rpm -Uvh http://ftp-stud.fht-esslingen.de/dag/redhat/el6/en/x86_64/rpmforge/RPMS/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
yum -y upgrade


# Installation des dépendances et de Python 2.7 avec threads et librairies partagées
yum install -y sqlite sqlite-devel gcc gdbm-devel readline-devel ncurses-devel zlib-devel bzip2-devel sqlite-devel db4-devel openssl-devel tk-devel bluez-libs-devel wget make

wget http://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz
tar xvzf Python-2.7.6.tgz
pushd Python-2.7.6
./configure --with-threads --enable-shared
make && make altinstall
cat > /etc/ld.so.conf.d/opt-python2.7.conf << EOF
/usr/local/lib
EOF
ldconfig
popd

wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python2.7

wget --no-check-certificate https://pypi.python.org/packages/source/v/virtualenv/virtualenv-1.9.1.tar.gz#md5=07e09df0adfca0b2d487e39a4bf2270a
tar -xvzf virtualenv-1.9.*.tar.gz 
pushd virtualenv-1.9.*
python2.7 setup.py install
popd

wget --no-check-certificate https://pypi.python.org/packages/source/v/virtualenvwrapper/virtualenvwrapper-4.0.tar.gz#md5=78df3b40735e959479d9de34e4b8ba15
tar -xvzf virtualenvwrapper-*.gz
pushd virtualenvwrapper-*
python2.7 setup.py install
python2.7 setup.py install
popd

# Installer apache2, mod_wsgi et mod_x_sendfile
yum install -y httpd{,-devel}
wget http://modwsgi.googlecode.com/files/mod_wsgi-3.4.tar.gz

tar xvzf mod_wsgi-3.4.tar.gz
pushd mod_wsgi-3.4/
./configure --with-python=/usr/local/bin/python2.7
make && make install
if [ "$(uname -m)" = "x86_64" ]
then
    lib_path="lib64"
else
    lib_path="lib"
fi
echo "LoadModule wsgi_module /usr/$lib_path/httpd/modules/mod_wsgi.so" > /etc/httpd/conf.d/mod_wsgi.conf
service httpd restart
popd

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
service httpd restart
chkconfig httpd on

sed -i "s/^\(SELINUX=\).*$/\1disabled/" /etc/sysconfig/selinux
setenforce 0
popd
