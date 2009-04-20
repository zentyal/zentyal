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

# Class: EBox::Samba::Model::GeneralSettings
#
#   This model is used to configure file sharing eneral settings.
#

package EBox::Samba::Model::GeneralSettings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use Error qw(:try);

use EBox::Samba;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::Text;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Config;

use strict;
use warnings;

use base 'EBox::Model::DataForm';


sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

# Method: validateTypedRow
#
#       Override <EBox::Model::DataTable::validateTypedRow> method
#
sub validateTypedRow
{
    my ($self, $action, $oldParams, $newParams) = @_;

    my $netbios = exists $newParams->{'netbios'} ?
                         $newParams->{'netbios'}->value() :
                         $oldParams->{'netbios'}->value();

    my $workgroup = exists $newParams->{'workgroup'} ?
                           $newParams->{'workgroup'}->value() :
                           $oldParams->{'workgroup'}->value();

    if ($netbios eq $workgroup) {
		throw EBox::Exceptions::External(
			__('Netbios and workgroup must have different names'));
	}
}

sub _table
{
    my @tableHead =
    (
        new EBox::Types::Boolean(
            'fieldName' => 'pdc',
            'printableName' => __('Enable PDC'),
            'defaultValue' => 1,
            'editable' => 1,
        ),
        new EBox::Types::DomainName(
            'fieldName' => 'workgroup',
            'printableName' => __('Domain name'),
            'defaultValue' => 'EBOX',
            'editable' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'netbios',
            'printableName' => __('Netbios name'),
            'defaultValue' => EBox::Samba::defaultNetbios(),
            'editable' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Description'),
            'defaultValue' => 'EBox Samba Server',
            'editable' => 1,
        ),
        new EBox::Types::Union(
            'fieldName' => 'userquota',
            'printableName' => __('Quota limit'),
            'subtypes' => [
                new EBox::Types::Int(
                    'fieldName' => 'userquota_size',
                    'printableName' => __('Limited to'),
                    'defaultValue' => 100,
                    'trailingText' => __('Mb'),
                    'size' => 7,
                    'editable' => 1,
                ),
                new EBox::Types::Union::Text(
                    'fieldName' => 'userquota_disabled',
                    'printableName' => __('Disabled'),
                ),
            ],
        ),
        new EBox::Types::Boolean(
            'fieldName' => 'roaming',
            'printableName' => __('Enable roaming profiles'),
            'defaultValue' => 0,
            'editable' => 1,
        ),
        new EBox::Types::Select(
            'fieldName' => 'drive',
            'printableName' => __('Drive letter'),
            'populate' => \&_drive_letters,
            'editable' => 1,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'GeneralSettings',
        'printableTableName' => __('General settings'),
        'modelDomain' => 'Samba',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => __('On this page you can set different general settings for Samba'),
    };

    return $dataTable;
}

sub _drive_letters
{
    my @letters;

    foreach my $letter ('H'..'Z') {
        $letter .= ':';
        push (@letters, { value => $letter, printableValue => $letter });
    }

    return \@letters;
}

1;
