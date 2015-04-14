# Docker File for generate a linux container that can excute to e zcheck and the zunit tests inside it
#
# To execute it install docker and then run 'docker build .'
#
FROM ubuntu:12.04

RUN echo "deb http://de.archive.ubuntu.com/ubuntu precise main universe" >> /etc/apt/sources.list
RUN echo "deb http://de.archive.ubuntu.com/ubuntu precise-updates main universe" >> /etc/apt/sources.list
RUN echo "deb http://de.archive.ubuntu.com/ubuntu precise-security main universe" >> /etc/apt/sources.list
RUN echo "deb http://ppa.launchpad.net/zentyal/3.0/ubuntu precise main" >> /etc/apt/sources.list
RUN echo "deb http://archive.zentyal.org/zentyal-beta 3.0-proposed main" >> /etc/apt/sources.list
RUN apt-get update -y

#Installing basic and build dependencies
RUN apt-get install -y --force-yes git sudo libapache2-mod-perl2 libtap-formatter-junit-perl build-essential devscripts zbuildtools apt-utils

# ADD zentyal-syntax-check and zentyal-unit-tests
ADD extra/scripts/zentyal-syntax-check /tmp/zentyal-syntax-check
ADD extra/scripts/zentyal-unit-tests /tmp/zentyal-unit-tests

#ADD conf files for check and unit tests
ADD main/common/conf/zentyal.conf /tmp/main/common/conf/zentyal.conf
ADD main/common/extra/eboxlog.conf /tmp/main/common/extra/eboxlog.conf
ADD main/captiveportal/extra/captiveportal-log.conf /tmp/main/captiveportal/extra/captiveportal-log.conf

#ADD control files to check the dependencies
ADD  main/firewall/debian/precise/control /tmp/main/firewall/debian/precise/control
ADD  main/ftp/debian/precise/control /tmp/main/ftp/debian/precise/control
ADD  main/mailfilter/debian/precise/control /tmp/main/mailfilter/debian/precise/control
ADD  main/services/debian/precise/control /tmp/main/services/debian/precise/control
ADD  main/antivirus/debian/precise/control /tmp/main/antivirus/debian/precise/control
ADD  main/ntp/debian/precise/control /tmp/main/ntp/debian/precise/control
ADD  main/captiveportal/debian/precise/control /tmp/main/captiveportal/debian/precise/control
ADD  main/ipsec/debian/precise/control /tmp/main/ipsec/debian/precise/control
ADD  main/dhcp/debian/precise/control /tmp/main/dhcp/debian/precise/control
ADD  main/usercorner/debian/precise/control /tmp/main/usercorner/debian/precise/control
ADD  main/zarafa/debian/precise/control /tmp/main/zarafa/debian/precise/control
ADD  main/software/debian/precise/control /tmp/main/software/debian/precise/control
ADD  main/objects/debian/precise/control /tmp/main/objects/debian/precise/control
ADD  main/webserver/debian/precise/control /tmp/main/webserver/debian/precise/control
ADD  main/users/debian/precise/control /tmp/main/users/debian/precise/control
ADD  main/bwmonitor/debian/precise/control /tmp/main/bwmonitor/debian/precise/control
ADD  main/jabber/debian/precise/control /tmp/main/jabber/debian/precise/control
ADD  main/mail/debian/precise/control /tmp/main/mail/debian/precise/control
ADD  main/trafficshaping/debian/precise/control /tmp/main/trafficshaping/debian/precise/control
ADD  main/core/debian/precise/control /tmp/main/core/debian/precise/control
ADD  main/monitor/debian/precise/control /tmp/main/monitor/debian/precise/control
ADD  main/openvpn/debian/precise/control /tmp/main/openvpn/debian/precise/control
ADD  main/l7-protocols/debian/precise/control /tmp/main/l7-protocols/debian/precise/control
ADD  main/squid/debian/precise/control /tmp/main/squid/debian/precise/control
ADD  main/samba/debian/precise/control /tmp/main/samba/debian/precise/control
ADD  main/dns/debian/precise/control /tmp/main/dns/debian/precise/control
ADD  main/ca/debian/precise/control /tmp/main/ca/debian/precise/control
ADD  main/nut/debian/precise/control /tmp/main/nut/debian/precise/control
ADD  main/printers/debian/precise/control /tmp/main/printers/debian/precise/control
ADD  main/ebackup/debian/precise/control /tmp/main/ebackup/debian/precise/control
ADD  main/webmail/debian/precise/control /tmp/main/webmail/debian/precise/control
ADD  main/common/debian/precise/control /tmp/main/common/debian/precise/control
ADD  main/radius/debian/precise/control /tmp/main/radius/debian/precise/control
ADD  main/ips/debian/precise/control /tmp/main/ips/debian/precise/control
ADD  main/ids/debian/precise/control /tmp/main/ids/debian/precise/control
ADD  main/network/debian/precise/control /tmp/main/network/debian/precise/control
ADD  main/remoteservices/debian/precise/control /tmp/main/remoteservices/debian/precise/control
ADD  main/ltsp/debian/precise/control /tmp/main/ltsp/debian/precise/control
ADD  main/virt/debian/precise/control /tmp/main/virt/debian/precise/control

#Install the zentyal deps
RUN /tmp/zentyal-syntax-check --installdeps --path=/tmp  --release=precise
RUN /tmp/zentyal-unit-tests nothing || /bin/true

#Add the user that will run the unit tests
RUN useradd -m -p 12CsGd8FRcMSM testUser
RUN echo 'testUser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Give special permissions to some files
RUN mkdir -p /run/shm/zentyal
RUN chmod 777 /run/shm/zentyal

# Configure timezoen so the tests get the date expected
RUN  echo "Europe/Madrid" > /etc/timezone
RUN  dpkg-reconfigure -f noninteractive tzdata

# Adding empty folder for the repo to be linked
VOLUME ["/zentyal-repo"]
