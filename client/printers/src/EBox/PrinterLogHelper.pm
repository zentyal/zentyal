# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

# Class: EBox::PrinterLogHelper;
package EBox::PrinterLogHelper;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant CUPSLOGFILE => '/var/log/cups/page_log';

sub new 
{
        my $class = shift;
        my $self = {};
        bless($self, $class);
        return $self;
}

sub domain { 
        return 'ebox-printers';
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
	return [CUPSLOGFILE];	
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
# 	line - string containing the log line
#	dbengine- An instance of class implemeting AbstractDBEngineinterface
# 	
sub processLine # (file, line, logger) 
{
	my ($self, $file, $line, $dbengine, $event) = @_;

	unless ($line =~ /^(\w+) (\w+) (\d+) \[([^ ]+) .*\] .*/) {
		return;
	}

	my $data = { 'timestamp' => $4, 'job' => $3, 
		     'printer' => $1, 'owner' => $2,
		     'event' => 'queued' };
	$dbengine->insert('jobs', $data);
	
}

1;
