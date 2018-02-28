#!/bin/bash

/bin/rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
/bin/rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
/usr/bin/yum -y install mod_php71w php71w-opcache php71w-cli php71w-mysql php71w-gd php71w-xml php71w-intl

/usr/bin/echo "adjusting apache configuration"
/bin/printf "<VirtualHost *:80>\n\tServerAdmin root@$(hostname)\n\tServerName $(hostname)\n\tServerAlias $(hostname -I)\n\tDocumentRoot /var/www/moodle\n\t<Directory />\n\t\tOptions FollowSymLinks\n\t\tAllowOverride None\n\t</Directory>\n\t<Directory /var/www/moodle/>\n\t\tOptions Indexes FollowSymLinks MultiViews\n\t\tAllowOverride All\n\t\tOrder allow,deny\n\t\tallow from all\n\t</Directory>\n\n\tErrorLog /var/log/httpd/$(hostname)_error.log\n\n\t# Possible values include: debug, info, notice, warn, error, crit,\n\t# alert, emerg.\n\tLogLevel warn\n\nCustomLog /var/log/httpd/$(hostname)_access.log combined\n</VirtualHost>\n" > /etc/httpd/conf.d/$(hostname).conf
/usr/bin/sed -i 's/DirectoryIndex\ index.html/DirectoryIndex\ index.html\ index.php/' /etc/httpd/conf/httpd.conf


/usr/bin/sed -i 's/^\[client\]/\[client\]\ndefault-character-set\ =\ utf8mb4\n/' /etc/my.cnf.d/client.cnf
/usr/bin/sed -i 's/^\[mysqld\]/\[mysqld\]\ninnodb_file_format\ =\ Barracuda\ninnodb_file_per_table\ =\ 1\ninnodb_large_prefix\n/' /etc/my.cnf.d/server.cnf
/usr/bin/sed -i 's/^\[mysql\]/\[mysql\]\ndefault-character-set\ =\ utf8mb4\n/' /etc/my.cnf.d/mysql-clients.cnf
/bin/systemctl restart mariadb

/bin/mysql -e "CREATE DATABASE ${MOODLE_DBNAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
/bin/mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON ${MOODLE_DBNAME}.* TO '${MOODLE_USER}'@'${MOODLE_HOST}' IDENTIFIED BY '${MOODLE_PASS}';"

{
        /bin/echo "moodle admin password is: ${MOODLE_ADMIN_PW}"
        /bin/echo "Configuring MARIADB/MYSQL - root password is ${MOODLE_ROOT_PW}"
        /bin/mysqladmin -u root password ${MOODLE_ROOT_PW}
} | /bin/perl -pe 's/\e\[?.*?[\@-~]//g' | /bin/mutt -s "MYSQL/MARIADB - root credentials - SAVE" root@localhost

/usr/bin/mkdir /var/moodle

expect << EOD
set timeout 600
spawn /usr/bin/php /var/www/moodle/admin/cli/install.php
send_user "/usr/bin/php /var/www/moodle/admin/cli/install.php\n";
expect {
#  timeout       { send_user "TIME OUT\n"; exit 1 }
#  timeout { exp_continue }
#  eof { send_user "\ndone - perhaps\n" }
   "type y*" { send "y\r"; exp_continue }
   "Choose a language*" { send "\r"; exp_continue }
   "Data directories permission*" { send "\r"; exp_continue }
   "Web address*" { send "http://$(hostname)\r"; exp_continue }
   "Data directory*" { send "/var/moodle\r"; exp_continue }
   "Choose database driver*" { send "mysqli\r"; exp_continue }
   "Database host*" { send "localhost\r"; exp_continue }
   "Database name*" { send "moodle\r"; exp_continue }
   "Tables prefix*" { send "\r"; exp_continue }
   "Database port*" { send "\r"; exp_continue }
   "Unix socket*" { send "\r"; exp_continue }
   "Database user*" { send "moodle\r"; exp_continue }
   "Database password*" { send "${MOODLE_PASS}\r"; exp_continue }
   "Full site name*" { send "$(hostname)\r"; exp_continue }
   "Short name*" { send "$(hostname)\r"; exp_continue }
   "Admin account username*" { send "admin\r"; exp_continue }
   "New admin user password*" { send "${MOODLE_ADMIN_PW}\r"; exp_continue }
   "New admin user email address*" { send "${MOODLE_ADMIN_EMAIL}\r"; exp_continue }
   "Upgrade key*" { send "\r"; exp_continue }
}
EOD
