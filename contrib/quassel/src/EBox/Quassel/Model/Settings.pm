package EBox::Quassel::Model::Settings;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;

use EBox::Types::Text;
use EBox::Types::Boolean;

# Method: _table
#
# Overrides:
#
#       <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @fields = (
        new EBox::Types::Boolean(
            fieldName => 'booleanField',
            printableName => __('Example boolean field'),
            editable => 1,
            help => __('This field is an example.'),
        ),
        new EBox::Types::Text(
            fieldName => 'textField',
            printableName => __('Example text field'),
            editable => 1,
            size => '8',
            help => __('This field is another example.'),
        ),
    );

    my $dataTable =
    {
        tableName => 'Settings',
        printableTableName => __('Settings'),
        pageTitle => $self->parentModule()->printableName(),
        defaultActions => [ 'editField' ],
        modelDomain => 'Quassel',
        tableDescription => \@fields,
        help => __('This is the help of the model'),
    };

    return $dataTable;
}

1;
