# Copyright (C) 2009-2010 eBox Technologies S.L.
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

use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
use EBox::Types::Password;
use EBox::Types::Text;

our %SERVICES = (
    dyndns => {
        printableValue => 'DynDNS',
        protocol => 'dyndns2',
        server => 'members.dyndns.org',
        use => 'web',
        web => 'checkip.dyndns.com',
        web_skip => 'Current IP Address:',
    },
    zoneedit => {
        printableValue => 'ZoneEdit',
        protocol => 'zoneedit1',
        server => 'dynamic.zoneedit.com',
        use => 'web',
        web => 'dynamic.zoneedit.com/checkip.html',
        web_skip => 'Current IP Address:',
    },
    easydns => {
        printableValue => 'EasyDNS',
        protocol => 'easydns',
        server => 'members.easydns.com',
        use => 'web',
        web => 'checkip.dyndns.com',
        web_skip => 'Current IP Address:',
    },
    dnspark => {
        printableValue => 'dnspark.com',
        protocol => 'dnspark',
        server => 'www.dnspark.com',
        use => 'web',
        web => 'ipdetect.dnspark.com',
        web_skip => 'Current Address:',
    },
    joker => {
        printableValue => 'Joker.com',
        protocol => 'dyndns2',
        server => 'svc.joker.com',
        use => 'web',
        web => 'svc.joker.com/nic/checkip',
        web_skip => 'Current IP Address:',
    },
);

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
    foreach my $serviceKey (keys %SERVICES) {
        push @providers, {
            value => $serviceKey,
            printableValue => $SERVICES{$serviceKey}->{printableValue}
        };
    }
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
                       pageTitle          => ('Dynamic DNS'),
                       printableTableName => __('Configuration'),
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
