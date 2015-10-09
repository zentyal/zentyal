# Copyright (C) 2011-2013 Zentyal S.L.
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
#   <EBox::DNS::Model::Services>
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which contains the free based TXT records for a domain
#
use strict;
use warnings;

package EBox::DNS::Model::Services;

use base 'EBox::DNS::Model::Record';

use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;

use EBox::Types::Composite;
use EBox::Types::Int;
use EBox::Types::Port;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Union;

use File::Slurp;

# Constants
use constant SERVICE_FILE => '/etc/services';

# Group: Public methods

# Constructor: new
#
#      Create a new Services model instance
#
# Returns:
#
#      <EBox::DNS::Model::Services> - the newly created model
#      instance
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless ($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#   Check the given custom name is a Fully Qualified Domain Name (FQDN)
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    $self->checkService($changedFields, $allFields);
    $self->checkHostname($changedFields, $allFields);

    if ($action eq 'update') {
        # Add toDelete the RRs for this SRV record
        my $oldRow  = $self->row($changedFields->{id});
        my $zoneRow = $oldRow->parentRow();
        if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
            my $zone = $zoneRow->valueByName('domain');
            my $srvName  = $oldRow->valueByName('service_name');
            my $protocol = $oldRow->valueByName('protocol');
            $self->{toDelete} = "_${srvName}._${protocol}.${zone}. SRV";
        }
    }
}

# Method: deletedRowNotify
#
# 	Overrides to add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#      <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    my $zoneRow = $row->parentRow();
    if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
        my $zone = $zoneRow->valueByName('domain');
        my $srvName  = $row->valueByName('service_name');
        my $protocol = $row->valueByName('protocol');
        $self->_addToDelete("_${srvName}._${protocol}.${zone}. SRV");
    }
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
          new EBox::Types::Text(
              fieldName     => 'service_name',
              printableName => __('Service name'),
              editable      => 1,
             ),
          new EBox::Types::Select(
              fieldName     => 'protocol',
              printableName => __('Protocol'),
              populate      => \&_protocols,
              editable      => 1,
             ),
          new EBox::Types::Int(
              fieldName     => 'priority',
              printableName => __('Priority'),
              min           => 0,
              max           => 65535,
              defaultValue  => 0,
              editable      => 1,
              help          => __('Lower value is greater priority'),
             ),
          new EBox::Types::Int(
              fieldName     => 'weight',
              printableName => __('Weight'),
              min           => 0,
              max           => 65535,
              defaultValue  => 0,
              editable      => 1,
              help          => __('0 indicates no weighting and a greater value '
                                  . 'more chances to be selected with equal '
                                  . 'priority'),
             ),
          new EBox::Types::Port(
              fieldName     => 'port',
              printableName => __('Target port'),
              editable      => 1,
             ),
          new EBox::Types::Union(
              fieldName     => 'hostName',
              printableName => __('Target'),
              editable      => 1,
              help          => __('If you select the "Custom", it should be a '
                                  . 'Fully Qualified Domain Name'),
              subtypes      =>
                [
                    new EBox::Types::Select(
                        fieldName     => 'ownerDomain',
                        printableName => __('This domain'),
                        foreignModel  => \&_hostnameModel,
                        foreignField  => 'hostname',
                        editable      => 1,
                       ),
                    new EBox::Types::Text(
                        fieldName     => 'custom',
                        printableName => __('Custom'),
                        editable      => 1,
                       ),
                   ],
             ),
      );

    my $dataTable =
        {
            tableName => 'Services',
            printableTableName => __('Services'),
            automaticRemove => 1,
            modelDomain     => 'DNS',
            defaultActions => ['add', 'del', 'move', 'editField',  'changeView' ],
            tableDescription => \@tableDesc,
            class => 'dataTable',
            help => __('It manages the SRV records for this domain. '
                       . 'They are useful to select a host based on the priority '
                       . 'for a service.'),
            printableRowName => __x('{srv} record', srv => 'SRV'),
        };

    return $dataTable;
}

