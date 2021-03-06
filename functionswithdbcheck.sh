#!/bin/bash


sudo -i

## making the server user to a root to avoid permission issues.

CTIME=$(date +%d-%m-%Y-%H:%M-%S) #### to catch the date & time of the commands
#exec 2> >(while read line; do echo "$(date +'%h %d %H:%M:%S') $line" >> foo.log; done;)
#exec 2> /home/ubuntu/log.txt
exec 2> >(perl -pe '$x=`date "+%d %b %Y %H:%M %p"`;chomp($x);$_=$x." ".$_' >/var/www/$CTIME.error.log) 
#touch /home/ubuntu/log.txt
slackmessenger(){

curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$1"'"}' https://hooks.slack.com/services/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



}
Download(){

 echo -e "$CTIME your desired package name:$1" | sudo tee -a /home/ubuntu/log.txt ##### this installs your package one by one check if its installed or not and then work
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

	echo -e "$CTIME ################Apache setup in Place##########################3" | sudo tee -a /var/www/$CTIME.error.log
	slackmessenger "apache setup in place"
	sudo a2dismod php7.4
####sudo apt-get --assume-yes install php7.4-fpm
	a2enmod proxy_fcgi setenvif
	a2enconf php7.4-fpm
	systemctl restart apache2 ##this should enable php7.4fpm on the apache server. Currently the apache is on port 80, we need to change it to port 8081

	sudo mv /etc/apache2/ports.conf /etc/apache2/ports.conf.default
	echo "Listen 8081" | sudo tee /etc/apache2/ports.conf ##changes the default listiing port. however, we still need to change the virtual host port to bring it into full effect.
	echo -e "$CTIME adding 8081 port to ports.conf" | sudo tee -a /home/ubuntu/log.txt
	###### Now changing the conf file has to steps. either edit the existing file or make a new conf file
	#### Since its always better to have a backup, Ill make a new conf file which will be identical to the default conf file. (Disabling the default one in process)

	a2dissite 000-default
	##########################sudo cp -r /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/osama.conf

	##change the ports and stuff before enabling site....

	sudo awk {print $0; printf '<VirtualHost *:8081> \n ServerName osama.com \n ServerAdmin webmaster@localhost \n DocumentRoot /var/www/osama \n ServerAlias www.osama.com\n <Directory /var/www/osama>\n AllowOverride All\n </Directory> \n ErrorLog ${APACHE_LOG_DIR}/error.log \n
CustomLog ${APACHE_LOG_DIR}/access.log combined \n\n</VirtualHost>\n' > /etc/apache2/sites-available/osama.conf
	sudo a2ensite osama.conf
#########Abondoned########  awk '{ print $0 ; if(NR == 10) printf "DocumentRoot=/var/www/osama\n  ServerName osama.com\n  ServerAlias www.osama.com\n <Directory /var/www/osama>\n AllowOverride All\n  </Director>
	cat /etc/apache2/sites-available/osama.conf 
	sudo ln -s /etc/apache2/sites-available/osama.conf /etc/apache2/sites-enabled/osama.conf


	systemctl reload apache2  ##### can change the awk commmand to add virtual host. would be better will test it out.
	sudo a2enmod rewrite
	echo -e "$CTIME ################APACHE SETUP COMPLETED#######################" | sudo tee -a /var/www/$CTIME.error.log
	slackmessenger "apachesettings completed"

}


#### STILL HAVE TO MAKE DIRECTORY.. NO NEED TO ADD IN ANY FUNCTIONS.... 

varnishsetup(){

	echo -e "$CTIME ################VARNISH SETUP##########################" | sudo tee -a /var/www/$CTIME.error.log
	slackmessenger "varnish setting tacking place"
	varnishport=$(grep '\-a' /lib/systemd/system/varnish.service| sed 's/.*\-a ://' |cut -d ' ' -f 1);
	sudo sed -i "s/$varnishport/8080/g" /usr/lib/systemd/system/varnish.service
	echo -e "$CTIME CATING VARNISH.SERVICE FILE" | sudo tee -a /var/www/$CTIME.error.log
	cat /usr/lib/systemd/system/varnish.service | sudo tee -a /var/www/$CTIME.error.log 
	##### ALTERNATIVE WAYYYY 
	#######cat varnish.service | grep ExecStart | cut -d ' ' -f 7 ## CATCHES PORT AND THEN USE SED TO REPLACE.....
	##changes the varnish port.. Now, we need to either edit or make a conf file that connects to apache...

	backendport=$(cat /etc/varnish/default.vcl | grep .port | sed 's/.*.port = "//' |cut -d '"' -f 1);
	sudo sed -i "s/$backendport/8081/g" /etc/varnish/default.vcl
	echo -e "$CTIME CATING DEFAULT.VCL" | sudo tee -a /var/www/$CTIME.error.log
	cat /etc/varnish/default.vcl | sudo tee -a /var/www/$CTIME.error.log 

	####### just need to add hit&miss code in default.vcl. will do so later...
	### Now all the changes are to be done in nginx.. Where we will add a load balancer function that will act as a reverse proxy and also changes in virtual host so the proxy pass can be called...

	echo -e "$CTIME #################VARNISHS SETUP COMPLETED###############" | sudo tee -a /var/www/$CTIME.error.log
	slackmessenger "varnish setting has been completed"
}


nginxsetup(){
	#sudo -i
	echo -e "$CTIME ########################ALL CHANGES IN NGINX TAKING PLACE#########################" | sudo tee -a /var/www/$CTIME.error.log
	slackmessenger "Nginx settings taking place"
	sudo touch /etc/nginx/conf.d/backend.conf
##Either this or  echo "upstream backend { server 127.0.0.1:8080 fail_timeout=5s weight=5;\n server 127.0.0.1:8081 backup;\n  #upstream} | tee /etc/nginx/conf.d/backend.conf
	sudo awk {print $0; printf "upstream backend{\n server 127.0.0.1:8080 fail_timeout=5s weight=5; \n server 127.0.0.1:8081 backup; \n }" > /etc/nginx/conf.d/backend.conf
	echo -e "$CTIME cating upstream function" | sudo tee -a /var/www/$CTIME.error.log
	cat /etc/nginx/conf.d/backend.conf | sudo tee -a /var/www/$CTIME.error.log
	sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
	sudo mv /etc/nginx/sites-available/default.backup /home/ubuntu

	sudo awk {print $0; printf 'server {\n listen 80 default_server;\n listen [::]:80 default_server;\n index index.html index.htm index.nginx-debian.html index.php;\n server_name osama;\n location / {\n proxy_pass http://backend;\n  proxy_set_header Host $host; \n proxy_set_header X-Real-IP $remote_addr; \n proxy_set_header X-Forwarded-Host $host:$server_port; \n proxy_set_header X-Forwarded-Server $host; \n proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \n proxy_set_header X-Forwarded-Proto $scheme; \n } \n}' > /etc/nginx/sites-available/osama.com
	echo -e "$CTIME Nginx conf file here" | sudo tee -a /var/www/$CTIME.error.log 
	#cat /etc/nginx/sites-available/osama.com | sudo tee -a /var/www/$CTIME.error.log

	sudo ln -s /etc/nginx/sites-available/osama.com /etc/nginx/sites-enabled/osama.com
	#sudo rm -rf /etc/nginx/sites-available/default
	sudo rm -rf /etc/nginx/sites-enabled/default
	echo -e "$CTIME ####################NGINX CHANGES COMPLETED################################" | sudo tee -a /var/www/$CTIME.error.log
	echo -e "$CTIME ## Reverse Proxy  Completed....###" | sudo tee -a /var/www/$CTIME.error.log 
	slackmessenger "Nginx & Reverseproxy completed :P"
}


								#####################################reverse proxy setup finished#############################
db_validator=1


db_exists(){

	db_checker=$1

	echo $db_checker
#new=$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w ${1:-10} | head -n 1)
	if mysql "${db_checker}" >/dev/null 2>&1 </dev/null
	then
  	 echo -e "$CTIME ${db_checker} exists generating a new one" | sudo tee -a /var/www/$CTIME.error.log 
  	 #new=$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w 10 | head -n 1)
  	 #echo $new
  	 #sudo mysql -e create database if not exists $new_db;"
  	 db_validator=0
 	 echo "$db_validator" ########## 0 means db already exists

	else
  	 echo -e "$CTIME ${db_checker} does not exist, generating it" | sudo tee -a /var/www/$CTIME.error.log 
  #sudo mysql -e "create DATABASE IF NOT EXISTS $db_checker;"
  	 
	 echo "$db_validator"  ########### 1 means db does not exists

	fi


}

#db_checkers(){

	#db_name=$1
#db_exists osamah
	#db_exists $db_name
#	if [ $db_validator == 1 ];
#	then
#	echo "db does not exists";
#
#	elif [ $db_validator == 0 ]
#	then
#	echo "exists generating a new one";

#	else
#	echo "error";
#	fi
#}

#echo $db_name
#db_exists osamah
#dp_checkers

mysqlsetup(){
	
	echo "$CTIME ################# MYSQL DB CREATION ###################" | sudo tee -a /var/www/$CTIME.error.log 
	dbname1=$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w 10 | head -n 1) ###prefferred db name
		
	sudo systemctl start mariadb
	sudo systemctl enable mariadb
	db_exists $dbname1
	sudo mysql -e "create user IF NOT EXISTS 'Osama'@'localhost' identified by 'Osama123';"

       	if [ $db_validator == 1 ];
        then
	echo -e "$CTIME db does not exists" | sudo tee -a /var/www/$CTIME.error.log  ###########if the db doesnot exists then it makes one with that name
	sudo mysql -e "create database if not exists $dbname1;"
	sudo mysql -e "grant all privileges on $dbname1.* to 'Osama'@'localhost';"
	elif [ $db_validator == 0 ]
       	then
	echo -e "$CTIME exists generating a new one" | sudo tee -a /var/www/$CTIME.error.log 
	dbname2=$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w 10 | head -n 1)
	sudo mysql -e "create database if not exists $dbname2;"    ############## generates  different one if the db name exists
	sudo mysql -e "grant all privileges on $dbname2.* to 'Osama'@'localhost';"
	else
	echo "error";
	fi

#	sudo mysql -e "create database if not exists wp_test;"
#	sudo mysql -e "create user IF NOT EXISTS 'Osama'@'localhost' identified by 'Osama123';"
	sudo mysql -e "select * from mysql.user where User='Osama';"
#	sudo mysql -e "grant all privileges on wp_test.* to 'Osama'@'localhost';"
	sudo mysql -e "flush privileges;"

	echo -e "$CTIME ################ MYSQL USER & DB CREATED ################" | sudo tee -a /var/www/$CTIME.error.log 
}


sysreboot(){

	
	echo -e "$CTIME ####################REBOOOTING SYSTEM##################" | sudo tee -a /var/www/$CTIME.error.log 
	sudo systemctl daemon-reload
	sudo systemctl restart nginx varnish apache2 mysql
	
	echo -e "$CTIME #####SERVER RESTARTED############" | sudo tee -a /var/www/$CTIME.error.log  #### restart php in future.&mysql


}


wpsetup(){
	
	sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	sudo chmod +x wp-cli.phar
	sudo mv wp-cli.phar /usr/local/bin/wp   ###Infamous wp-cli. needed it for the next step hence using it...

	echo -e "$CTIME ################WORDPRESS SETUP##################" | sudo tee -a /var/www/$CTIME.error.log 
	cd /var/www/osama/
	wp core download --allow-root

	if [ $db_validator == 1 ];
        then
        echo -e "$CTIME db does not exists, creating config with same db" | sudo tee -a /var/www/$CTIME.error.log 
       # sudo mysql -e "create database if not exists $dbname1;"
	wp config create --dbname=$dbname1 --dbuser=Osama --dbpass=Osama123 --dbhost='localhost' --allow-root
        elif [ $db_validator == 0 ]
        then
        echo -e "$CTIME exists generating a new config file with different db" | sudo tee -a /var/www/$CTIME.error.log
        #sudo mysql -e "create database if not exists $dbname2;"
	wp config create --dbname=$dbname2 --dbuser=Osama --dbpass=Osama123 --dbhost='localhost' --allow-root
        else
        echo "error";
        fi

	#wp config create --dbname=wp_test --dbuser=Osama --dbpass=Osama123 --dbhost='localhost' --allow-root

	#wp db create --allow-root

	wp core install --url='osama.com' --title='thisworks' --admin_user='Osama' --admin_password='Osama123' --admin_email='osama.hilal@cloudways.com' --allow-root

#	sudo apt-get --assume-yes install php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip
	sudo chown -R www-data:www-data /var/www/osama
	#sed -i "76i define('FS_METHOD','direct');\n" /var/www/osama/wp-config.php ###need this for breeze to work properly
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

	echo -e "$CTIME #################################################THIS HAS BEEN A SUCCESS. GOOD BYE. ########################################################" | sudo tee -a /var/www/$CTIME.error.log 

}


systemstatuses(){

#######server statuses

echo -e "$CTIME all server related statuses" | sudo tee -a /home/ubuntu/log.txt 
sudo systemctl status nginx varnish apache2

}

#trap ' ' 2 15 20 &&& trap - 2 15 20

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

