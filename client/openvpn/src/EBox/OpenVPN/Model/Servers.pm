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
package EBox::OpenVPN::Model::Servers;
use base qw(EBox::Model::DataTable EBox::OpenVPN::Model::InterfaceTable);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::HasMany;
use EBox::Types::Text;
use EBox::Types::Boolean;

use EBox::OpenVPN::Server;

#use EBox::OpenVPN::Model::ServerConfiguration;

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
            new EBox::Types::Boolean (
                                      fieldName => 'service',
                                      printableName => __('Enabled'),
                                      editable => 1,
                                      defaultValue => 0,
                                     ),
            new EBox::Types::Text
                            (
                                'fieldName' => 'name',
                                'printableName' => __('Name'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1,
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'configuration',
                                'printableName' => __('Configuration'),
                                'foreignModel' => 'ServerConfiguration',
                                'view' => '/ebox/OpenVPN/View/ServerConfiguration',
                                'backView' => '/ebox/OpenVPN/View/Servers',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'advertisedNetworks',
                                'printableName' => __('Advertised networks'),
                                'foreignModel' => 'AdvertisedNetworks',
                                'view' => '/ebox/OpenVPN/View/AdvertisedNetworks',
                                'backView' => '/ebox/OpenVPN/View/Servers',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'download',
                                'printableName' => __('Download client bundle'),
                                'foreignModel' => 'DownloadClientBundle',
                                'view' => '/ebox/OpenVPN/View/DownloadClientBundle',
                                'backView' => '/ebox/OpenVPN/View/Servers',
                                'size' => '1',
                             ),
                             __PACKAGE__->interfaceFields(),
          );

    my $dataTable = 
        { 
            'tableName'              => __PACKAGE__->name(),
            'printableTableName' => __('List of servers'),
            'pageTitle' => __('VPN servers'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/Servers',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('server'),
            'sortedBy' => 'name',
            'help' => _help(),
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}


sub name
{
    __PACKAGE__->nameFromClass(),
}

# Method: precondition
#
#   Overrides  <EBox::Model::DataTable::precondition>
#   to check if the CA is created otherwise this model can't be used
#
# Returns:
#
#       Boolean - true if the precondition is accomplished, false
#       otherwise
sub precondition
{
    my $global = EBox::Global->getInstance();
    my $openvpn = $global->modInstance('openvpn');

    my $certsAvailable = @{  $openvpn->availableCertificates() };
    return undef unless ($certsAvailable);
}

# Method: preconditionFailMsg
#
#   Overrides <EBox::Model::DataTable::preconditionFailMsg
#
# Returns:
#
#       String - the i18ned message to inform user why this model
#       cannot be handled
#
#
sub preconditionFailMsg
{
    return  __x(q/<p>You can't create VPN servers because there aren't enough/
        . ' certificates.</p><p>Please, go to the {openhref} certificate '
        . 'manager module {closehref} and create new certificates.</p>' 
        . '<p>You will need a CA and at least one certificate.</p>',
        openhref => qq{<a href='/ebox/CA/Index'>}, closehref => qq{</a>});
 
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ($action eq 'add') {
        $self->_checkCertificatesAvailable(
                  __('Server creation')
                                          );
    }

    $self->_validateService($action, $params_r, $actual_r);
    $self->_validateName($action, $params_r, $actual_r);
}


sub _validateService
{
    my ($self, $action, $params_r, $actual_r) = @_;


    if ( not exists $params_r->{service} ) {
        return;
    }

    if (not $params_r->{service}->value()) {
        return;
    }

    my $configuration = $actual_r->{'configuration'}->foreignModelInstance();
    if ((not defined $configuration) or (not $configuration->configured())) {
        throw EBox::Exceptions::External(
                                         __('Cannot activate the server because is not fully configured; please edit the configuration and retry')
                                            )
        }

        $self->_checkCertificatesAvailable(
                  __('Server activation')
                                          );
}


sub _validateName
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ( not exists $params_r->{name} ) {
        return;
    }

    my $name =  $params_r->{name}->value();
    my $openvpn = EBox::Global->modInstance('openvpn');
    $openvpn->checkNewDaemonName($name, 'server');
}

sub _checkCertificatesAvailable
{
    my ($self, $printableAction) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');
    my $certsAvailable = @{  $openvpn->availableCertificates() };
    if (not $certsAvailable) {
        throw EBox::Exceptions::External(
                   __x(
                       q/{act} not possible because there aren't any avaialbe certificate. Please, go to the certificate manager module and create new certificates/,
                       act => $printableAction
                      )
                                        );
    }
}

sub servers
{
    my ($self) = @_;
    my @servers = map {
        EBox::OpenVPN::Server->new(
                                    $_
                                  )
    } @{  $self->rows() };
    
    return \@servers;

}


sub server
{
    my ($self, $name) = @_;
    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $row = $self->findRow(name => $name);
    defined $row or
        throw EBox::Exceptions::Internal("Server $name  does not exist");

    return EBox::OpenVPN::Server->new($row);
}


sub serverExists
{
    my ($self, $name) = @_;
    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $row = $self->findValue(name => $name);
    return defined $row
}

sub addedRowNotify
{
    my ($self, $row) = @_;
    
    my $service = $row->elementByName('service');
    
    if ($service->value()) {
        my $openvpn = EBox::Global->modInstance('openvpn');
        $openvpn->notifyLogChange();
    }

}

sub updatedRowNotify
{
    my ($self, $row) = @_;

    my $openvpn = EBox::Global->modInstance('openvpn');
    $openvpn->notifyLogChange();

}

sub deletedRowNotify
{
    my ($self, $row) = @_;
    my $name = $row->elementByName('name')->value();

    my $openvpn = EBox::Global->modInstance('openvpn');
    $openvpn->notifyDaemonDeletion($name, 'server');

}

sub _help
{
    return ('<p>You can configure openVPN servers to easily connect remote ' .
            'offices or users.</p>' .
            '<p>Click on <i>Configuration</i> to set the VPN parameters.</p>' .
            '<p><i>Advertised networks</i> allows you to configure which ' .
            'networks you want to make accessible to the remote users.' .
            '<p>Once you are done with the configuration you can download ' .
            'a file bundle for your operating system to use in your clients.');

}


1;
