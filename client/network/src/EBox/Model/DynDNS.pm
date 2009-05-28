# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Network::Model::DynDNS;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
use EBox::Types::Password;
use EBox::Types::Text;

# Dependencies

# Group: Public methods

# Constructor: new
#
#     Create the DynDNS model
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Network::Model::DynDNS>
#
sub new
{

      my $class = shift;

      my $self = $class->SUPER::new(@_);

      bless ( $self, $class );

      return $self;

}


sub services
{
      my @providers;
      push @providers, { 'value' => 'dyndns', printableValue => 'DynDNS' };
      push @providers, { 'value' => 'zoneedit', printableValue => 'ZoneEdit' };
      push @providers, { 'value' => 'easydns', printableValue => 'EasyDNS' };
      push @providers, { 'value' => 'dnspark', printableValue => 'dnspark.com' };
      push @providers, { 'value' => 'joker', printableValue => 'Joker.com' };
      return \@providers;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableHeader =
      (
       new EBox::Types::Boolean(
           'fieldName'     => 'enableDDNS',
           'printableName' => __('Enable Dynamic DNS'),
           'editable'      => '1',
           ),
       new EBox::Types::Select(
           'fieldName'     => 'service',
           'printableName' => __('Service'),
           'populate'      => \&services,
           'editable'      => 1,
           ),
       new EBox::Types::Text(
           'fieldName'     => 'username',
           'printableName' => __('Username'),
           'editable'      => 1,
           ),
       new EBox::Types::Password(
           'fieldName'     => 'password',
           'printableName' => __('Password'),
           'editable'      => 1,
           ),
       new EBox::Types::DomainName(
           'fieldName'     => 'hostname',
           'printableName' => __('Hostname'),
           'editable'      => 1,
           ),
      );

      my $dataTable = {
                       tableName          => 'DynDNS',
                       printableTableName => __('Dynamic DNS'),
                       defaultActions     => [ 'editField', 'changeView' ],
                       tableDescription   => \@tableHeader,
                       class              => 'dataForm',
                       help               => __('All gateways you enter here must be reachable '
                                               . 'through one of the network interfaces '
                                               . 'currently configured'),
                       modelDomain        => 'Network',
                     };

      return $dataTable;

}

1;
