# Copyright (C) 2005 Warp Netwoks S.L.

# Class: EBox::PrinterLogHelper;
package EBox::PrinterLogHelper;

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;

use constant CUPSLOGFILE => '/var/log/cups/error_log';

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

	
	unless ($line =~ /^.*\[([^ ]+) .*\] Job (\d+) queued on '(\w+)' by '(\w+)'.*/) {
		return;
	}

	my $data = { 'timestamp' => $1, 'job' => $2, 
		     'printer' => $3, 'owner' => $4 };
	$dbengine->insert('jobs', $data);
	
}

1;
