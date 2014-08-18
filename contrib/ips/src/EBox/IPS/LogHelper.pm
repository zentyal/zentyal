# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::IPS::LogHelper;

use base 'EBox::LogHelper';

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant SURICATA_LOGFILE => '/var/log/suricata/fast.log';

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: logFiles
#
#   This function must return the file or files to be read from.
#
# Returns:
#
#   array ref - containing the whole paths
#
sub logFiles
{
    return [SURICATA_LOGFILE];
}

# Method: processLine
#
#   This fucntion will be run every time a new line is recieved in
#   the associated file. You must parse the line, and generate
#   the messages which will be logged to ebox through an object
#   implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#   file - file name
#   line - string containing the log line
#   dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    # Example lines to parse:
    # 10/05/10-10:08:59.667372  [**] [1:2009187:4] ET WEB_CLIENT ACTIVEX iDefense COMRaider ActiveX Control Arbitrary File Deletion [**] [Classification: Web Application Attack] [Priority: 3] {TCP} xx.xx.232.144:80 -> 192.168.1.4:56068

    unless ($line =~ /^(\d\d)\/(\d\d)\/(\d\d\d\d)-(\d\d:\d\d:\d\d)\..* \[\*\*\] \[(.+)\] ?(?:\((.+)\))?:? (.+) \[\*\*\] ?(?:\[Classification: (.+)\])? \[Priority: (\d)\] \{(.+)\} (.+) -> (.+)/) {
        return;
    }
    my $month = $1;
    my $day = $2;
    my $year = $3;
    my $time = $4;
    my $id = $5;
    my $detector = $6;
    my $description = $7;
    my $classification = $8;
    if (defined $classification) {
        $description .= " ($classification)";
    }
    my $prio = $9;
    my $protocol = $10;
    my $source = $11;
    my $dest = $12;

    my $timestamp = $self->_convertTimestamp("$year-$month-$day $time", '%Y-%m-%d %T');

    my %dataToInsert;
    $dataToInsert{timestamp} = $timestamp;
    $dataToInsert{description} = $description;
    $dataToInsert{priority} = $prio;
    $dataToInsert{source} = $source;
    $dataToInsert{dest} = $dest;
    $dataToInsert{protocol} = $protocol;
    $dataToInsert{event} = 'alert';

    $dbengine->insert('ips_event', \%dataToInsert);
}

1;
