# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::FirewallLogHelper;

use base 'EBox::LogHelper';

use EBox::Gettext;

use constant FIREWALL_LOGFILE => '/var/log/syslog';
use constant TS_FORMAT        => '%b %e %H:%M:%S %Y';

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
    return [FIREWALL_LOGFILE];
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

    unless ($line =~ /^(\w+\s+\d+ \d\d:\d\d:\d\d) .*: \[.*\] zentyal-firewall (\w+) (.+)/) {
        return;
    }
    my $date = $1 . ' ' . (${[localtime(time)]}[5] + 1900);
    my $type = $2;
    my $rule = $3;

    my @pairs = grep (/=./, split(' ', $rule));
    my %fields = map { split('='); } @pairs;

    my %dataToInsert;
    my $timestamp = $self->_convertTimestamp($date, TS_FORMAT);
    $dataToInsert{timestamp} = $timestamp;
    $dataToInsert{event} = $type;

    my @fieldNames = qw(in out src dst proto spt dpt);
    for my $name (@fieldNames) {
        my $uName = uc ($name);
        if (exists $fields{$uName}) {
            $dataToInsert{'fw_' . $name} = $fields{$uName};
        } else {
            $dataToInsert{'fw_' . $name} = undef;
        }
    }

    $dbengine->insert('firewall', \%dataToInsert);
}

1;
