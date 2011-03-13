# Copyright (C) 2008-2010 eBox Technologies S.L.
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
#   EBox::DNS::Model::HostnameTable
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the host names (A resource records) in a domain and a set of alias
#   described in <EBox::Network::Model::AliasTable>
#
package EBox::DNS::Model::HostnameTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Model::ModelManager;
use EBox::Types::DomainName;
use EBox::Types::HasMany;
use EBox::Types::HostIP;
use EBox::Sudo;

use EBox::Model::ModelManager;

use Net::IP;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

# Group: Public methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: addHostname
#
#   Add a hostname to the hostnames table. Note this method must exist
#   because we must provide an easy way to migrate old dns module
#   to this new one.
#
# Parameters:
#
#   (NAMED)
#   hostname   - String host name
#   ip         - String host ipaddr
#   aliases    - array ref containing the alias names
#
#   Example:
#
#      'hostname'     => 'bar',
#      'ip'           => '192.168.1.2',
#      'aliases'      => [
#                         { 'bar',
#                           'b4r'
#                         }
#                        ]
sub addHostname
{
   my ($self, %params) = @_;

   my $name = delete $params{'hostname'};
   my $ip = delete $params{'ip'};

   return unless (defined($name) and defined($ip));

   my $id = $self->addRow('hostname' => $name, 'ipaddr' => $ip);

   unless (defined($id)) {
       throw EBox::Exceptions::Internal("Couldn't add host name: $name");
   }

   my $aliases = delete $params{'aliases'};
   return unless (defined($aliases) and @{$aliases} > 0);

   my $aliasModel =
   		EBox::Model::ModelManager::instance()->model('AliasTable');

   $aliasModel->setDirectory($self->{'directory'} . "/$id/alias");
   foreach my $alias (@{$aliases}) {
       $aliasModel->addRow('alias' => $alias);
   }
}

# Method: validateTypedRow
#
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if there is an alias with
#    the same name for other hostname within the same domain
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless ( exists $changedFields->{hostname} );

    # Check there is no CNAME RR in the domain with the same name
    my $newHostName = $changedFields->{hostname};
    my $domainModel = $changedFields->{hostname}->row()->model();

    for my $id (@{$domainModel->ids()}) {
        my $row = $domainModel->row($id);
        for my $id (@{$row->subModel('alias')->ids()}) {
           my $subRow = $row->subModel('alias')->row($id);
           if ($subRow->elementByName('alias')->isEqualTo($newHostName)) {
                throw EBox::Exceptions::External(
                    __x('There is an alias with the same name "{name}" '
                        . 'for "{hostname}" in the same domain',
                         name     => $subRow->valueByName('alias'),
                         hostname => $row->valueByName('hostname')));
            }
        }
    }

    if ( $action eq 'update' ) {
        # Add toDelete the RRs for this hostname and its aliases
        my $oldRow  = $self->row($changedFields->{id});
        my $zoneRow = $oldRow->parentRow();
        if ( $zoneRow->valueByName('dynamic') ) {
            my @toDelete = ();
            my $zone = $zoneRow->valueByName('domain');
            # Delete all aliases
            my $aliasModel = $oldRow->subModel('alias');
            my $ids = $aliasModel->ids();
            foreach my $id (@{$ids}) {
                my $aliasRow = $aliasModel->row($id);
                push(@toDelete, $aliasRow->valueByName('alias') . ".$zone");
            }

            my $fullHostname = $oldRow->valueByName('hostname') . ".$zone";
            push(@toDelete, $fullHostname);
            $self->{toDelete} = \@toDelete;
        }
    }

}

# Method: updatedRowNotify
#
#     Override to add to the list of removed of RRs
#
# Overrides:
#
#     <EBox::Exceptions::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $newRow, $force) = @_;

    # The field is added in validateTypedRow
    if ( exists $self->{toDelete} ) {
        foreach my $rr (@{$self->{toDelete}}) {
            $self->_addToDelete($rr);
        }
        delete $self->{toDelete};
    }
}

