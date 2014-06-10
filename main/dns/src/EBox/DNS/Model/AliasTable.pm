# Copyright (C) 2008-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::DNS::Model::AliasTable;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;
use EBox::Types::DomainName;
use EBox::Sudo;

use Net::IP;

# Group: Public methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: validateTypedRow
#
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if there is a hostname with
#    the same name of this added/edited alias within the same domain
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless ( exists $changedFields->{alias} );
    my $alias = $changedFields->{alias};
    my $olddir = $alias->model()->directory();

    # Check it is not the nameserver hostname
    my $dnsMod = EBox::Global->modInstance('dns');
    my $newAlias = $alias->value();
    if (uc($newAlias) eq uc($dnsMod->NameserverHost())) {
        throw EBox::Exceptions::External(
            __x('An alias cannot be the nameserver host name "{ns}". '
                . 'Use a hostname instead',
                 ns => $dnsMod->NameserverHost()));
    }

    # Check there is no A RR in the domain with the same name
    my $domain = $alias->row()->parentRow()->parentRow()->valueByName('domain');

    my $hostnameIds = $alias->row()->parentRow()->model()->ids();
    foreach my $hostId (@{$hostnameIds}) {
        my $hostname = $alias->row()->parentRow()->model()->row($hostId);
        if ($hostname->elementByName('hostname')->isEqualTo($alias)) {
            throw EBox::Exceptions::External(
                        __x('There is a hostname with the same name "{name}" '
                            . 'in the same domain',
                             name     => $hostname->valueByName('hostname')));
        }

        foreach my $aliasId (@{$hostname->subModel('alias')->ids()}) {
            my $anAlias = $hostname->subModel('alias')->row($aliasId);
            next if ($aliasId eq $alias->row()->id());
            if ($anAlias->elementByName('alias')->isEqualTo($alias)) {
                throw EBox::Exceptions::External(
                  __x('There is an alias for {hostname} hostname '
                          . 'with the same name "{name}" '
                              . 'in the same domain',
                      hostname => $hostname->valueByName('hostname'),
                      name     => $anAlias->valueByName('alias')));
            }
        }
    }

    $self->setDirectory($olddir);

    if ($action eq 'update') {
        my $oldRow = $self->row($changedFields->{id});
        my $zoneRow = $oldRow->parentRow()->parentRow();
        if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
            my $zone = $zoneRow->valueByName('domain');
            my $alias = $oldRow->valueByName('alias');
            $self->{toDelete} = "$alias.$zone";
        }
    }
}

# Method: updatedRowNotify
#
#   Override to add to the list of removed of RRs
#
# Overrides:
#
#   <EBox::Exceptions::DataTable::updatedRowNotify>
#
sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    # The field is added in validateTypedRow
    if (exists $self->{toDelete}) {
        $self->_addToDelete($self->{toDelete});
        delete $self->{toDelete};
    }
}

# Method: deletedRowNotify
#
#       Overrides to add to the list of deleted RR in dynamic zones
#
# Overrides:
#
#      <EBox::Model::DataTable::deletedRowNotify>
#
sub deletedRowNotify
{
    my ($self, $row) = @_;

    # Deleted RRs to account
    my $zoneRow = $row->parentRow()->parentRow();
    if ($zoneRow->valueByName('dynamic') or $zoneRow->valueByName('samba')) {
        my $zone = $zoneRow->valueByName('domain');
        my $alias = $row->valueByName('alias');
        my $fullName = "$alias.$zone";
        # Delete all aliases
        $self->_addToDelete($fullName);
    }
}

sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('hostname');
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
                                'fieldName' => 'alias',
                                'printableName' => __('Alias'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             )
          );

    my $dataTable =
        {
            'tableName' => 'AliasTable',
            'printableTableName' => __('Alias'),
            'automaticRemove' => 1,
            'defaultController' => '/Dns/Controller/AliasTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView'],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __("This is the list of host name aliases. All of them will be resolved to the host's IP addresses list."),
            'printableRowName' => __('alias'),
            'sortedBy' => 'alias',
        };

    return $dataTable;
}

# Group: Private methods

# Add the RR to the deleted list
sub _addToDelete
{
    my ($self, $domain) = @_;

    my $mod = $self->{confmodule};
    my $key = EBox::DNS::DELETED_RR_KEY();
    my @list = ();
    if ( $mod->st_entry_exists($key) ) {
        @list = @{$mod->st_get_list($key)};
        foreach my $elem (@list) {
            if ($elem eq $domain) {
                # domain already added, nothing to do
                return;
            }
        }
    }

    push (@list, $domain);
    $mod->st_set_list($key, 'string', \@list);
}

1;
