# Docker File for generate a linux container that can excute the zcheck and the zunit tests inside it
#
# To execute it install docker and then run 'docker build .'
#
FROM ubuntu

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" >> /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu precise-updates main universe" >> /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu precise-updates main universe" >> /etc/apt/sources.list
RUN echo "deb http://ppa.launchpad.net/zentyal/3.1/ubuntu precise main" >> /etc/apt/sources.list
RUN apt-get update

#Installing dependencies
RUN apt-get install -y --force-yes git sudo libapache2-mod-perl2
RUN apt-get install -y --force-yes libyaml-libyaml-perl libtest-mockmodule-perl libtest-mockobject-perl libtest-differences-perl libtest-file-perl libtest-mocktime-perl libtest-tester-perl libtest-cmd-perl libtest-output-perl libtest-class-perl libdir-self-perl

# Checking out the zentyal repo
RUN git clone https://github.com/Zentyal/zentyal.git
RUN cd zentyal && git checkout master

RUN /zentyal/extra/scripts/zentyal-syntax-check --installdeps --path=/zentyal --release=precise

RUN useradd -m -p 12CsGd8FRcMSM testUser

