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


package EBox::Asterisk::Model::Settings;

# Class: EBox::Asterisk::Model::Settings
#
#       Form to set the general configuration settings for the Asterisk server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Types::Boolean;
use EBox::Asterisk::Extensions;

# Group: Public methods

# Constructor: new
#
#       Create the new Settings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Settings> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


# Method: validateTypedRow
#
#      Check the row to add or update if contains a valid extension
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the extension is not valid
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if ( exists $changedFields->{voicemailExtn} ) {
        if ( $changedFields->{voicemailExtn}->value() ne EBox::Asterisk::Extensions->VMDFTLEXTN ) {

            EBox::Asterisk::Extensions->checkExtension(
                                            $changedFields->{voicemailExtn}->value(),
                                            __(q{extension}),
                                            EBox::Asterisk::Extensions->MEETINGMINEXTN,
                                            EBox::Asterisk::Extensions->MEETINGMAXEXTN,
                                        );

            my $extensions = new EBox::Asterisk::Extensions;
            if ($extensions->extensionExists($changedFields->{voicemailExtn}->value())) {
                throw EBox::Exceptions::DataExists(
                          'data'  => __('Voicemail extension'),
                          'value' => $changedFields->{voicemailExtn}->value(),
                      );
            }

        }
    }
}


# Group: Private methods

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
       new EBox::Types::Boolean(
                                fieldName     => 'demoExtensions',
                                printableName => __('Enable demo extensions'),
                                editable      => 1,
                                defaultValue  => 1,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'outgoingCalls',
                                printableName => __('Enable outgoing calls'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Int(
                                fieldName     => 'voicemailExtn',
                                printableName => __('Voicemail extension'),
                                editable      => 1,
                                size          => 4,
                                defaultValue  => EBox::Asterisk::Extensions->VMDFTLEXTN,
                               ),
      );

    my $dataTable =
    {
        tableName          => 'Settings',
        printableTableName => __('General settings'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('General Asterisk server configuration'),
        messages           => {
                                  update => __('General Asterisk server configuration updated'),
                              },
        modelDomain        => 'Asterisk',
    };

    return $dataTable;

}

1;
