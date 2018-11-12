# Copyright (C) 2013 Zentyal S.L.
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

package EBox::IPsec::Model::Users;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Global;

use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    if ($self->global()->modExists('samba')) {
        $self->{usersMod} = $self->global()->modInstance('samba');
    }

    if ($self->{usersMod} and $self->{usersMod}->isEnabled() and $self->{usersMod}->isProvisioned()) {
        my $domainSID = $self->{usersMod}->ldap()->domainSID();
        $self->{domainUsersSID} = "$domainSID-513";
    } else {
        # Samba is not available.
        delete $self->{usersMod};
    }

    bless($self, $class);
    return $self;
}


# Method: validateTypedRow
#
#      Check the row to add or update if contains a valid configuration.
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the configuration is not valid.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;
    my $global = $self->global();

}

# Method: validationGroup
#
# Return the Active directory group to use to validate L2TP/IPSec VPN users or undef if the validation is not using AD.
#
sub validationGroup
{
    my ($self) = @_;

    unless ($self->{usersMod}) {
        return undef;
    }

    my $usersSource = $self->row()->elementByName('usersSource');
    if ($usersSource->selectedType() eq 'group') {
        return $usersSource->subtype()->value();
    } else {
        return undef;
    }
}

# Method: _populateGroups
#
# List all available groups in the system.
#
sub _populateGroups
{
    my $usersMod = undef;
    if (EBox::Global->modExists('samba')) {
        $usersMod = EBox::Global->modInstance('samba');
    }

    unless ($usersMod and $usersMod->isEnabled() and $usersMod->isProvisioned()) {
        return [];
    }

    my @securityGroups;
    foreach my $group (@{$usersMod->securityGroups()}) {
        my $name = $group->name();
        push (@securityGroups, {
            value => $name,
            printableValue => $name,
        });
    }
    return \@securityGroups;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;
    my $global = $self->global();

    my @fields = ();
    my @actions = ();
    if ($self->{usersMod}) {
        eval 'use EBox::Samba::Group';
        my $domainUsers = EBox::Samba::Group->new(sid => $self->{domainUsersSID});
        my @usersSourceSubtypes = ();
        push (@usersSourceSubtypes,
            new EBox::Types::Select(
                fieldName     => 'group',
                printableName => __('Users Group'),
                populate      => \&_populateGroups,
                editable      => 1,
                optional      => 0,
                disableCache  => 1,
                defaultValue  => $domainUsers->name(),
            )
        );
        push (@usersSourceSubtypes,
            new EBox::Types::Union::Text(
                fieldName => 'usersFile',
                printableName => __('Manual list of users'),
            )
        );

        @fields = (
            new EBox::Types::Union(
                fieldName  => 'usersSource',
                printableName => __('Users Source'),
                editable => 1,
                subtypes => \@usersSourceSubtypes,
                help => __('Selects the provider for the users allowed to use the VPN.'),
            )
        );

        @actions = ('add', 'del', 'editField', 'changeView');
    } else {
        @fields = (
            new EBox::Types::Text(
                fieldName  => 'usersSource',
                printableName => __('The list of users allowed to connecto to VPN must be handled manually'),
                help => __('To use the existing system user accounts you will need to activate "File sharing" module ' .
                           'to enable the Active Directory'),
            )
        );
    }

    my $dataTable = {
        tableName => 'Users',
        printableTableName => __('L2TP/IPSec users source'),
        defaultActions => \@actions,
        tableDescription => \@fields,
        class => 'dataTable',
        modelDomain => 'IPsec',
    };

    return $dataTable;
}

1;
