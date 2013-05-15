# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Asterisk::Model::Meetings;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;

use EBox::Asterisk::Extensions;

# Group: Public methods

# Constructor: new
#
#       Create the new Meetings model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Meetings> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
      (
       new EBox::Types::Int(
                            fieldName     => 'exten',
                            printableName => __('Extension'),
                            size          => 4,
                            unique        => 1,
                            editable      => 1,
                            help          => __x('A number between {min} and {max}.',
                                                 min => EBox::Asterisk::Extensions->MEETINGMINEXTN,
                                                 max => EBox::Asterisk::Extensions->MEETINGMAXEXTN
                                                ),
                           ),
       new EBox::Types::Password(
                                 fieldName     => 'pin',
                                 printableName => __('Password'),
                                 size          => 8,
                                 unique        => 0,
                                 editable      => 1,
                                 optional      => 1,
                                ),
       new EBox::Types::Text(
                             fieldName     => 'desc',
                             printableName => __('Description'),
                             size          => 24,
                             unique        => 0,
                             editable      => 1,
                             optional      => 1,
                            ),
      );

    my $dataTable =
    {
        tableName          => 'Meetings',
        printableTableName => __('List of Meetings'),
        pageTitle          => __('Meetings'),
        printableRowName   => __('meeting'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        help               => __("Meeting rooms available on the server."),
        sortedBy           => 'exten',
        modelDomain        => 'Asterisk',
        enableProperty => 1,
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

sub precondition
{
    my ($self) = @_;
    return $self->parentModule()->configured();
}

sub preconditionFailMsg
{
    my ($self) = @_;
    my $name = $self->parentModule()->printableName();
    return __x('You must enable the {name} module before to be able to configure meetings',
               name => $name
              );
}

# Method: validateTypedRow
#
#       Check the row to add or update if contains a valid extension.
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidData> - thrown if the extension is not valid.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if ( exists $changedFields->{exten} ) {
        my $extensions = new EBox::Asterisk::Extensions;
        $extensions->checkExtension(
                                    $changedFields->{exten}->value(),
                                    __(q{extension}),
                                    EBox::Asterisk::Extensions->MEETINGMINEXTN,
                                    EBox::Asterisk::Extensions->MEETINGMAXEXTN,
                                   );

        if ($extensions->extensionExists($changedFields->{exten}->value())) {
            throw EBox::Exceptions::DataExists(
                      'data'  => __('extension'),
                      'value' => $changedFields->{exten}->value(),
                  );
        }
    }
}

sub getMeetings
{
    my ($self) = @_;

    my @meetings = ();

    foreach my $id (@{$self->enabledRows()}) {

        my $row = $self->row($id);

        my %meeting = ();

        my $exten = $row->valueByName('exten');
        $meeting{'exten'} = $exten;
        $meeting{'pin'} = $row->valueByName('pin');
        $meeting{'desc'} = $row->valueByName('desc');
        $meeting{'options'} = "$exten,M";
        push (@meetings, \%meeting);

    }

    return \@meetings;
}

1;
