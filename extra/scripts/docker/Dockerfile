# Docker File for generate a linux container that can excute to e zcheck and the zunit tests inside it
#
# To execute it install docker and then run 'docker build .'
#
FROM ubuntu:12.04

RUN echo "deb http://de.archive.ubuntu.com/ubuntu precise main universe" >> /etc/apt/sources.list
RUN echo "deb http://de.archive.ubuntu.com/ubuntu precise-updates main universe" >> /etc/apt/sources.list
RUN echo "deb http://de.archive.ubuntu.com/ubuntu precise-security main universe" >> /etc/apt/sources.list
RUN echo "deb http://ppa.launchpad.net/zentyal/3.0/ubuntu precise main" >> /etc/apt/sources.list
RUN apt-get update

#Installing basic dependencies
RUN apt-get install -y --force-yes git sudo libapache2-mod-perl2 libtap-formatter-junit-perl build-essential devscripts zbuildtools

# Checking out the zentyal repo
RUN git clone https://github.com/Zentyal/zentyal.git
RUN cd zentyal && git checkout 3.0
RUN cd zentyal && git pull origin 3.0

#Install the zentyal deps
RUN /zentyal/extra/scripts/zentyal-syntax-check --installdeps --path=/zentyal  --release=precise
RUN /zentyal/extra/scripts/zentyal-unit-tests nothing || /bin/true

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
RUN mkdir -p /zentyal-repo
