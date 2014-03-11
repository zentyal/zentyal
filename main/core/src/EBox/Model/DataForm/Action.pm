# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Model::DataForm::Action
#
#       An specialized model from <EBox::Model::DataForm> which
#       performs an action and nothing is stored in a persistent
#       state. The action may have parameters, however these ones are
#       not stored for future actions
#

use strict;
use warnings;

package EBox::Model::DataForm::Action;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::Internal;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      Create a new <EBox::Model::DataForm::Action> model instance
#
# Parameters:
#
#       confmodule - <EBox::Module::Config> the GConf eBox module which
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

    bless ($self, $class);

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

    $self->validateTypedRow('update', $paramsRef, $paramsRef, $force);

    # Notify remainder elements
    if ((not $force) and $self->table()->{automaticRemove}) {
        my $manager = EBox::Model::Manager->instance();
        $manager->warnOnChangeOnId($self->tableName(), 0, $paramsRef, undef);
    }

    # Create the row
    my @values = values(%{$paramsRef});

    my $dir = $self->{'directory'};
    my $confmod = $self->{'confmodule'};
    my $row = EBox::Model::Row->new(dir => $dir, confmodule => $confmod);
    $row->setModel($self);
    $row->setId('dummy');
    for my $value (@values) {
        $row->addElement($value);
    }

    $self->setMessage($self->message('update'));
    my $depModelMsg = $self->_notifyManager('update', $row);
    if (defined ($depModelMsg)
        and ($depModelMsg ne '' and $depModelMsg ne '<br><br>' )) {
        $self->setMessage($self->message('update') . '<br><br>' . $depModelMsg);
    }
    $self->_notifyManager('update', $row);
    $self->updatedRowNotify($row, undef, $force);
}

# auditable turned off, in case of need to audit actions there must be audited
# by custom code
sub auditable
{
    return 0;
}

1;
