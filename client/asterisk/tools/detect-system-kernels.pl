#!/usr/bin/perl

use strict;

my @headers = ();

if (`dpkg -l | grep linux-image-server`) {
    push(@headers, 'linux-headers-server');
}

if (`dpkg -l | grep linux-image-virtual`) {
    push(@headers, 'linux-headers-virtual');
}

if (`dpkg -l | grep linux-image-ec2`) {
    push(@headers, 'linux-headers-ec2');
}

if (`dpkg -l | grep linux-image-386`) {
    push(@headers, 'linux-headers-386');
}

if (`dpkg -l | grep linux-image-generic`) {
    push(@headers, 'linux-headers-generic');
}

if (`dpkg -l | grep linux-image-generic-pae`) {
    push(@headers, 'linux-headers-generic-pae');
}

print "@headers\n";
