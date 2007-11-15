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

# Class: EBox::Model::DataForm::Action
#
#       An specialized model from <EBox::Model::DataForm> which
#       performs an action and nothing is stored in a persistent
#       state. The action may have parameters, however these ones are
#       not stored for future actions
#

package EBox::Model::DataForm::Action;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::Internal;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      Create a new <EBox::Model::DataForm::Action> model instance
#
# Parameters:
#
#       gconfmodule - <EBox::GConfModule> the GConf eBox module which
#       gives the environment where to store data
#
#       directory - String the subdirectory within the environment
#       where the data will be stored
#
#       domain    - String the Gettext domain
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless ( $self, $class );

    return $self;

}

# Method: setTypedRow
#
#      Here it is where to perform the action. This method MUST NOT be
#      overridden to perform the action. You must better subclass
#      <EBox::Model::DataForm::formSubmitted> to perform the action
#
# Overrides:
#
#      <EBox::Model::DataForm::setTypedRow>
#
sub setTypedRow
{
    my ($self, $id, $paramsRef, %optParams) = @_;

    my $force = delete $optParams{force};

    # This method just perform those actions

    $self->validateTypedRow('update', $paramsRef, $paramsRef);

    # Notify remainder elements
    if ( (not $force) and $self->table()->{automaticRemove}) {
        my $manager = EBox::Model::ModelManager->instance();
        $manager->warnOnChangeOnId($self->tableName(), 0, $paramsRef, undef);
    }

    # Create the row
    my @values = values(%{$paramsRef});
    my %printableValueHash = map { $_->fieldName() => $_->printableValue() } @values;
    my %plainValueHash = map { $_->fieldName() => $_->value() } @values;
    my $row = { id => 'dummy',
                values => \@values,
                printableValueHash => \%printableValueHash,
                plainValueHash => \%plainValueHash,
                valueHash => $paramsRef,
              };

    $self->setMessage($self->message('update'));
    my $depModelMsg = $self->_notifyModelManager('update', $row);
    if ( defined ($depModelMsg)
         and ( $depModelMsg ne '' and $depModelMsg ne '<br><br>' )) {
        $self->setMessage($self->message('update') . '<br><br>' . $depModelMsg);
    }
    $self->_notifyCompositeManager('update', $row);
    $self->updatedRowNotify($row, $force);

}

1;
