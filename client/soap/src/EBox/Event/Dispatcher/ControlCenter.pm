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

package EBox::Event::Dispatcher::ControlCenter;

# Class: EBox::Dispatcher::Log;
#
# This class is a dispatcher which sends the event to the eBox log.
#
use base 'EBox::Event::Dispatcher::Abstract';

################
# Core modules
################
use Error qw(:try);

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions;

# Group: Public method

# Constructor: new
#
#        The constructor for <EBox::Event::Dispathcer::ControlCenter>
#
#
# Returns:
#
#        <EBox::Event::Dispatcher::ControlCenter> - the newly created object
#
sub new
  {

      my ($class) = @_;

      my $self = $class->SUPER::new('ebox-soap');
      bless( $self, $class);

      my $global = EBox::Global->getInstance();
      $self->{soap} = $global->modInstance('soap');

      return $self;

  }

# Method: configurated
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::configurated>
#
sub configurated
  {

      my ( $self ) = @_;

      ($self->{soap}->enabled()) or return 0;

      return 1;

  }


# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::ConfigurationMethod>
#
sub ConfigurationMethod
  {

      return 'link';

  }

# Method: ConfigureURL
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::ConfigureURL>
#
sub ConfigureURL
  {

      return 'SOAP/Index';

  }

# Method: send
#
#        Send the event to the control center if the connectivity test
#        is working properly
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::send>
#
sub send
  {

      my ($self, $event) = @_;

      defined ( $event ) or
        throw EBox::Exceptions::MissingArgument('event');

      unless ( $self->{CCReady} ) {
          $self->enable();
      }

      # Return undef if no connection with CC was possible
      return undef unless ( $self->{CCReady} );

      my $res;
      try {
          $res = $self->_sendEvent($event);
      } catch EBox::Exceptions::Base with {
          $res = undef;
          $self->{CCReady} = 0;
      };

      return $res;
  }

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_description>
#
sub _receiver
  {

      return __('Control center admin at a log file');

  }

# Method: _name
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_name>
#
sub _name
  {

      return __('Control center');

  }

# Method: _enable
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::_enable>
#
sub _enable
  {

      my ($self) = @_;

      $self->{CCReady} = 0;
      # Connectivity test launches an EBox::Exceptions::External if it
      # cannot connect to the control center anyway
      $self->{soap}->connectivityTest();
      $self->{CCReady} = 1;

      return 1;

  }


# Group: Private helper methods

# Send the event through SOAP::Lite
# Throw EBox::Exceptions::* if any error has happened
sub _sendEvent # ($event)
  {

      my ($self, $event) = @_;

      my $soapMod = $self->{soap};
      my $ip = $soapMod->controlCenterIP();
      my $soapPort = $soapMod->controlCenterSOAPServerPort();
      my $eBoxCN = $soapMod->eBoxCN();

      use SOAP::Lite;

      my $soapConn = new SOAP::Lite
        uri   => 'http://ebox-platform.com/EBox/ControlCenter/EventReceiver',
        proxy => 'https://' . $ip->ip() . ':' . $soapPort . '/soap',
        on_fault => sub {
            my ($soap, $res) = @_;
            if ( ref $res ) {
                # Get the exception type
                my $excType = (keys %{$res->faultdetail()})[0];
                # Get the hash to bless
                my $hash_ref = $res->faultdetail()->{$excType};
                # Substitute from __ to ::
                $excType =~ s/__/::/g;
                # Do the bless to have the exception object
                bless ($hash_ref, $excType);
                throw $hash_ref;
            } else {
                throw EBox::Exceptions::Protocol($soap->transport()->status(), '');
            }}
        ;

      $self->_setCerts();

      my $response = $soapConn->informEvent($eBoxCN, $event);

      return $response->result();

  }

# Method: _setCerts
#
#       Set the environment variables to do the SOAP call through
#       <Crpyt::SSLeay> library
#
sub _setCerts
  {

      my ($self) = @_;

      my $modSoap = $self->{soap};

      $ENV{HTTPS_CERT_FILE} = $modSoap->certificateFile();
      $ENV{HTTPS_KEY_FILE} = $modSoap->privateKeyFile();
      $ENV{HTTPS_CA_FILE} = $modSoap->CACertificateFile();
      $ENV{HTTPS_VERSION} = '3';

  }

1;
