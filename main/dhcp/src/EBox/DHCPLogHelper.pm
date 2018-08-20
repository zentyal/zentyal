# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::DHCPLogHelper;

use base 'EBox::LogHelper';

use EBox::Gettext;

use constant DHCPLOGFILE => '/var/log/syslog';

sub new
{
    my $class = shift;
    my $self = {};
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
sub logFiles
{
    return [DHCPLOGFILE];
}

# Method: processLine
#
#       This fucntion will be run every time a new line is recieved in
#       the associated file. You must parse the line, and generate
#       the messages which will be logged to ebox through an object
#       implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#       file - file name
#       line - string containing the log line
#       dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    return unless ($line =~ /^(\w+\s+\d+ \d\d:\d\d:\d\d) \S+ dhcpd\[\d+\]:.*/);

    my $date = $1 . ' ' . (${[localtime(time)]}[5] + 1900);
    my ($ip, $mac, $iface, $event);
    if ($line =~ /^.*DHCPACK on ([\d.]+) to ([\d:a-f]{17}).*?via (\w+)/) {
        $ip = $1;
        $mac = $2;
        $iface =$3;
        $event = 'leased';
    } elsif ($line =~ /^.*DHCPRELEASE of ([\d.]+) from ([\d:a-f]{17}).*?via (\w+)/) {
        $ip = $1;
        $mac = $2;
        $iface =$3;
        $event = 'released';
    } else {
        return;
    }

    my $timestamp = $self->_convertTimestamp($date, '%b %e %H:%M:%S %Y');
    my $data = {
        'timestamp' => $timestamp,
        'ip' => $ip,
        'mac' => $mac,
        'interface' => $iface,
        'event' => $event
    };
    $dbengine->insert('leases', $data);
}

1;
