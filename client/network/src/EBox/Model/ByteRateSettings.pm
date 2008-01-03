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

# Class:
#
#   EBox::Network::Model::ByteRateSettings
#
#   This class is used to manage the traffic rate monitoring general settings
#
#   It subclasses <EBox::Model::DataTable>
#

package EBox::Network::Model::ByteRateSettings;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Network::Report::ByteRate;
use EBox::Types::Select;

# Group: Public methods

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: formSubmitted
#
# Overrides:
#
#        <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{

    my ($self, $oldRow) = @_;

    # Restart monitoring when settings are changed
    EBox::Network::Report::ByteRate->_regenConfig();

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#        <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableDesc =
        (
            new EBox::Types::Select(
                    fieldName => 'iface',
                    printableName => __('Interface to listen'),
                    editable => 1,
		    populate       => \&_populateIfaceSelect,
		    defaultValue   => 'all',
                 ),
        );

      my $dataForm = {
                      tableName          => 'ByteRateSettings',
                      printableTableName => __('Traffic rate monitor settings'),
		      modelDomain        => 'Network',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      help               => __('Changes will be applied immediately to the '
                                               . 'traffic rate monitor'),
		      messages           => {
			    update => __('Settings changed'),
			   },
                     };



    return $dataForm;
}

# Group: Private methods

sub _populateIfaceSelect
{
    my $network = EBox::Global->modInstance('network');
    my @extIfaces = @{ $network->ExternalIfaces() };
    my @intIfaces = @{ $network->InternalIfaces() };

    my @options = map {
        { value => $_,
            printableValue => __x( "{iface} (internal interface)",
                                   iface => $_)
        }
    } @intIfaces;

    push @options, map {
        { value => $_,
            printableValue => __x("{iface} (external interface)",
                                  iface => $_)
        }
    } @extIfaces;

    push @options,
      {
       value => 'all', printableValue => __('all')};

    return \@options;

}

1;

