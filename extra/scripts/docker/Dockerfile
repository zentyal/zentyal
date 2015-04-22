# Docker File for generate a linux container that can excute to e zcheck and the zunit tests inside it
#
# To execute it install docker and then run 'docker build .'
#
FROM ubuntu:14.04

RUN echo "deb http://de.archive.ubuntu.com/ubuntu trusty main universe" >> /etc/apt/sources.list
RUN echo "deb http://de.archive.ubuntu.com/ubuntu trusty-updates main universe" >> /etc/apt/sources.list
RUN echo "deb http://de.archive.ubuntu.com/ubuntu trusty-security main universe" >> /etc/apt/sources.list
RUN echo "deb http://archive.zentyal.org/zentyal/ 4.1 main extra" >> /etc/apt/sources.list
RUN apt-get update -y

#Installing basic and build dependencies
RUN apt-get install -y --force-yes git sudo libapache2-mod-perl2 libtap-formatter-junit-perl build-essential devscripts zbuildtools apt-utils

# ADD zentyal-syntax-check and zentyal-unit-tests
ADD extra/scripts/zentyal-syntax-check /tmp/zentyal-syntax-check
ADD extra/scripts/zentyal-unit-tests /tmp/zentyal-unit-tests

#ADD conf files for check and unit tests
ADD main/common/conf/zentyal.conf /tmp/main/common/conf/zentyal.conf
ADD main/common/extra/eboxlog.conf /tmp/main/common/extra/eboxlog.conf

#ADD control files to check the dependencies
ADD  main/firewall/debian/control /tmp/main/firewall/debian/control
ADD  main/mailfilter/debian/control /tmp/main/mailfilter/debian/control
ADD  main/services/debian/control /tmp/main/services/debian/control
ADD  main/antivirus/debian/control /tmp/main/antivirus/debian/control
ADD  main/ntp/debian/control /tmp/main/ntp/debian/control
ADD  main/dhcp/debian/control /tmp/main/dhcp/debian/control
ADD  main/software/debian/control /tmp/main/software/debian/control
ADD  main/objects/debian/control /tmp/main/objects/debian/control
ADD  main/mail/debian/control /tmp/main/mail/debian/control
ADD  main/openchange/debian/control /tmp/main/openchange/debian/control
ADD  main/core/debian/control /tmp/main/core/debian/control
ADD  main/openvpn/debian/control /tmp/main/openvpn/debian/control
ADD  main/samba/debian/control /tmp/main/samba/debian/control
ADD  main/dns/debian/control /tmp/main/dns/debian/control
ADD  main/ca/debian/control /tmp/main/ca/debian/control
ADD  main/printers/debian/control /tmp/main/printers/debian/control
ADD  main/common/debian/control /tmp/main/common/debian/control
ADD  main/network/debian/control /tmp/main/network/debian/control

#Install the zentyal deps
RUN apt-get update -y
RUN /tmp/zentyal-syntax-check --installdeps --path=/tmp  --release=precise
RUN /tmp/zentyal-unit-tests nothing || /bin/true

#Add the user that will run the unit tests
RUN useradd -m -p 12CsGd8FRcMSM testUser
RUN echo 'testUser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Give special permissions to some files
RUN mkdir -p /run/shm/zentyal
RUN chmod 777 /run/shm/zentyal
RUN chmod 4755 /usr/bin/sudo

# Configure timezoen so the tests get the date expected
RUN  echo "Europe/Madrid" > /etc/timezone
RUN  dpkg-reconfigure -f noninteractive tzdata

# Adding empty folder for the repo to be linked
VOLUME ["/zentyal-repo"]
