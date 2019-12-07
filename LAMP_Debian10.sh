#!/bin/bash

#<UDF name="newuser" Label="New user" example="username" />
#<UDF name="newpassword" Label="New user password" example="password" />
#<UDF name="hostname" Label="Hostname" example="example" />
#<UDF name="domain" Label="Domain" example="example.com" />

# <UDF name="dbpass" Label="MySQL root Password" />
# <UDF name="dbname" Label="Create Database" default="" example="Create database" />


# Update system
apt-get -o Acquire::ForceIPv4=true update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
apt-get -o Acquire::ForceIPv4=true update -y

# Add newuser and append to sudoer file
adduser $NEWUSER --disabled-password --gecos "" && \
echo "$NEWUSER:$NEWPASSWORD" | chpasswd
echo "$NEWUSER  ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Set hostname
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1   $HOSTNAME" >> /etc/hosts


# Install Apache
apt-get install apache2 -y


# Edit apache config
sed -ie "s/KeepAlive Off/KeepAlive On/g" /etc/apache2/apache2.conf


# Create a copy of the default Apache configuration file for your site:
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$DOMAIN.conf


# Configuration of vhost file
cat <<END >/etc/apache2/sites-available/$DOMAIN.conf
<Directory /var/www/html/$DOMAIN/public_html>
    Require all granted
</Directory>
<VirtualHost *:80>
        ServerName $DOMAIN
        ServerAlias www.$DOMAIN
        ServerAdmin webmaster@$DOMAIN
        DocumentRoot /var/www/html/$DOMAIN/public_html

        ErrorLog /var/www/html/$DOMAIN/logs/error.log
        CustomLog /var/www/html/$DOMAIN/logs/access.log combined

</VirtualHost>
END

mkdir -p /var/www/html/$DOMAIN/{public_html,logs}


cat <<END >/var/www/html/$DOMAIN/public_html/index.html
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
sudo a2ensite $DOMAIN.conf


# Disable the default virtual host
a2dissite 000-default.conf


# Restart apache
systemctl reload apache2

# Install Certbot for Let's Encrypt certificate management
apt-get install -y certbot python-certbot-apache

# Install Composer
apt-get install -y composer

# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
echo "mysql-server mysql-server/root_password password $DBPASS" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASS" | sudo debconf-set-selections
apt-get -y install default-mysql-server

mysql -uroot -p$DBPASS -e "create database $DBNAME"

service mysql restart

# Install php
apt install -y php libapache2-mod-php php-mysql php-pear php-zip php-curl php-xmlrpc php-gd php-mbstring php-xml

# Enable index.php
sed -ie "s/DirectoryIndex index.html index.cgi index.pl index.php index.xhtml indem/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/g" /etc/apache2/mods-enabled/dir.conf

cat <<END >/var/www/html/$DOMAIN/public_html/info.php
<?php phpinfo(); ?>
END

# Directory for php logs
mkdir /var/log/php
chown www-data /var/log/php
systemctl restart apache2
