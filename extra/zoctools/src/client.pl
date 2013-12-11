#!/usr/bin/perl
#
# RabbitMQ client example to request the upgrade process from Exchange to
# OpenChange
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

#$|++;
use AnyEvent;
use Net::RabbitFoot;
use UUID::Tiny;

#my $conn = Net::RabbitFoot->new()->load_xml_spec()->connect(
#        host => 'localhost',
#        port => 5672,
#        user => 'guest',
#        pass => 'guest',
#        vhost => '/',
#        );
#
my $queue_name = 'Zentyal.OpenChange.Migrate.Control';
#my $channel = $conn->open_channel();
#$channel->publish(
#        exchange => '',
#        routing_key => $queue_name,
#        body => "{\"command\": 0}");


sub send_command
{
    my $command = shift;
    my $cv = AnyEvent->condvar;
    my $corr_id = UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V4);

    my $conn = Net::RabbitFoot->new()->load_xml_spec()->connect(
        host => 'localhost',
        port => 5672,
        user => 'guest',
        pass => 'guest',
        vhost => '/',
    );

    my $channel = $conn->open_channel();

    my $result = $channel->declare_queue(exclusive => 1);
    my $response_queue = $result->{method_frame}->{queue};

    sub on_response {
        my $var = shift;
        my $body = $var->{body}->{payload};
        if ($corr_id eq $var->{header}->{correlation_id}) {
            $cv->send($body);
        }
    }

    $channel->consume(
        no_ack => 1,
        on_consume => \&on_response,
    );

    $channel->publish(
        exchange => '',
        routing_key => $queue_name,
        header => {
            reply_to => $response_queue,
            correlation_id => $corr_id,
        },
        #body => "{\"command\": 0}",
        #body => "{\"command\": 2, \"users\": [ { \"name\": \"user1\" }, { \"name\": \"user2\" }, { \"name\": \"user3\" }, { \"name\": \"user4\" }, { \"name\": \"user5\" } ] }",
        body => $command,
    );
    return $cv->recv;
}

my $command = $ARGV[0];
print " [x] Sending command '$command'\n";
my $response = send_command($command);
print " [.] Got $response\n";
