# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::IDSLogHelper;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant SNORT_LOGFILE => '/var/log/snort/alert';

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub domain
{
    return 'ebox-ids';
}


# Method: logFiles
#
#	This function must return the file or files to be read from.
#
# Returns:
#
#	array ref - containing the whole paths
#
sub logFiles
{
    return [SNORT_LOGFILE];
}

# Method: processLine
#
#	This fucntion will be run every time a new line is recieved in
#	the associated file. You must parse the line, and generate
#	the messages which will be logged to ebox through an object
#	implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#	file - file name
#	line - string containing the log line
#	dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
	my ($self, $file, $line, $dbengine) = @_;

    # Example lines to parse:
    # 04/23-21:49:17.163791  [**] [116:150:1] (snort decoder) Bad Traffic Loopback IP [**] [Priority: 3] {TCP} 127.0.1.1:5100 -> 69.89.31.56:640
    # 04/24-11:45:18.441639  [**] [122:1:0] (portscan) TCP Portscan [**] [Priority: 3] {PROTO:255} 10.6.7.1 -> 10.6.7.10
    # 05/31-20:23:27.212634  [**] [1:1390:5] SHELLCODE x86 inc ebx NOOP [**] [Classification: Executable code was detected] [Priority: 1] {UDP} 192.168.122.1:41190 -> 192.168.122.177:41111

	unless ($line =~ /^(\d\d)\/(\d\d)-(\d\d:\d\d:\d\d)\..* \[\*\*\] \[(.+)\] ?(?:\((.+)\))? (.+) \[\*\*\] ?(?:\[Classification: (.+)\])? \[Priority: (\d)\] \{(.+)\} (.+) -> (.+)/) {
	    return;
	}
	my $monthNum = $1;
    my $day = $2;
    my $time = $3;
	my $id = $4;
	my $detector = $5;
    my $description = $6;
    my $classification = $7;
    if (defined $classification) {
        $description .= " ($classification)";
    }
    my $prio = $8;
    my $protocol = $9;
    my $source = $10;
    my $dest = $11;

    my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
    my $month = $months[$monthNum - 1];
    my $year = (${[localtime(time)]}[5] + 1900);
	my $timestamp = "$month $day $time $year";

	my %dataToInsert;
	$dataToInsert{timestamp} = $timestamp;
	$dataToInsert{description} = $description;
    $dataToInsert{priority} = $prio;
    $dataToInsert{source} = $source;
    $dataToInsert{dest} = $dest;
    $dataToInsert{protocol} = $protocol;
    $dataToInsert{event} = 'alert';

	$dbengine->insert('ids', \%dataToInsert);
}

1;
