# Copyright (C) 2009-2014 Zentyal S.L.
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

package EBox::Network::Model::DynDNS;

use base 'EBox::Model::DataForm';

use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::DomainName;
use EBox::Types::Password;
use EBox::Types::Select;
use EBox::Types::Text;

our %SERVICES = (
    dyndns => {
        printableValue => 'DynDNS',
        protocol => 'dyndns2',
        server => 'members.dyndns.com',
        use => 'web',
        web => 'checkip.dyndns.com',
        web_skip => 'Current IP Address:',
        require_info => 1,
    },
    zoneedit => {
        printableValue => 'ZoneEdit',
        protocol => 'zoneedit1',
        server => 'dynamic.zoneedit.com',
        use => 'web',
        web => 'dynamic.zoneedit.com/checkip.html',
        web_skip => 'Current IP Address:',
        require_info => 1,
    },
    easydns => {
        printableValue => 'EasyDNS',
        protocol => 'easydns',
        server => 'members.easydns.com',
        use => 'web',
        web => 'checkip.dyndns.com',
        web_skip => 'Current IP Address:',
        require_info => 1,
    },
#    disabled until ddclient bug #30 is fixed
#       http://sourceforge.net/apps/trac/ddclient/ticket/30
#     dnspark => {
#         printableValue => 'dnspark.com',
#         protocol => 'dnspark',
#         server => 'www.dnspark.com',
#         use => 'web',
#         web => 'ipdetect.dnspark.com',
#         web_skip => 'Current Address:',
#         require_info => 1,
#     },
    joker => {
        printableValue => 'Joker.com',
        protocol => 'dyndns2',
        server => 'svc.joker.com',
        use => 'web',
        web => 'svc.joker.com/nic/checkip',
        web_skip => 'Current IP Address:',
        require_info => 1,
    },
    noip => {
        printableValue => 'no-ip.com',
        protocol => 'noip',
        server => 'dynupdate.no-ip.com',
        use => 'web',
        web => 'http://ip1.dynupdate.no-ip.com/',
        require_info => 1,
    },
);

# Group: Public methods

# Method: validateTypedRow
#
#   Check the used service requires info from form
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if ( $allFields->{enableDDNS}->value()
         and $SERVICES{$allFields->{service}->value()}->{require_info} ) {
        # Check the username, password and domain name are set
        foreach my $field (qw(username password hostname)) {
            unless ( $allFields->{$field}->value() ) {
                throw EBox::Exceptions::MissingArgument( $allFields->{$field}->printableName() );
            }
        }
    }
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
           'editable'      => 1,
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
           'optional'      => 1,
           ),
       new EBox::Types::Password(
           'fieldName'     => 'password',
           'printableName' => __('Password'),
           'editable'      => 1,
           'optional'      => 1,
           ),
       new EBox::Types::DomainName(
           'fieldName'     => 'hostname',
           'printableName' => __('Hostname'),
           'editable'      => 1,
           'optional'      => 1,
           ),
      );

      my $dataTable = {
                       tableName          => 'DynDNS',
                       disableAutocomplete => 1,
                       pageTitle          => ('Dynamic DNS'),
                       printableTableName => __('Configuration'),
                       defaultActions     => [ 'editField', 'changeView' ],
                       tableDescription   => \@tableHeader,
                       class              => 'dataForm',
                       help               => __('You should select your provider from the list '
                                               . 'and enter your account data. '
                                               . 'You also need to enable it in order to work.'),
                       modelDomain        => 'Network',
                     };

      return $dataTable;

}

# Group: Callback functions

# Service populate function
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

1;
