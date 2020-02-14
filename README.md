# zabbix_smartctl
Monitoring via smartmontools

INSTALL

apt-get update
apt-get install sudo zabbix-agent libjson-perl smartmontools

COPY zabbix_smart.pl to dir /usr/local/bin

RUN:
chmod +x /usr/local/bin/zabbix_smart.pl
/usr/local/bin/zabbix_smart.pl install

IMPORT template template.xml to zabbix (my zabbix version Zabbix 4.4.0alpha1)
