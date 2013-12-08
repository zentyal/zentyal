# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::IPsec::Model::Connections;

# Class: EBox::IPsec::Model::Connections
#
#   TODO: Document class
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HasMany;

# Group: Public methods

# Constructor: new
#
#       Create the new Connections model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::IPsec::Model::Connections> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);

    return $self;
}

sub tunnels
{
    my ($self) = @_;

    my @tunnels;
    foreach my $id (@{$self->enabledRows()}) {
        my $row = $self->row($id);
        my $conf = $row->elementByName('configuration')->foreignModelInstance();
        my @confComponents = qw(ConfGeneral ConfPhase1 ConfPhase2);

        my %settings;
        foreach my $name (@confComponents) {
            my $elements = $conf->componentByName($name, 1)->row()->elements();
            foreach my $element (@{ $elements }) {
                my $fieldName = $element->fieldName();
                # Value returns array with (ip, netmask)
                my $fieldValue = join ('/', $element->value());
                $settings{$fieldName} = $fieldValue;
            }
        }
        $settings{'name'}    = $row->valueByName('name');
        $settings{'comment'} =  $row->valueByName('comment');

        push @tunnels, \%settings;
    }

    return \@tunnels;
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
         new EBox::Types::Text(
                                   fieldName => 'name',
                                   printableName => __('Name'),
                                   size => 12,
                                   unique => 1,
                                   editable => 1,
                              ),
         new EBox::Types::HasMany(
                                   fieldName     => 'configuration',
                                   printableName => __('Configuration'),
                                   foreignModel => 'ipsec/Conf',
                                   foreignModelIsComposite => 1,

                                   view => '/IPsec/Composite/Conf',
                                   backView => '/IPsec/View/Connections',
                              ),
         new EBox::Types::Text(
                                   fieldName => 'comment',
                                   printableName => __('Comment'),
                                   size => 24,
                                   unique => 0,
                                   editable => 1,
                                   optional => 1,
                              ),
        );

    my $dataTable =
    {
        tableName => 'Connections',
        pageTitle => __('IPsec Connections'),
        printableTableName => __('IPsec Connections'),
        printableRowName => __('IPsec connection'),
        defaultActions => ['add', 'del', 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        class => 'dataTable',
        modelDomain => 'IPsec',
        enableProperty => 1,
        defaultEnabledValue => 1,
        help => __('IPsec connections allow to deploy secure tunnels between ' .
                   'different subnetworks. This protocol is vendor independant ' .
                   'and will connect Zentyal with other security devices.'),
    };

    return $dataTable;
}




1;
