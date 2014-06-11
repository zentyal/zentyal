# Copyright (C) 2012-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::Samba::Model::AntivirusExceptions;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Select;

# Constructor: new
#
#   Create the new Antivirus table
#
# Overrides:
#
#   <EBox::Model::DataTable::new>
#
# Returns:
#
#   <EBox::Samba::Model::Antivirus> - the newly created object
#   instance
#
sub new
{

    my ($class, %opts) = @_;
    my $self = $class->SUPER::new(%opts);
    bless ($self, $class);
    return $self;
}

sub shareModel
{
    return EBox::Global->modInstance('samba')->model('SambaShares');
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

    my @tableDesc = ( new EBox::Types::Union(
                        fieldName     => 'user_group_share',
                        printableName => __('User/Group/Share'),
                        subtypes => [
                            new EBox::Types::Union::Text(
                                fieldName => 'users',
                                unique => '1',
                                printableName => __('User homes')),
                            new EBox::Types::Select(
                                fieldName => 'share',
                                disableCache => 1,
                                unique => 1,
                                printableName => __('Share'),
                                foreignModel => \&shareModel,
                                foreignField => 'share',
                                HTMLViewer => '/samba/ajax/viewer/shareViewer.mas',
                                editable => 1)
                        ]
                    ),
                );

    my $dataTable = { tableName          => 'AntivirusExceptions',
                      printableTableName => __('Samba shares antivirus exceptions'),
                      modelDomain        => 'Samba',
                      defaultActions     => [ 'add', 'del', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataTable',
                      help               => __('Add exceptions to the default antivirus settings'),
                      printableRowName   => __('exception'),
                      pageTitle          => undef,
                    };

    return $dataTable;
}

sub syncRows
{
    my ($self, $currentIds) = @_;

    my $anyChange = undef;
    my $shareModel = $self->parentModule->model('SambaShares');
    for my $id (@{$currentIds}) {
        my $userGroupShare = $self->row($id)->elementByName('user_group_share');
        my $remove;
        if ($userGroupShare->selectedType() eq 'share') {
            my $share = $shareModel->find(share => $userGroupShare->printableValue());
            unless (defined $share) {
                $self->removeRow($id, 1);
                $anyChange = 1;
            }
        }
    }
    return $anyChange;
}

1;
