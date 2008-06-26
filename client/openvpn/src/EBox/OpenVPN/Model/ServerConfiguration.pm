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

# Class:
# 
#

#   
package EBox::OpenVPN::Model::ServerConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Model::ModelManager;

use EBox::Types::Boolean;
use EBox::Types::HasMany;
use EBox::Types::Select;
use EBox::Types::Password;

use EBox::Types::IPNetwork;
use EBox::Types::IPAddr;

use EBox::OpenVPN::Server;
use EBox::OpenVPN::Types::PortAndProtocol;
use EBox::OpenVPN::Types::Certificate;
use EBox::OpenVPN::Types::TlsRemote;

use constant ALL_INTERFACES => '_ALL';


sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}



sub _table
{
    my @tableHead = 
        ( 
          new EBox::OpenVPN::Types::PortAndProtocol(
                                                    
                                                    fieldName => 'portAndProtocol',
                                                    printableName => __('Server port'),
                                                    unique => 1,
                                                    editable => 1,
                                                   ),
         new EBox::Types::IPNetwork(
                                   fieldName => 'vpn',
                                   printableName => __('VPN address'),
                                    editable => 1,
                               ),

         new EBox::OpenVPN::Types::Certificate(
                                fieldName => 'certificate',
                                printableName => __('Server certificate'),

                                editable       => 1,
                               ),
         
         new EBox::OpenVPN::Types::TlsRemote(
                                 fieldName => 'tlsRemote',
                                 printableName => __('Client authorization by common name'),
                                 editable => 1,
                               ),
         new EBox::Types::Boolean(
                                 fieldName =>  'masquerade',
                                 printableName => __('Network Address Translation'),
                                  editable => 1,
                                  defaultValue => 0,
                               ),
         new EBox::Types::Boolean(
                                 fieldName => 'clientToClient',  
                                 printableName => __('Allow client-to-client connections'), 
                                  editable => 1,
                                  defaultValue => 0,
                                ),
         new EBox::Types::Boolean(
                                 fieldName => 'pullRoutes', 
                                 printableName => __('Allow eBox-to-eBox tunnels'), 
                                  editable => 1,
                                  defaultValue => 0,
                                ),
        new EBox::Types::Password(
                                  fieldName => 'ripPasswd', 
                                  printableName => __('eBox-to-eBox tunnel password'), 
                                  minLength => 6,
                                  editable => 1,
                                  optional => 1,
                                 ), 
         new EBox::Types::Select(
                                 fieldName  => 'local', 
                                 printableName => __('Interface to listen on'), 
                                 editable => 1,
                                 populate      => \&_populateLocal,
                                 defaultValue => ALL_INTERFACES,
                                ),
        );

    my $dataTable = 
        { 
            'tableName'               => __PACKAGE__->nameFromClass(),
            'printableTableName' => __('Server configuration'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/ServerConfiguration',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('server'),
            'sortedBy' => 'name',
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}


sub name
{
    __PACKAGE__->nameFromClass(),
}




sub _populateLocal
{
    my @options;

    my $network = EBox::Global->modInstance('network');

    my @enabledIfaces = grep {
        $network->ifaceMethod($_) ne 'notset'
    } @{ $network->ifaces() };

    @options = map { { value => $_ } }  @enabledIfaces;


    push @options,  { 
                     value => ALL_INTERFACES, 
                      printableValue => __('All network interfaces'), 
                    };

    return \@options;
}




sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    $self->_uniqPortAndProtocol($action, $params_r, $actual_r);

    $self->_checkServerCertificate($action, $params_r, $actual_r);

    $self->_checkRipPasswd($action, $params_r, $actual_r);

    $self->_checkMasqueradeIsAvailable($action, $params_r, $actual_r);

    $self->_checkIface($action, $params_r, $actual_r);
    $self->_checkIfaceAndMasquerade($action, $params_r, $actual_r);

    $self->_checkTlsRemote($action, $params_r, $actual_r);

    $self->_checkPortIsAvailable($action, $params_r, $actual_r);
}


sub _checkRipPasswd
{
    my ($self, $action, $params_r, $actual_r) = @_;

    return unless (
                   (exists $params_r->{ripPasswd}) or 
                   (exists $params_r->{pullRoutes})
                  );

    my $pullRoutes = exists $params_r->{pullRoutes} ?
                                    $params_r->{pullRoutes}->value() :
                                    $actual_r->{pullRoutes}->value();
    my $ripPasswd  = exists $params_r->{ripPasswd} ?
                                    $params_r->{ripPasswd}->value() :
                                    $actual_r->{ripPasswd}->value();

    return if (not $pullRoutes); # only ripPasswd is needed when pullRoutes
                                 #  is on
        
    $ripPasswd or
        throw EBox::Exceptions::External(
          __('eBox to eBox tunel option requieres a RIP password')
                                        );
}

sub _uniqPortAndProtocol
{
    my ($self, $action, $params_r) = @_;
    
    exists $params_r->{portAndProtocol} 
        or return;

    my $portAndProtocol = $params_r->{portAndProtocol};

    my $manager = EBox::Model::ModelManager->instance();
    my $serverList = $manager->model('/openvpn/Servers');

    
    my $nIdentical = 0;
    my $olddir = $self->directory();
    foreach my $row ( @{ $serverList->rows}) {
        my $serverConf = $row->subModel('configuration');
        my $other      = $serverConf->portAndProtocolType();
        
        if ($portAndProtocol->cmp($other) == 0) {
                throw EBox::Exceptions::External(
                                                 __('Other server is listening on the same port')
                                                );

        }
    }
    $self->setDirectory($olddir);
}

sub _checkPortIsAvailable
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $portAndProtocolNotChanged =  (not exists $params_r->{portAndProtocol} );
    my $localIfaceNotChanged      =    (not exists $params_r->{local} );

    if ( $portAndProtocolNotChanged and $localIfaceNotChanged ) {
        return;
    }

    my $portAndProtocol = exists $params_r->{portAndProtocol} ?
                                   $params_r->{portAndProtocol} :
                                   $actual_r->{portAndProtocol};
    my $proto = $portAndProtocol->protocol();
    my $port  = $portAndProtocol->port();

    my $local = exists $params_r->{local} ?
                    $params_r->{local}->value() :
                    $actual_r->{local}->value();


    return if $self->_alreadyCheckedAvailablity( $proto, $port, $local, $actual_r);


    my $firewall = EBox::Global->modInstance('firewall');
    $firewall or # firewall may not be installed
        return;


    # do the check...
    if ($local eq ALL_INTERFACES) {
        $local = undef;
    }

    if (not $firewall->availablePort($proto, $port, $local)) {
        throw EBox::Exceptions::External(
           __x(
               'Port {p} is not available',
               p => $portAndProtocol->printableValue()
              )
                                        );
    }

}


