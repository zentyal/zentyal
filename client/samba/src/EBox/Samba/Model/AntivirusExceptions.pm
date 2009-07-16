# Copyright (C) 2009 eBox Technologies S.L.
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

# Class: EBox::Samba::Model::Antivirus
#
#  This model is used to configure antivirus settings for Samba shares
#
package EBox::Samba::Model::AntivirusExceptions;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Samba::Types::Select;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the new Antivirus table
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Samba::Model::Antivirus> - the newly created object
#     instance
#
sub new
{

      my ($class, %opts) = @_;
      my $self = $class->SUPER::new(%opts);
      bless ( $self, $class);

      return $self;

}

sub populateGroup
{
    my $userMod = EBox::Global->modInstance('users');
    my @groups = map (
                {
                    value => $_->{gid},
                    printableValue => $_->{account}
                }, $userMod->groups()
            );
    return \@groups;
}

sub shareModel
{
    return EBox::Global->modInstance('samba')->model('SambaShares');
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::Union(
                       fieldName     => 'user_group_share',
                       printableName => __('User/Group/Share'),
                       subtypes =>
                        [
                            new EBox::Types::Union::Text(
                                fieldName => 'users',
                                unique => '1',
                                printableName => __('User homes')),
                            new EBox::Samba::Types::Select(
                                fieldName => 'group',
                                unique => '1',
                                printableName => __('Group'),
                                populate => \&populateGroup,
                                HTMLViewer => '/ajax/viewer/shareViewer.mas',
                                editable => 1),
                            new EBox::Types::Select(
                                fieldName => 'share',
                                unique => '1',
                                printableName => __('Share'),
                                foreignModel => \&shareModel,
                                foreignField => 'share',
                                HTMLViewer => '/ajax/viewer/shareViewer.mas',
                                editable => 1)
                        ]
                      ),
      );

    my $dataTable = {
                     tableName          => 'AntivirusExceptions',
                     printableTableName => __('Samba shares antivirus exceptions'),
                     modelDomain        => 'Samba',
                     defaultActions     => [ 'add', 'del', 'changeView' ],
                     tableDescription   => \@tableDesc,
                     class              => 'dataTable',
                     help               => __('Add exceptions to the default antivirus settings'),
                     printableRowName   => __('exception'),
                    };

      return $dataTable;
}

sub syncRows
{
    my ($self, $currentIds) = @_;

    my $anyChange = undef;
    my $userMod = EBox::Global->modInstance('users');

    for my $id (@{$currentIds}) {
        my $userGroupShare = $self->row($id)->elementByName('user_group_share');
        my $remove;
        if ($userGroupShare->selectedType() eq 'user') {
            if (!$userMod->uidExists($userGroupShare->value())) {
                $remove = 1;
            }
        } elsif ($userGroupShare->selectedType() eq 'group') {
            if (!$userMod->gidExists($userGroupShare->printableValue())) {
                $remove = 1;
            }
        }
        if ($remove) {
            $self->removeRow($id, 1);
            $anyChange = 1;
        }
    }
    return $anyChange;
}

1;
