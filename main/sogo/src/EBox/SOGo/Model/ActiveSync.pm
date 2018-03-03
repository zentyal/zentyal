# Copyright (C) 2013 Zentyal S. L.
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

package EBox::SOGo::Model::ActiveSync;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;

# Method: new
#
#   Constructor, instantiate new model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Method: _table
#
#   Returns model description
#
sub _table
{
    my ($self) = @_;

    my @tableDesc;

    push (@tableDesc, new EBox::Types::Boolean(
        fieldName => 'activesync',
        printableName => __('ActiveSync®'),
        editable => 1,
        defaultValue => 0,
        help => __('Enable ActiveSync® support for all the mail domains'),
    ));

    my $dataForm = {
        tableName          => 'ActiveSync',
        printableTableName => __('Configuration'),
        modelDomain        => 'SOGo',
        defaultActions     => [ 'editField' ],
        tableDescription   => \@tableDesc,
        help               => __('The ActiveSync® gateway, standard ' .
                                 'protocol for several mobile devices.'),

    };

    return $dataForm;
}

sub formSubmitted
{
    my ($self, $row, $oldRow) = @_;

    # Set module as changed to ensure apache restart
    $self->parentModule()->setAsChanged(1);
}

1;
