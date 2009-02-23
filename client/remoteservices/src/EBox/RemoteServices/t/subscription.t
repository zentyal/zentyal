#!/usr/bin/perl -w
#
# Copyright (C) 2008 Warp Networks S.L.
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

package main;

use warnings;
use strict;

###############
# Dependencies
###############
use English "-no_match_vars";

use EBox;
use EBox::RemoteServices::Subscription;

EBox::init();

my $subsServ = EBox::RemoteServices::Subscription->new(user => 'warp',
                                                     password => 'warp');

print 'Subscribing an eBox... ';
$subsServ->subscribeEBox('foobar');
print "[Done]$RS";
print 'Subscribing the same eBox... ';
$subsServ->subscribeEBox('foobar');
print "[Done]$RS";
print 'Deleting the stored data... ';
$subsServ->deleteData();
print "[Done]$RS";

1;
