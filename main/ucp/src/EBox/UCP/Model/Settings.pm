package EBox::UCP::Model::Settings;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;

use EBox::Types::Text;
use EBox::Types::MailAddress;
use EBox::Types::Password;

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
        new EBox::Types::MailAddress(
            'fieldName' => 'email',
            'printableName' => __('Email'),
            'size' => '30',
            'optional' => 0,
            'editable' => 1,
        ),
        new EBox::Types::Password(
            fieldName   => 'password',
            printableName => __('Password'),
            confirmPrintableName => __('Confirm Password'),
            hiddenOnViewer => 1,
            editable      => 1,
            disableAutocomplete => 1,
            optional      => 0,
            optionalLabel => 0,
            size          => 16,
            minLength     => 6,
            help => __("Your UCP's password.")
        ),
        new EBox::Types::Text(
            fieldName => 'apiId',
            printableName => __('Your API id.'),
            editable => 1,
            size => '8',
            help => __("Your UCP client's id."),
        ),
        new EBox::Types::Text(
            fieldName => 'apiKey',
            printableName => __('API key'),
            editable => 1,
            size => '250',
            help => __("Your UCP client's id."),
        ),
    );

    my $dataTable =
    {
        tableName => 'Settings',
        printableTableName => __('Settings'),
        pageTitle => $self->parentModule()->printableName(),
        defaultActions => [ 'editField' ],
        modelDomain => 'UCP',
        tableDescription => \@fields,
        help => __('Use this page to setup your UCP connection.'),
    };

    return $dataTable;
}

1;
