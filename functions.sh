#!/bin/bash

## making the server user to a root to avoid permission issues.
Download(){
 echo "your disired package name:$1" ##### this installs your package one by one check if its installed or not and then work
 #   read name

    dpkg -s $1 &> /dev/null

    if [ $? -ne 0 ]

        then
            echo "not installed"
   #         sudo apt-get update
            sudo apt-get --assume-yes install $1

        else
            echo "installed"
    fi
}



#####Making directorry first
##sudo mkdir /var/www/osama

################################################################### Reverse PROXY SETUP###################################################
apachesetup(){
	sudo -i
	echo "################Apache setup in Place##########################3"
	sudo a2dismod php7.4
####sudo apt-get --assume-yes install php7.4-fpm
	a2enmod proxy_fcgi setenvif
	a2enconf php7.4-fpm
	systemctl restart apache2 ##this should enable php7.4fpm on the apache server. Currently the apache is on port 80, we need to change it to port 8081

	sudo mv /etc/apache2/ports.conf /etc/apache2/ports.conf.default
	echo "Listen 8081" | sudo tee /etc/apache2/ports.conf ##changes the default listiing port. however, we still need to change the virtual host port to bring it into full effect.

###### Now changing the conf file has to steps. either edit the existing file or make a new conf file
#### Since its always better to have a backup, Ill make a new conf file which will be identical to the default conf file. (Disabling the default one in process)

	a2dissite 000-default
##########################sudo cp -r /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/osama.conf

##change the ports and stuff before enabling site....

	sudo awk {print $0;'<VirtualHost *:8081> \n ServerName osama.com \n ServerAdmin webmaster@localhost \n DocumentRoot /var/www/osama \n ServerAlias www.osama.com\n <Directory /var/www/osama>\n AllowOverride All\n>
\n</VirtualHost>\n'> /etc/apache2/sites-available/osama.conf

	sudo a2ensite osama.conf
#########Abondoned########  awk '{ print $0 ; if(NR == 10) printf "DocumentRoot=/var/www/osama\n  ServerName osama.com\n  ServerAlias www.osama.com\n <Directory /var/www/osama>\n AllowOverride All\n  </Director>

	sudo ln -s /etc/apache2/sites-available/osama.conf /etc/apache2/sites-enabled/osama.conf


	systemctl reload apache2  ##### can change the awk commmand to add virtual host. would be better will test it out.
	sudo a2enmod rewrite
	echo "################APACHE SETUP COMPLETED#######################";


}


#### STILL HAVE TO MAKE DIRECTORY.. NO NEED TO ADD IN ANY FUNCTIONS.... 

varnishsetup(){
sudo -i
#echo "################VARNISH SETUP##########################";

varnishport=$(grep '\-a' /lib/systemd/system/varnish.service| sed 's/.*\-a ://' |cut -d ' ' -f 1);
sudo sed -i "s/$varnishport/8080/g" /usr/lib/systemd/system/varnish.service
cat /usr/lib/systemd/system/varnish.service
##### ALTERNATIVE WAYYYY 
#######cat varnish.service | grep ExecStart | cut -d ' ' -f 7 ## CATCHES PORT AND THEN USE SED TO REPLACE.....
##changes the varnish port.. Now, we need to either edit or make a conf file that connects to apache...

backendport=$(cat /etc/varnish/default.vcl | grep .port | sed 's/.*.port = "//' |cut -d '"' -f 1);
sudo sed -i "s/$backendport/8081/g" /etc/varnish/default.vcl
cat /etc/varnish/default.vcl

####### just need to add hit&miss code in default.vcl. will do so later...
### Now all the changes are to be done in nginx.. Where we will add a load balancer function that will act as a reverse proxy and also changes in virtual host so the proxy pass can be called...

echo "#################VARNISHS SETUP COMPLETED###############";

}


nginxsetup(){
	sduo -i
	echo "########################ALL CHANGES IN NGINX TAKING PLACE#########################";
	sudo touch /etc/nginx/conf.d/backend.conf
##Either this or  echo "upstream backend { server 127.0.0.1:8080 fail_timeout=5s weight=5;\n server 127.0.0.1:8081 backup;\n  #upstream} | tee /etc/nginx/conf.d/backend.conf
	sudo awk {print $0; printf "upstream backend{\n server 127.0.0.1:8080 fail_timeout=5s weight=5; \n server 127.0.0.1:8081 backup; \n }" > /etc/nginx/conf.d/backend.conf

	sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
	sudo mv /etc/nginx/sites-available/default.backup /home/ubuntu

	sudo awk{print $0; printf 'server {\n listen 80 default_server;\n listen [::]:80 default_server;\n index index.html index.htm index.nginx-debian.html index.php;\n server_name osama;\n location / {\n proxy_pass http://backend;\n  proxy_set_header Host $host; \n proxy_set_header X-Real-IP $remote_addr; \n proxy_set_header X-Forwarded-Host $host:$server_port; \n proxy_set_header X-Forwarded-Server $host; \n proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \n proxy_set_header X-Forwarded-Proto $scheme; \n } \n}' > /etc/nginx/sites-available/osama.com

	sudo ln -s /etc/nginx/sites-available/osama.com /etc/nginx/sites-enabled/osama.com
	sudo rm -rf /etc/nginx/sites-available/default
	echo "####################NGINX CHANGES COMPLETED################################";
	echo "## Reverse Proxy  Completed....###";
}


#####################################reverse proxy setup finished#############################

mysqlsetup(){
	sudo -i
	echo "#################MYSQL DB CREATION ###################";

	sudo systemctl start mariadb
	sudo systemctl enable mariadb

	sudo mysql -e "create database if not exists wp_test;"
	sudo mysql -e "create user IF NOT EXISTS 'Osama'@'localhost' identified by 'Osama123';"
	sudo mysql -e "select * from mysql.user where User='Osama';"
	sudo mysql -e "grant all privileges on wp_test.* to 'Osama'@'localhost';"
	sudo mysql -e "flush privileges;"

	echo "################MYSQL USER & DB CREATED################";
}


sysreboot(){

	sudo -i
	echo "####################REBOOOTING SYSTEM##################";
	sudo systemctl restart nginx varnish apache2 mysql
	
	echo "#####SERVER RESTARTED############"


}


wpsetup(){
	sudo -i
	sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	sudo chmod +x wp-cli.phar
	sudo mv wp-cli.phar /usr/local/bin/wp   ###Infamous wp-cli. needed it for the next step hence using it...

	echo "################WORDPRESS SETUP##################";
	cd /var/www/osama/
	wp core download --allow-root

	wp config create --dbname=wp_test --dbuser=Osama --dbpass=Osama123 --dbhost='localhost' --allow-root

	wp db create --allow-root

	wp core install --url='osama.com' --title='thisworks' --admin_user='Osama' --admin_password='Osama123' --admin_email='osama.hilal@cloudways.com' --allow-root

	sudo apt-get --assume-yes install php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip
	sudo chown -R www-data:www-data /var/www/osama
	sed -i "76i \ndefine('FS_METHOD','direct');\n" /var/www/osama/wp-config.php ###need this for breeze to work properly
	wp plugin install breeze --activate --allow-root

	echo "# BEGIN WordPress

	RewriteEngine On
	RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
	RewriteBase /
	RewriteRule ^index\.php$ - [L]
	RewriteCond %{REQUEST_FILENAME} !-f
	RewriteCond %{REQUEST_FILENAME} !-d
	RewriteRule . /index.php [L]

	# END WordPress" | sudo tee /var/www/osama/.htaccess

	echo "#################################################THIS HAS BEEN A SUCCESS. GOOD BYE. ########################################################";

}


systemstatuses(){

#######server statuses

echo "all server related statuses";
sudo systemctl status nginx varnish apache2

}

#sudo -i
declare -a phparray=("php7.4" "php7.4-fpm" "libapache2-mod-php7.4" "php7.4-mysql" "php-common" "php7.4-cli" "php7.4-common" "php7.4-json" "php7.4-opcache" "php7.4-readline" "php-curl" "php-gd" "php-mbstring" "php-xml" "php-xmlrpc" "php-soap" "php-intl" "php-zip");
declare -a apache=("apache2" "apache2-utils");
declare -a mariadb=("mariadb-server" "mariadb-client");
sudo apt-get --assume-yes update
sudo apt-get --assume-yes upgrade
for i in ${apache[@]}; do
 echo $i
 Download $i
 done
for n in ${mariadb[@]}; do
 echo $n
 Download $n
 done

for z in ${phparray[@]}; do
 echo $z
 Download $z
 done
######installing stufff#########
Download nginx
Download varnish
sudo mkdir /var/www/osama
########## Download Setup completed##################
apachesetup
varnishsetup
nginxsetup
mysqlsetup
sysreboot
wpsetup
systemstatuses

