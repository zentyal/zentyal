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

# Class: EBox::OpenVPN::LogHelper;
package EBox::OpenVPN::LogHelper;
use base 'EBox::LogHelper';

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;


use constant TABLE_NAME => 'openvpn';

sub new 
{
  my ($class, $openvpn) = @_;

  my $self = $class->SUPER::new(@_);
  $self->{openvpn} = $openvpn;

  bless($self, $class);
  $self->_populateLogFiles;

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
# XXX this implementation must be deleted if #848 is fixed and replaced with the
# contents of _logFile method
sub logFiles
{
  my ($self) = @_;

  my $logFilesScript =<<'END';
        use strict;
        use warnings;
        use EBox;
        use EBox::Global; 
  
        EBox::init();
        my $openvpn = EBox::Global->modInstance("openvpn");
        my $logHelper = $openvpn->logHelper();
        my @logFiles = @{ $logHelper->_logFiles  };

        print "@logFiles";
       1;
END

  my @output = `perl -e '$logFilesScript'`;
  my $logFilesLine = shift @output;

  my @logFiles =  split '\s', $logFilesLine;
  return \@logFiles;
}

# XXX  if #848 is fixed this must be logFiles
sub _logFiles
{
  my ($self) = @_;
  my @logFiles =  keys %{ $self->{logFiles}  };
  return   \@logFiles;	
}



sub _populateLogFiles
{
  my ($self) = @_;
  my %logFiles;

  foreach my $daemon ($self->{openvpn}->daemons) {
    next if not $daemon->service;

    my $file = $daemon->logFile;
    my $name = $daemon->name;
    my $type = $daemon->type;

    $logFiles{$file} = {
			name => $name,
			type => $type,
		       };
    
  }

  $self->{logFiles} = \%logFiles;
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
  my ($self, $file, $line, $dbengine) = @_;

  my ($wday, $month, $mday, $time, $year, $msg) = split '\s', $line, 6;


  my $eventInfo = $self->_eventFromMsg($msg);
  if (not defined $eventInfo) {
    return;
  }
  

  my $event  = $eventInfo->{name};

 
  my $daemon = $self->{logFiles}->{$file};
  my $name   = $daemon->{name};
  my $type   = $daemon->{type};

  my $timestamp = join (' ', $wday, $month, $mday, $time, $year);
  


  my $data = {
	      timestamp  => $timestamp,
	      daemonName => $name,
	      daemonType => $type,
	      event      => $event,
	     };
  


  $dbengine->insert(TABLE_NAME, $data);
}






sub _eventFromMsg 
{
  my ($self, $msg) = @_;

  # XXX reimplement with qr table

  if ($msg eq 'Initialization Sequence Completed') {
    return { name => 'started' } ;
  }

  return undef;
}

1;