# Group: Private methods

# Get the hostname model from DNS module
sub _hostnameModel
{
    my ($type) = @_;

    # FIXME: We cannot use API until the bug in parent deep recursion is fixed
    # my $parentRow = $type->model()->parentRow();
    # if ( defined($parentRow) ) {
    #     return $parentRow->subModel('hostnames');
    # } else {
        # Bug in initialisation code of ModelManager
        my $model = EBox::Global->modInstance('dns')->model('HostnameTable');
        my $dir = $type->model()->directory();
        $dir =~ s:srv:hostnames:g;
        $model->setDirectory($dir);
        return $model;
    # }
}

sub _protocols
{
    my @options = (
        { value          => 'tcp',
          printableValue => 'TCP',
        },
        { value          => 'udp',
          printableValue => 'UDP',
        },
       );
    return \@options;
}

sub services
{
    my ($self) = @_;

    unless (defined $self->{services}) {
        $self->{services} = $self->_loadServices();
    }

    return $self->{services};
}

sub _loadServices
{
    my ($self) = @_;

    my $services = [];
    my @lines = File::Slurp::read_file(SERVICE_FILE);
    foreach my $line (@lines) {
        next if ($line =~ m:^#:);
        my @fields = split(/\s+/, $line);
        if (defined ($fields[0]) and defined ($fields[1])) {
            if ($fields[0] =~ m:[a-z\-]+: and $fields[1] =~ m:\d+/\w+:) {
                my ($name, $port, $protocol) = ($fields[0],
                        $fields[1] =~ m:(\d+)/(\w+):);
                if (defined ($name) and defined ($port) and defined ($protocol)) {
                    push (@{$services}, { name => $name, port => $port, protocol => $protocol });
                    foreach my $field (@fields[ 2 .. $#fields ]) {
                        last if ($field =~ m:^#:);
                        push (@{$services}, { name => $field, port => $port, protocol => $protocol });
                    }
                }
            }
        }
    }
    return $services;
}

sub checkService
{
    my ($self, $changedFields, $allFields) = @_;

    my $services = $self->services();
    if (exists $changedFields->{service_name} or
        exists $changedFields->{protocol} or
        exists $changedFields->{port} ) {
        my $serviceName = $allFields->{service_name}->value();
        $serviceName =~ s/^_//;
        my $serviceProtocol = $allFields->{protocol}->value();
        my $nMatch = grep { ($_->{name} eq $serviceName) and
                            ($_->{protocol} eq $serviceProtocol) } @{$services};
        if ($nMatch < 1) {
            throw EBox::Exceptions::External(
                __x("Service '{srv}' is not present in {file}",
                    srv => $allFields->{service_name}->value(),
                    file => SERVICE_FILE)
            );
        }
    }
}

sub checkHostname
{
    my ($self, $changedFields, $allFields) = @_;

    if (exists $changedFields->{hostName}) {
        if ($changedFields->{hostName}->selectedType() eq 'custom') {
            my $val = $changedFields->{hostName}->value();
            my @parts = split(/\./, $val);
            unless (@parts > 1) {
                throw EBox::Exceptions::External(
                    __x('The given host name is not a fully qualified domain '
                        . 'name (FQDN). Do you mean {srv}.{name}?',
                        srv => $allFields->{service_name}->value(),
                        name => $val));
            }
            # Check the given custom nameserver is a CNAME record from the
            # same zone
            my $zoneRow = $self->parentRow();
            my $zone    = $zoneRow->valueByName('domain');
            my $customZone = join('.', @parts[1 .. $#parts]);
            if ($zone eq $customZone) {
                # Use ownerDomain to set the mail exchanger
                throw EBox::Exceptions::External(__('A custom host name cannot be '
                                                    . 'set from the same domain. '
                                                    . 'Use "This domain" option '
                                                    . 'instead'));
            }
        }
    }
}

1;
