#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

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
