#!/usr/bin/perl
#
# RabbitMQ client example to request the upgrade process from Exchange to OpenChange
#
# OpenChange Project
#
# Copyright (C) Zentyal SL 2013
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

$|++;
use AnyEvent;
use Net::RabbitFoot;

my $conn = Net::RabbitFoot->new()->load_xml_spec()->connect(
    host => 'localhost',
    port => 5672,
    user => 'guest',
    pass => 'guest',
    vhost => '/',
);

my $channel = $conn->open_channel();

$channel->declare_exchange(
    exchange => 'openchange_upgrade_calculation',
    type => 'fanout',
);

my $result = $channel->declare_queue( exclusive => 1, );

my $queue_name = $result->{method_frame}->{queue};

$channel->bind_queue(
    exchange => 'openchange_upgrade_calculation',
    queue => $queue_name,
);

print " [*] Waiting for info. To exit press CTRL-C\n";

sub callback {
    my $var = shift;
    my $body = $var->{body}->{payload};

    print " [x] $body\n";
}

$channel->consume(
    on_consume => \&callback,
    queue => $queue_name,
    no_ack => 1,
);

AnyEvent->condvar->recv;
