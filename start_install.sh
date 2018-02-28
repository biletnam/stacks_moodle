#!/bin/bash
: '
#cloud-config
package_upgrade: false

packages:
- epel-release
- firewalld
- wget
- httpd
- mailx
- mutt
- policycoreutils-python
- libselinux-python
- libsemanage-python
- setroubleshooting

runcmd:
- yum -y install ansible
- printf "127.0.0.1 localhost host host.example.com\n" > /etc/hosts
- printf "[moodle_server]\nhost.example.com\tansible_connection=local\n" >> /etc/ansible/hosts
- printf "host_key_checking = False\n" >> /etc/ansible/ansible.cfg
- cd /var/www
- wget https://download.moodle.org/download.php/direct/stable34/moodle-latest-34.tgz
- tar xzvf moodle-latest-34.tgz
- rm -f moodle-latest-34.tgz
- mkdir /tmp/playbook
- cd /tmp/playbook
- wget https://github.com/myENA/stacks_moodle/archive/master.tar.gz
- tar zxvfp master.tar.gz
- cd stacks_moodle-master
- hostnamectl set-hostname {{moodlehost}}
- export MOODLE_ADMIN_MAIL="{{adminemail}}"
- sh start_install.sh
'

ansible-playbook main.yml

/usr/bin/echo "After logging in, check Email as the Root user for DB credentials"

# open firewall
/usr/bin/firewall-offline-cmd --add-service=http
/usr/bin/firewall-offline-cmd --add-service=https
/bin/systemctl enable firewalld
/bin/systemctl start firewalld
/bin/find /var/www/moodle -exec chown root:root {} \;
/bin/find /var/www/moodle -type d -exec chmod 755 {} \;
/bin/find /var/www/moodle -type f -exec chmod 644 {} \;
/bin/find /var/moodle -exec chown apache:apache {} \;
/bin/find /var/moodle -type d -exec chmod 700 {} \;
/bin/find /var/moodle -type f -exec chmod 600 {} \;
/bin/chcon -R --type=httpd_sys_rw_content_t /var/www/moodle/
/bin/chcon -R --type=httpd_sys_rw_content_t /var/moodle/
/sbin/reboot
