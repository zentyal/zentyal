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

package EBox::Squid::LogHelper;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant  SQUIDLOGFILE => '/var/log/squid/access.log';
use constant  DANSGUARDIANLOGFILE => '/var/log/dansguardian/access.log';

sub new 
{
        my $class = shift;
        my $self = {};
        bless($self, $class);
        return $self;
}

sub domain { 
        return 'ebox-squid';
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
	return [SQUIDLOGFILE, DANSGUARDIANLOGFILE];
}

# Method: processLine
#
#	This method will be run every time a new line is received in
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
	my ($self, $file, $line, $dbengine) = @_;
		
	my @fields = split (/\s+/, $line);
	
	if ($fields[2] eq '127.0.0.1') {
		return;
	}
	
	my $event;
	if ($fields[3] eq 'TCP_DENIED/403' and $file eq  DANSGUARDIANLOGFILE) {
		$event = 'filtered';
	} elsif ($fields[3] eq 'TCP_DENIED/403')  {
		$event = 'denied';
	} else {
		$event = 'accepted';
	}	
	

        my $time = localtime $fields[0];
        my $data = { 
            'timestamp' => $time, 
            'elapsed' => $fields[1], 
            'remotehost' => $fields[2], 
            'code' => $fields[3],
            'bytes' => $fields[4], 
            'method' => $fields[5],
            'url' => $fields[6], 
            'rfc931' => $fields[7],
            'peer' => $fields[8], 
            'mimetype' => $fields[9],
            'event' => $event
           };
	
        
	$dbengine->insert('access', $data);
}

1;