sub _alreadyCheckedAvailablity
{
    my ($self, $proto, $port, $local, $actual_r) = @_;

    # avoid falses positives
    my ($oldProto, $oldPort, $oldLocal) = (
                                           $actual_r->{portAndProtocol}->protocol(),
                                           $actual_r->{portAndProtocol}->port(),
                                           $actual_r->{local}->value(),
                                          );
    my $samePort  = $port eq $oldPort;
    my $sameProto = $proto eq $oldProto;
    my $sameLocal = $local eq $oldLocal;

    if ($local eq ALL_INTERFACES) {
        if ($sameProto and $samePort) {
            # we have already checked
            return 1;
        }
    }
    else {
        if ($sameProto and $samePort and $sameLocal) {
            # we have already checked,
            return 1;
        } 
    }

    return 0;
}



#XXX this must be in a iface type...
sub _checkIface
{
    my ($self, $action, $params_r, $actual_r) = @_;

    $params_r->{'local'} or
        return;

    my $iface   = $params_r->{'local'}->value();
    if ($iface eq ALL_INTERFACES) {
        return;
    }


    my $network = EBox::Global->modInstance('network');

    if (not $network->ifaceExists($iface) ) {
        throw EBox::Exceptions::External(__x('The interface {iface} does not exist'), iface => $iface);
    } 
    
    if ( $network->ifaceMethod($iface) eq 'notset') {
        throw EBox::Exceptions::External(__x('The interface {iface} is not configured'), iface => $iface);
  }
}



sub _checkMasqueradeIsAvailable
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (not (exists $params_r->{masquerade} ) ) {
        return;
    }


    my $firewall = EBox::Global->modInstance('firewall');
    if (not $firewall) {
        throw EBox::Exceptions::External(
          __('Cannot use Network Address translation beacuse it requires the firewall module. The module is neither installed or activated')
                                        );
    }

    if (not $firewall->isEnabled()) {
        throw EBox::Exceptions::External(
          __('Cannot use Network Address translation beacuse it requires the firewall module enabled. Please activate it and try again')
                                        );
    }
}

sub _checkIfaceAndMasquerade
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (not (exists $params_r->{masquerade}  or exists $params_r->{'local'}) ) {
        return;
    }
    
    
    my $masquerade = exists $params_r->{masquerade} ?
                                 $params_r->{masquerade}->value() :
                                 $actual_r->{masquerade}->value();


    if ($masquerade) {
        # with masquerade either internal or external interfaces are correct
        return;
    }


    my $local   = exists $params_r->{local} ?
                                 $params_r->{local}->value() :
                                 $actual_r->{local}->value(); 

    my $network = EBox::Global->modInstance('network');

    if ($local eq ALL_INTERFACES) {
        # check that at least there is one external interface
        my $externalIfaces = @{ $network->ExternalIfaces() };
        if (not $externalIfaces) {
            throw EBox::Exceptions::External(
             __('At least one external interface is needed to connect to the server unless network address translation option is enabled')
                                            );
        }
    }
    else {
        my $external = $network->ifaceIsExternal($local);
        if (not $external) {
            throw EBox::Exceptions::External(
              __('The interface must be a external interface, unless masuqerade option is on')
                                            )
        }
    }

}


sub _checkServerCertificate
{
    my ($self, $action, $params_r, $actual_r) = @_;
    
    (exists $params_r->{certificate}) or
        return;

    my $cn = $params_r->{certificate}->value();
    EBox::OpenVPN::Server->checkCertificate($cn);
}


sub _checkTlsRemote
{
    my ($self, $action, $params_r, $actual_r) = @_;

    
    (exists $params_r->{tlsRemote}) or
        return;

    my $cn = $params_r->{tlsRemote}->value();
    
    if ($cn == 0) {
        # TLS rmeote option disabled, nothing to check
        return;
    }


    EBox::OpenVPN::Server->checkCertificate($cn);
}

sub configured
{
    my ($self) = @_;

    $self->portAndProtocolType()->port()     or return 0;
    $self->portAndProtocolType()->protocol() or return 0;

    $self->vpnType()->printableValue ne ''    or return 0;

    my $cn = $self->certificate();
    $cn                                      or return 0;
    EBox::OpenVPN::Server->checkCertificate($cn);

    return 1;
}


1;


