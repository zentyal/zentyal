# Copyright (C) 2013 Zentyal S.L.
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
use warnings;

package EBox::OpenChange::MigrationRPCClient;

use AnyEvent;
use Net::RabbitFoot;
use UUID::Tiny;
use JSON;

use constant RPC_COMMAND_STATUS    => 1;
use constant RPC_COMMAND_EXIT      => 2;
use constant RPC_COMMAND_CANCEL    => 3;
use constant RPC_COMMAND_CONNECT   => 4;
use constant RPC_COMMAND_GET_USERS => 5;
use constant RPC_COMMAND_SET_USERS => 6;
use constant RPC_COMMAND_ESTIMATE  => 7;
use constant RPC_COMMAND_EXPORT    => 8;
use constant RPC_COMMAND_IMPORT    => 9;

use constant RPC_STATE_IDLE       => 0;
use constant RPC_STATE_ESTIMATING => 1;
use constant RPC_STATE_ESTIMATED  => 2;
use constant RPC_STATE_EXPORTING  => 3;
use constant RPC_STATE_EXPORTED   => 4;
use constant RPC_STATE_IMPORTING  => 5;
use constant RPC_STATE_IMPORTED   => 6;

my $_instance = undef;

sub _new_instance
{
    my $class = shift;
    my $self = {};
    bless ($self, $class);

    $self->{conn} = Net::RabbitFoot->new()->load_xml_spec()->connect(
        host => 'localhost',
        port => 5672,
        user => 'guest',
        pass => 'guest',
        vhost => '/',
    );

    $self->{queue_name} = 'Zentyal.OpenChange.Migrate.Control';
    $self->{channel} = $self->{conn}->open_channel();

    my $result = $self->{channel}->declare_queue(exclusive => 1);
    $self->{response_queue} = $result->{method_frame}->{queue};

    return $self;
}

sub new
{
    my $class = shift;

    unless (defined $_instance) {
        $_instance = $class->_new_instance();
    }
    return $_instance;
}

my $timer;
my $cv;
my $corr_id;
my $response;

sub on_response {
    my $var = shift;

    my $body = $var->{body}->{payload};
    my $msg_corr_id = $var->{header}->{correlation_id};

    if ($corr_id eq $msg_corr_id) {
        $body = decode_json($body);
        $cv->send($body);
    } else {
        $cv->send();
    }
    undef $timer;
}

sub send_command
{
    my ($self, $command) = @_;

    $timer = undef;
    $response = undef;
    $corr_id = UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V4);
    $cv = AnyEvent->condvar;

    $self->{channel}->consume(
        no_ack => 1,
        on_consume => \&on_response,
    );

    $self->{channel}->publish(
        exchange => '',
        routing_key => $self->{queue_name},
        header => {
            reply_to => $self->{response_queue},
            correlation_id => $corr_id,
        },
        body => encode_json($command),
    );

    $timer = AnyEvent->timer( after => 10, cb => sub {
        EBox::error("Command timed out!");
        $cv->send();
    });

    return $cv->recv;
}

sub dump
{
    my ($self, $c) = @_;

    use Data::Dumper;
    EBox::info(Dumper($c));
}

1;
