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

use Data::Dumper; # XXX remove if #848 is solved


use constant TABLE_NAME => 'openvpn';

sub new 
{
  my ($class, $openvpn, %params) = @_;

  my $self = $class->SUPER::new(@_);
  $self->{openvpn} = $openvpn;

  bless($self, $class);


  # XXX when #848 is solved remove the conditional; and always call
  # _populateLogFiles 
  unless ($params{noPopulate}) { 
    $self->_populateLogFiles;
  }



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
  my ($self) = @_;
  my @logFiles =  keys %{ $self->{logFiles}  };
  return   \@logFiles;	
}



sub _populateLogFiles
{
  my ($self) = @_;

# XXX  comment out if #848 is solved
#   $self->{logFiles} = $self->_logFilesFromDaemons;

# XXX this  must be deleted if #848 is fixed 
  my $script = $self->_populateScript;
  my $output = EBox::Sudo::root($script);

  my $VAR1;
  eval $output->[0];

  $self->{logFiles} = $VAR1;

}



sub _logFilesFromDaemons
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

  return \%logFiles;

}
# XXX this  must be deleted if #848 is fixed 
sub _populateScript
{
  my $script =<<'END'; 
    use strict;
    use warnings;
    use EBox;
    use EBox::Global; 
  
     EBox::init();
    my $openvpn = EBox::Global->modInstance("openvpn");
    my $logHelper = $openvpn->logHelper(noPopulate => 1);
    $logHelper->_dumpLogFiles();
     1;
END

  my $cmd = qq{perl -e '$script'};
  return $cmd;
}

# XXX this  must be deleted if #848 is fixed 
sub _dumpLogFiles
{
  my ($self) = @_;

  my $logFiles = $self->_logFilesFromDaemons();

  my $dumper = new Data::Dumper( [$logFiles] );
  $dumper->Indent(0);

  print $dumper->Dump;
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
  

  my $event   = $eventInfo->{name};
  my $fromIp = $eventInfo->{fromIp};
  my $fromCert = $eventInfo->{fromCert};
  my $extraInfo = $eventInfo->{extraInfo};

 
  my $daemon = $self->{logFiles}->{$file};
  my $name   = $daemon->{name};
  my $type   = $daemon->{type};

  my $timestamp = join (' ', $wday, $month, $mday, $time, $year);
  




  my $dbRow = {
	      timestamp  => $timestamp,
	      event      => $event,
	      daemon_name => $name,
	      daemon_type => $type,
	      from_ip     => $fromIp,
	      from_cert     => $fromCert,
	     };
  


  $dbengine->insert(TABLE_NAME, $dbRow);
}


my %callbackByRe = (
		    qr{^Initialization Sequence Completed$} => 
		    \&_startedEvent,

		    qr{
                       ^([\d\.]+?):\d+\s        # client ip:port
                        VERIFY\s([\w\s]+):\s   # VERIFY [status]:
                       (.*)$                   #  more information (containst the client's certificatw)
                     }x   =>
		    \&_verifiyEvent,

		    qr{
                           ^[\d\.]+:\d+\s    # client ip and port
                           \[(.*?)\]\s       # client certificate CN
                           Peer\sConnection\sInitiated\swith\s
                           ([\d\.]+?):\d+$    # client ip and port (we will use this instead of the first)

                    }x => 
		    \&_peerConnectionEvent,


		    qr{
                           \[(.*?)\]\s       # server certificate CN
                           Peer\sConnection\sInitiated\swith\s
                           ([\d\.]+?):\d+$    # server ip and port (we will use this instead of the first)

                    }x => 
		    \&_peerServerConnectionEvent,

		    qr{
                        ^(.*?)/(.*?):\d+\s #[client cn]/[ip]:[port]
                       Connection\sreset,\srestarting.*$
                     }x => 
		    \&_connectionResetEvent,
		   
		    qr{
                       ^Connection\sreset,\srestarting.*$
                     }x => 
		    \&_connectionResetByServerEvent,
		     


		   );



sub _eventFromMsg 
{
  my ($self, $msg) = @_;

  foreach my $re (keys %callbackByRe) {
    if ($msg =~ $re) {
      return $callbackByRe{$re}->($msg);
    }
  }

#   # XXX reimplement with qr table

#   if ($msg eq 'Initialization Sequence Completed') {
#     return { name => 'started' } ;
#   }
#   elsif ($msg =~ m{}) {
#   }

  return undef;
}


sub _startedEvent
{
  return { name => 'initialized' } ;
}



sub _verifiyEvent
{
  my $ip     = $1;
  my $status = $2;
  my $extraInfo = $3;

  my $cert   = undef;

  my $event;
  if ($status eq 'OK') {
    # we ignore the verification ok event for now
    return undef;
  }
  elsif ($status eq 'X509NAME ERROR' ) {
    $event = 'verificationNameError';
    ($cert) = split ',', $extraInfo, 2; # in this case extraInfo contains: [certificate],
                                   # [advice]
    }
  elsif ($status =~ /ERROR/) {
    if ($extraInfo =~ m/error=unable to get local issuer certificate: (.*)$/) {
      $event = 'verificationIssuerError';
      $cert = $1;
    }
    else {
      $event = 'verificationError';
      # try to guess the certificate. No garantee
      if ($extraInfo =~ m/\s([^\s]*?CN=[^\s]*?)[\s,.]|$/) {
	$cert = $1;
      }
    }
  }
  else {
    EBox::error("unknown openvpn verification status: $status");
    return undef;
  }
  

  return {
	  name => $event,
	  fromCert => $cert,
	  fromIp => $ip,

	 };
  
}


sub _peerConnectionEvent
{
  my $cn = $1;
  my $ip = $2;

  return {
	  name => 'connectionInitiated',
	  fromCert => $cn,
	  fromIp   => $ip,
	 }

}


sub _peerServerConnectionEvent
{
  my $cn = $1;
  my $ip = $2;

  return {
	  name => 'serverConnectionInitiated',
	  fromCert => $cn,
	  fromIp   => $ip,
	 }

}

sub _connectionResetEvent
{
  my $cn = $1;
  my $ip = $2;

  return {
	  name => 'connectionReset',
	  fromCert => $cn,
	  fromIp   => $ip,
	 }

}


sub _connectionResetByServerEvent
{
  return {
	  name => 'connectionResetByServer',
	 }
}

1;
