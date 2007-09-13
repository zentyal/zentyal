# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::ControlCenter::ApacheSOAP;

# Package: EBox::ControlCenter::ApacheSOAP
#
#       Class to control the Apache SOAP Web server instance and its
#       configuration
#
use strict;
use warnings;

# eBox uses
use EBox::Sudo;
use EBox::Config;
use EBox::ControlCenter::Common;
use EBox::ControlCenter::FileEBoxDB;

###############
# Dependencies
###############
use Config::Tiny;
use Perl6::Junction qw(any);
use HTML::Mason::Interp;

# Group: Public methods

# Constructor: new
#
#     The <EBox::ControlCenter::ApacheSOAP> constructor
#
# Returns:
#
#     <EBox::ControlCenter::ApacheSOAP> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = {};

      bless ($self, $class);

      return $self;

  }

# Method: regenConfig
#
#     Regenerate the configuration from the Apache SOAP server and
#     manage the daemon to stop/start/restart
#
# Parameters:
#
#     action - String action to perform (restart, start, stop)
#              Default: restart *(Optional)*
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidType> - thrown if the parameter is not
#     from the correct type
#
sub regenConfig
  {

      my ($self, $action) = @_;

      $action = 'restart' unless defined ( $action );
      unless ( $action eq any('restart', 'start', 'stop') ) {
          throw EBox::Exceptions::InvalidType(
                 'action',
                 'It should one of the following: start, stop or restart'
                                             );
      }

      if ( $action eq any('restart', 'start')) {
          $self->_writeHTTPdConfFile();
      }

      $self->_doDaemon($action);

  }

# Group: Private methods

sub _writeHTTPdConfFile
{

    my ($self) = @_;

    my $httpdconf = $self->_httpdConfFile();
    my $output;
    my $interp = HTML::Mason::Interp->new(out_method => \$output);
    my $comp = $interp->make_component(
                                       comp_file => ( EBox::ControlCenter::Common::stubsDir() . '/apache.mas')
                                      );

    my $ccCN = EBox::ControlCenter::Common::controlCenterCN();

    my @confFileParams = ();
    push (@confFileParams, port => $self->_soapPort() );
    push (@confFileParams, user => EBox::Config::user() );
    push (@confFileParams, group => EBox::Config::group() );
    push (@confFileParams,
          certFile => EBox::ControlCenter::Common::findCertFile($ccCN)
         );
    push (@confFileParams, keyFile    => $self->_findKey($ccCN) );
    push (@confFileParams, CACertFile => EBox::ControlCenter::Common::CACert() );
    push (@confFileParams, debug => EBox::Config::configkey('debug'));
    push (@confFileParams, eBoxes => $self->_eBoxes());

    $interp->exec($comp, @confFileParams);

    my $confile = EBox::Config::tmp . "httpd.conf";
    unless (open(HTTPD, "> $confile")) {
        throw EBox::Exceptions::Internal("Could not write to $confile");
    }
    print HTTPD $output;
    close(HTTPD);

    EBox::Sudo::root("/bin/mv $confile $httpdconf");

}


# Method to get the eBoxes cns
# Return an array ref
sub _eBoxes
  {

      my ($self) = @_;

      my $db = new EBox::ControlCenter::FileEBoxDB();

      return $db->listEBoxes();

  }

# Method to manage the apache-soap daemon using SysV init scripts
sub _doDaemon # (action)
  {

      my ($self, $action) = @_;

      EBox::Sudo::root("invoke-rc.d apache-soap $action");

  }

# Method to get the SOAP port to listen to
sub _soapPort
  {

      my ($self) = @_;

      my $confFile = Config::Tiny->read( EBox::ControlCenter::Common::CCConfFile() );

      return $confFile->{_}->{soap_server_port};

  }

# Method to get the key path from a common name
# Undef if the file does not exist
sub _findKey # (cn)
  {

      my ($self, $cn) = @_;

      my $privDir = EBox::ControlCenter::Common::CAPrivateDir();

      return undef unless ( -f "$privDir/$cn.pem" );
      return "$privDir/$cn.pem";

  }

# Method to return the path to the httpd.conf file
sub _httpdConfFile
  {

      my ($self) = @_;

      return EBox::ControlCenter::Common::eBoxCCDir() . '/conf/httpd.conf';

  }

1;
