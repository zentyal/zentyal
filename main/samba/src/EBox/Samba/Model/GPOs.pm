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

# Class: EBox::Samba::Model::GPOs
#
#
package EBox::Samba::Model::GPOs;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Link;

# Constructor: new
#
#   Create the GPOs table
#
# Overrides:
#
#   <EBox::Model::DataTable::new>
#
# Returns:
#
#   <EBox::Samba::Model::GPOs> - the newly created object instance
#
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);

    return $self;
}

# Method: _table
#
# Overrides:
#
#   <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Text(fieldName     => 'name',
                              printableName => __('Name')),
        new EBox::Types::Text(fieldName     => 'status',
                              printableName => __('Status')),
        new EBox::Types::Link(fieldName     => 'edit',
                              printableName => __('Edit')),

    ];

    my $dataTable = {
                     tableName           => 'GPOs',
                     printableTableName  => __('Group Policy Objects'),
                     defaultController   => '/Samba/Controller/GPO',
                     defaultActions      => ['changeView'],
                     tableDescription    => $tableDesc,
                     menuNamespace       => 'Samba/GPOs',
                     printableRowName    => __('Group Policy Object'),
                     sortedBy            => 'name',
                     withoutActions      => 1,

                     #modelDomain         => 'Samba',
                     #class               => 'dataTable',
                     #help                => __('List of Group Policy Objects'),
                     #enableProperty      => 1,
                     #defaultEnabledValue => 1,
                     #orderedBy           => 'name',
                    };

      return $dataTable;
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers
#   based on the GPOs stored in LDAP
#
sub ids
{
    my ($self) = @_;

    my $global = $self->global();
    my $samba = $global->modInstance('samba');
    unless ($samba->configured() and $samba->isProvisioned()) {
        return [];
    }

    my @list = map { $_->dn() } @{$samba->gpos()};

    return \@list;
}

# Method: row
#
#   Override <EBox::Model::DataTable::row> to build and return a
#   row dependening on the gpo dn which is the id passwd.
#
sub row
{
    my ($self, $id) = @_;

    my $gpo = new EBox::Samba::GPO(dn => $id);
    if ($gpo->exists()) {
        my $displayName = $gpo->get('displayName');
        my $link = "/Samba/GPO?gpo=$id";
        my $status = $gpo->statusString();
        my $row = $self->_setValueRow(
            name => $displayName,
            status => $status,
            edit => $link,
        );
        $row->setId($id);
        $row->setReadOnly(1);
        return $row;
    } else {
        throw EBox::Exceptions::Internal("GPO $id does not exist");
    }
}

1;
