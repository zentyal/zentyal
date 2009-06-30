# Copyright (C) 2009 eBox technologies S.L.
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

# Class: EBox::UsersAndGroups::Model::ForceSync
#
#	Form model to force a sync on the pending operations on slaves
#

package EBox::UsersAndGroups::Model::ForceSync;

use base 'EBox::Model::DataForm::Action';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Sudo;

# Core modules
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#      Create a force sync form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
#
sub new
  {
      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);
      bless( $self, $class );

      return $self;
  }

# Method: formSubmitted
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self, $row, $force) = @_;

    try {
        EBox::Sudo::root('/usr/share/ebox-usersandgroups/slave-sync');
    } otherwise {
    };
    $self->pushRedirection('/ebox/Users/Composite/SlaveInfo');
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
                                 fieldName => 'action',
                                 printableName => __('Force sync'),
                                 editable       => 0,
                                 defaultValue   => __('on slaves'),
                                ),
        );

      my $dataForm = {
                      tableName           => 'ForceSync',
                      printableTableName  => __('Force sync of pending operations'),
                      modelDomain         => 'Users',
                      defaultActions      => [ 'editField', 'changeView' ],
                      printableActionName => __('Sync now'),
                      tableDescription    => \@tableDesc,
                      class               => 'dataForm',
                     };

      return $dataForm;

  }


1;