# Method: removeRow
#
#     Override not to allow to remove the last NS record if this row
#     points to this record
#
# Overrides:
#
#     <EBox::Exceptions::DataTable::removeRow>
#
sub removeRow
{
    my ($self, $id, $force) = @_;

    if ( $force and $self->table()->{automaticRemove} ) {
        # Trying to remove the pointed elements first
        my $manager = EBox::Model::ModelManager->instance();
        $manager->removeRowsUsingId($self->contextName(), $id);
    }
    return $self->SUPER::removeRow($id, $force);

}

# Method: precondition
#
# Overrides:
#
#     <EBox::Model::Component::precondition>
#
sub precondition
{
    my ($self) = @_;

    if ( $self->parentRow()->readOnly() ) {
        return 0;
    }
    return 1;

}

# Method: preconditionFailMsg
#
# Overrides:
#
#     <EBox::Model::Component::preconditionFailMsg>
#
sub preconditionFailMsg
{
    return __('The domain is set as read only. You cannot add host names');
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead =
        (
            new EBox::Types::DomainName
                            (
                                'fieldName' => 'hostname',
                                'printableName' => __('Host name'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::HostIP
                            (
                                'fieldName' => 'ipaddr',
                                'printableName' => __('IP Address'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'alias',
                                'printableName' => __('Alias'),
                                'foreignModel' => 'AliasTable',
                                'view' => '/ebox/DNS/View/AliasTable',

                                'backView' => '/ebox/DNS/View/AliasTable',
                                'size' => '1',
                             )
          );

    my $dataTable =
        {
            'tableName' => 'HostnameTable',
            'printableTableName' => __('Host names'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Dns/Controller/HostnameTable',
            'HTTPUrlView'       => 'DNS/View/HostnameTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Automatic reverse resolution is done. If you '
                         . 'repeat an IP address in another domain, only '
                         . 'first match will be used by reverse resolution. '
                         . 'Dynamic zones may erase your manual reverse resolution'),
            'printableRowName' => __('host name'),
            'sortedBy' => 'hostname',
        };

    return $dataTable;
}


# Method: deletedRowNotify
#
# 	Overrides to remove mail exchangers referencing the deleted
# 	host name and add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#      <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    # Delete the associated MX RR
    my $mailExModel = $row->parentRow()->subModel('mailExchangers');
    for my $id(@{$mailExModel->ids()}) {
        my $mailRow = $mailExModel->row($id);
        my $hostname = $mailRow->elementByName('hostName');
        next unless ($hostname->selectedType() eq 'ownerDomain');
        if ($hostname->value() eq $row->id()) {
            $mailExModel->removeRow($mailRow->id());
        }
    }

    # Deleted RRs to account
    my $zoneRow = $row->parentRow();
    if ( $zoneRow->valueByName('dynamic') ) {
        my $zone = $zoneRow->valueByName('domain');
        # Delete all aliases
        my $aliasModel = $row->subModel('alias');
        my $ids = $aliasModel->ids();
        foreach my $id (@{$ids}) {
            my $aliasRow = $aliasModel->row($id);
            $self->_addToDelete( $aliasRow->valueByName('alias') . ".$zone");
        }

        my $fullHostname = $row->valueByName('hostname') . ".$zone";
        $self->_addToDelete($fullHostname);
    }

}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
        my ($self) = @_;

        return $self->parentRow()->printableValueByName('domain');
}

# Group: Private methods

# Add the RR to the deleted list
sub _addToDelete
{
    my ($self, $domain) = @_;

    my $mod = $self->{gconfmodule};
    my $key = $mod->deletedRRsKey();
    my @list = ();
    if ( $mod->st_entry_exists($key) ) {
        @list = @{$mod->st_get_list($key)};
    }

    push(@list, $domain);
    $mod->st_set_list($key, 'string', \@list);

}

1;
