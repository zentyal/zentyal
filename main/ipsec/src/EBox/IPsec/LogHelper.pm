# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::IPsec::LogHelper;

use base 'EBox::LogHelper';

use EBox::Gettext;

use constant TABLE_NAME => 'ipsec';

# Status of the IPsec connections
my %status;

# Constructor: new
#
#       Create the new Log helper.
#
# Returns:
#
#       <EBox::IPsec::LogHelper>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);

    return $self;
}

# Method: logFiles
#
#       This function must return the file or files to be read from.
#
# Returns:
#
#       array ref - containing the whole paths
#
# Overrides:
#
#       <EBox::LogObserver::logFiles>
#
sub logFiles
{
    return ['/var/log/syslog','/var/log/auth.log'];
}

# Method: processLine
#
#       This function will be run every time a new line is received in
#       the associated file. You must parse the line, and generate
#       the messages which will be logged to eBox through an object
#       implementing <EBox::AbstractLogger> interface.
#
# Parameters:
#
#       file - file name
#       line - string containing the log line
#       dbengine - An instance of class implemeting AbstractDBEngine interface
#
# Overrides:
#
#       <EBox::LogObserver::processLine>
#
sub processLine # (file, line, dbengine)
{
    my ($self, $file, $line, $dbengine) = @_;

    my ($month, $mday, $time, $host, $daemon, $msg) = split '\s+', $line, 6;

    if (($daemon =~ m/^ipsec.*/) or ($daemon =~ m/^pluto.*/)) {

        my $eventInfo = $self->_eventFromMsg($msg);
        defined $eventInfo or
            return undef;

        my $event  = $eventInfo->{name};
        my $tunnel = $eventInfo->{tunnel};

        my $year = ${[localtime(time)]}[5] + 1900;
        my $timestamp = $self->_convertTimestamp("$month $mday $time $year",
                                                 '%b %e %H:%M:%S %Y'
                                                 );

        my $dbRow = {
            timestamp  => $timestamp,
            event      => $event,
            tunnel     => $tunnel,
        };

        $dbengine->insert(TABLE_NAME, $dbRow);
    }
}

sub _eventFromMsg
{
    my ($self, $msg) = @_;

    if ($msg =~ qr {^...Openswan IPsec started$}) {
        return { name => 'initialized' };
    } elsif ($msg =~ qr {^...Openswan IPsec stopped$}) {
        return { name => 'stopped' };
    } elsif ($msg =~ qr {^"(.*?)"\s.*\sIPsec\sSA\sestablished\stunnel\smode\s.*$}x) {
        my $tunnel = $1;

        if ((not exists $status{$tunnel}) or ($status{$tunnel} eq 'connectionReset')) {
            $status{$tunnel} = 'connectionInitiated';
            return {
                    name => 'connectionInitiated',
                    tunnel   => $tunnel,
                   };
        } else {
            return undef;
        }
    } elsif (($msg =~ qr {^"(.*?)":\sdeleting\sconnection.*$}x) or
             ($msg =~ qr {^"(.*?)"\s.*\sIPsec\sSA\sexpired.*$}x)) {
        my $tunnel = $1;

        exists $status{$tunnel} or
            return undef;
        unless( $status{$tunnel} eq 'connectionInitiated' ) {
            return undef;
        }

        $status{$tunnel} = 'connectionReset';
        return {
                name => 'connectionReset',
                tunnel   => $tunnel,
               };
    }

    return undef;
}

1;
