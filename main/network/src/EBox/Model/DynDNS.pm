# Copyright (C) 2009-2011 eBox Technologies S.L.
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
use EBox::Types::Select;
use EBox::Types::Text;

our %SERVICES = (
    dyndns => {
        printableValue => 'DynDNS',
        protocol => 'dyndns2',
        server => 'members.dyndns.org',
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
    dnspark => {
        printableValue => 'dnspark.com',
        protocol => 'dnspark',
        server => 'www.dnspark.com',
        use => 'web',
        web => 'ipdetect.dnspark.com',
        web_skip => 'Current Address:',
        require_info => 1,
    },
    joker => {
        printableValue => 'Joker.com',
        protocol => 'dyndns2',
        server => 'svc.joker.com',
        use => 'web',
        web => 'svc.joker.com/nic/checkip',
        web_skip => 'Current IP Address:',
        require_info => 1,
    },
    cloud => {
        printableValue => 'Zentyal Cloud',
        protocol => 'dyndns2',
        use => 'web',
        web => 'checkip.dyndns.com',
        web_skip => 'Current IP Address:',
        require_info => 0,
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

# Method: viewCustomizer
#
#    Overrides to disable the remainder fields if service selected is
#    Zentyal Cloud
#
# Overrides:
#
#    <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    my $remainderFields = [ qw(username password hostname) ];

    my $serviceAction = {};
    foreach my $serviceKey (keys %SERVICES) {
        if ( $SERVICES{$serviceKey}->{require_info} ) {
            $serviceAction->{$serviceKey} = { enable => $remainderFields };
        } else {
            $serviceAction->{$serviceKey} = { disable => $remainderFields };
        }
    }

    $customizer->setOnChangeActions( { service => $serviceAction } );
    unless ( $self->_isSubscribed() ) {
        $customizer->setPermanentMessage(_message());
    }

    return $customizer;

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
        if ( $serviceKey eq 'cloud' ) {
            $providers[-1]->{disabled} = not _isSubscribed();
        }
    }
    return \@providers;
}

# Group: Private methods

sub _isSubscribed
{

    my $gl = EBox::Global->getInstance(1);
    if ( $gl->modExists('remoteservices') ) {
        my $rs = $gl->modInstance('remoteservices');
        if ( $rs->eBoxSubscribed() ) {
            return 1;
        }
    }
    return 0;

}

sub _message
{
    return __sx('You can configure your Dynamic DNS provider here. If you have '
                . 'already subscribed your Zentyal server, the provider is Zentyal '
                . 'Cloud. If not, consider getting the free {ohb}Basic Server Subscription{ch}: '
                . 'it includes Dynamic DNS feature that gives your server human-readable public '
                . 'hostname (yourserver.zentyal.me).',
                ohb => '<a href="' . BASIC_URL . '" target="_blank">',
                ch  => '</a>');
}

1;
