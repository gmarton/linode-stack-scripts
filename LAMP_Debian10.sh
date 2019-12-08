#!/bin/bash

#<UDF name="NEWUSER" Label="New user" example="username" />
#<UDF name="NEWPASSWORD" Label="New user password" example="password" />
#<UDF name="SSHKEY" Label="User SSH Key (from ~/.ssh/id_rsa.pub)" />
#<UDF name="NEWHOSTNAME" Label="NEWHOSTNAME" example="example" />
#<UDF name="DOMAINNAME" Label="DOMAINNAME" example="example.com" />

# <UDF name="DBPASS" Label="MySQL root Password" />
# <UDF name="DBNAME" Label="Create Database" default="" example="Create database" />

# Harden SSH
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl restart sshd
passwd --lock root

# Update system
apt-get -o Acquire::ForceIPv4=true update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
apt-get -o Acquire::ForceIPv4=true update -y

# Add NEWUSER and add to sudoers
apt-get -y install sudo
adduser $NEWUSER --disabled-password --gecos "" && \
	echo "$NEWUSER:$NEWPASSWORD" | chpasswd
usermod -aG sudo $NEWUSER

SSHDIR="/home/$NEWUSER/.ssh"
mkdir $SSHDIR && echo "$SSHKEY" >> $SSHDIR/authorized_keys
chmod -R 700 $SSHDIR && chmod 600 $SSHDIR/authorized_keys
chown -R $NEWUSER:$NEWUSER $SSHDIR

# Set NEWHOSTNAME
hostnamectl set-hostname $NEWHOSTNAME
echo "127.0.0.1   $NEWHOSTNAME" >> /etc/hosts


# Install Apache
apt-get install apache2 -y

# Edit apache config
sed -ie "s/KeepAlive Off/KeepAlive On/g" /etc/apache2/apache2.conf


# Create a copy of the default Apache configuration file for your site:
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$DOMAINNAME.conf


# Configuration of vhost file
cat <<END >/etc/apache2/sites-available/$DOMAINNAME.conf
<Directory /var/www/html/$DOMAINNAME/public_html>
    Require all granted
</Directory>
<VirtualHost *:80>
        ServerName $DOMAINNAME
        ServerAlias www.$DOMAINNAME
        ServerAdmin webmaster@$DOMAINNAME
        DocumentRoot /var/www/html/$DOMAINNAME/public_html

        ErrorLog /var/www/html/$DOMAINNAME/logs/error.log
        CustomLog /var/www/html/$DOMAINNAME/logs/access.log combined

</VirtualHost>
END

mkdir -p /var/www/html/$DOMAINNAME/{public_html,logs}


cat <<END >/var/www/html/$DOMAINNAME/public_html/index.html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>StackSript Success</title>
</head>

<body>
<h1>StackScript successfully executed.</h1>
<h2>Next Steps:</h2>
<ol>
<li><a href="info.php">Check php installation.</a></li>
<li>execute 'sudo certbot --apache' to enable encryption.</li>
</body>

</html>
END

rm /var/www/html/index.html


# Enable your virtual host:
sudo a2ensite $DOMAINNAME.conf


# Disable the default virtual host
a2dissite 000-default.conf


# Restart apache
systemctl reload apache2

# Install Certbot for Let's Encrypt certificate management
apt-get install -y certbot python-certbot-apache

# Install Composer
apt-get install -y composer

# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
apt-get install -y default-mysql-server
systemctl enable mariadb.service
mysql_secure_installation <<EOF
y
$DBPASS
$DBPASS
y
y
y
y
EOF


mysql -e "update mysql.user set plugin='' where User='root'"
mysql -uroot -p$DBPASS -e "flush privileges"

mysql -uroot -p$DBPASS -e "create database $DBNAME"

systemctl restart mariadb.service

# Install php
apt install -y php libapache2-mod-php php-mysql php-pear php-zip php-curl php-xmlrpc php-gd php-mbstring php-xml

# Enable index.php
sed -ie "s/DirectoryIndex index.html index.cgi index.pl index.php index.xhtml indem/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/g" /etc/apache2/mods-enabled/dir.conf

cat <<END >/var/www/html/$DOMAINNAME/public_html/info.php
<?php phpinfo(); ?>
END

# Directory for php logs
mkdir /var/log/php
chown www-data /var/log/php
systemctl restart apache2

# Firewall
apt-get install ufw -y
ufw default allow outgoing
ufw default deny incoming
ufw allow 22
ufw allow http
ufw allow https
ufw enable
