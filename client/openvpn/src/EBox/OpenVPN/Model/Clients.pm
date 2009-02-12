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
package EBox::OpenVPN::Model::Clients;
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
use EBox::Types::Text::WriteOnce;

#use EBox::OpenVPN::Model::ClientConfiguration;

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

         new EBox::Types::Text::WriteOnce
                            (
                                'fieldName' => 'name',
                                'printableName' => __('Name'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1,
                             ),
            new EBox::Types::Boolean (
                                      fieldName => 'service',
                                      printableName => __('Service'),
                                      editable => 1,
                                      defaultValue => 0,
                                     ),

            new EBox::Types::HasMany
                            (
                                'fieldName' => 'configuration',
                                'printableName' => __('Configuration'),
                                'foreignModel' => 'ClientConfiguration',
                                'view' => '/ebox/OpenVPN/View/ClientConfiguration',
                                'backView' => '/ebox/OpenVPN/View/Clients',
                                'size' => '1',
                             ),
         new EBox::Types::Boolean
                            (
                             fieldName => 'internal',
                             printableName => 'internal',
                             hidden        => 1,
                            ),
         __PACKAGE__->interfaceFields(),

        );

    my $dataTable = 
        { 
            'tableName'              => __PACKAGE__->name(),
            'printableTableName' => __('VPN clients'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/Clients',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('client'),
            'sortedBy' => 'name',
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}


sub name
{
    __PACKAGE__->nameFromClass(),
}




sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    $self->_validateService($action, $params_r, $actual_r);
    $self->_validateName($action, $params_r, $actual_r);
    $self->_validateRipPasswd($action, $params_r, $actual_r);
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
                                         __('Cannot activate the client because is not fully configured; please edit the configuration and retry')
                                            )
        }
}


sub _validateName
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ( not exists $params_r->{name} ) {
        return;
    }

    my $name =  $params_r->{name}->value();
    my $openvpn = EBox::Global->modInstance('openvpn');

    my $internal = exists $params_r->{internal} ?
                            $params_r->{internal}->value() :
                            $actual_r->{internal}->value();


    $openvpn->checkNewDaemonName($name, 'client', $internal);
}


sub _validateRipPasswd
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ( not exists $params_r->{ripPasswd} ) {
        return;
    }

    my $ripPasswd =  $params_r->{ripPasswd}->value();
    if (not $ripPasswd) {
        throw EBox::Exceptions::External(
                                         __('RIP password is mandatory')
                                        )
    }


}

sub clients
{
    my ($self) = @_;
    my @clients = map {
        EBox::OpenVPN::Client->new( $_ )
    } @{  $self->rows() };
    
    return \@clients;

}


sub client
{
    my ($self, $name) = @_;
    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $row = $self->findRow(name => $name);
    defined $row or
        throw EBox::Exceptions::Internal("Client $name  does not exist");

    return EBox::OpenVPN::Client->new($row);
}


sub clientExists
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
    
    EBox::OpenVPN::Model::InterfaceTable::addedRowNotify($self, $row);

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
    $openvpn->notifyDaemonDeletion($name, 'client');
}





1;
