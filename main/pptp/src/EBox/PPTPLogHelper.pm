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

package EBox::PPTPLogHelper;

use base 'EBox::LogHelper';

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant LOGFILE => '/var/log/syslog';
use constant TABLE_NAME => 'pptp';

# Constructor: new
#
#       Create the new Log helper.
#
# Returns:
#
#       <EBox::PPTPLogHelper> - the recently created model.
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
#       array ref - containing the whole paths.
#
# Overrides:
#
#       <EBox::LogObserver::logFiles>
#
sub logFiles
{
    return [LOGFILE];
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
    my $year = ${[localtime(time)]}[5] + 1900;

    if ($daemon =~ m/^pptpd.*/) {

        my $eventInfo = $self->_eventFromMsg($msg);
        if (not defined $eventInfo) {
            return;
        }

        my $event  = $eventInfo->{name};
        my $fromIp = $eventInfo->{fromIp};

        my $timestamp = $self->_convertTimestamp("$month $mday $time $year", '%b %e %H:%M:%S %Y');

        my $dbRow = {
            timestamp  => $timestamp,
            event      => $event,
            from_ip    => $fromIp,
        };

        $dbengine->insert(TABLE_NAME, $dbRow);
    }
}

my %callbackByRe = (
    qr {^MGR: Manager process started$} =>\&_startedEvent,
    qr {
        ^CTRL:\sClient\s
        ([\d\.]+?)\s                    # client ip
        control\sconnection\sstarted$
    }x =>\&_startConnection,
    qr {
        ^CTRL:\sClient\s
        ([\d\.]+?)\s                    # client ip
        control\sconnection\sfinished$
    }x =>\&_stopConnection,
);

sub _eventFromMsg
{
    my ($self, $msg) = @_;

    foreach my $re (keys %callbackByRe) {
        if ($msg =~ $re) {
            return $callbackByRe{$re}->($msg);
        }
    }

    return undef;
}

sub _startedEvent
{
    return { name => 'initialized' };
}

sub _startConnection
{
    my $ip = $1;

    return {
            name => 'connectionInitiated',
            fromIp   => $ip,
           }
}

sub _stopConnection
{
    my $ip = $1;

    return {
            name => 'connectionReset',
            fromIp   => $ip,
           }
}

1;
