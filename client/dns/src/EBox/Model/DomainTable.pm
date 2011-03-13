# Copyright (C) 2008-2011 eBox Technologies S.L.
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
#   EBox::DNS::Model::DomainTable
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which basically contains domains names, the IP
#   address for the domain and a reference to a member
#   <EBox::DNS::Model::HostnameTable>
#
package EBox::DNS::Model::DomainTable;

use EBox::DNS::View::DomainTableCustomizer;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::HasMany;
use EBox::Types::HostIP;
use EBox::Types::Text;

use EBox::Model::ModelManager;

# Dependencies
use Crypt::OpenSSL::Random;
use MIME::Base64;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

# Group: Public methods

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: addDomain
#
#   Add a domain to the domains table. Note this method must exist
#   because we must provide an easy way to migrate old dns module
#   to this new one.
#
# Parameters:
#
#   (NAMED)
#   domain_name - String domain's name
#   ipaddr      - String domain's IP address *(Optional)* Default value: undef
#   hostnames  - array ref containing the following hash ref in each value:
#
#                name        - host's name
#                ip          - hostr's ipaddr
#                aliases     - array ref containing alias names;
#
#   Example:
#
#       domain_name => 'foo.com',
#       hostnames   => [
#                       { 'name'         => 'bar',
#                         'ip'           => '192.168.1.2',
#                         'aliases'      => [
#                                             { 'bar',
#                                               'b4r'
#                                             }
#                                           ]
#                       }
#                      ]
sub addDomain
{
    my ($self, $params) = @_;

    my $name = delete $params->{'domain_name'};
    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $id;
    my $address = delete $params->{'ipaddr'};

    if (defined($address)) {
        $id = $self->addRow('domain' => $name, 'ipaddr' => $address);
    } else {
        $id = $self->addRow('domain' => $name);
    }

    unless (defined($id)) {
        throw EBox::Exceptions::Internal("Couldn't add domain's name: $name");
    }

    my $hostnames = delete $params->{'hostnames'};
    return unless (defined($hostnames) and @{$hostnames} > 0);

    my $hostnameModel =
   		EBox::Model::ModelManager::instance()->model('HostnameTable');

    $hostnameModel->setDirectory($self->{'directory'} . "/$id/hostnames");
    foreach my $hostname (@{$hostnames}) {
        $hostnameModel->addHostname(%{$hostname});
    }
}

# Method: addedRowNotify
#
#    Override to generate the shared key but it is only used by
#    dynamic zones
#
# Overrides:
#
#    <EBox::Model::DataTable::addedRowNotify>
#
sub addedRowNotify
{
    my ($self, $newRow) = @_;

    # Generate the TSIG key
    my $secret = $self->_generateSecret();
    $newRow->elementByName('tsigKey')->setValue($secret);
    $newRow->store();

    # Generate the NS record and its A record
    my $hostModel = $newRow->subModel('hostnames');
    my $nsIPAddr  = '127.0.0.1';
    if (defined($newRow->valueByName('ipaddr'))) {
        $nsIPAddr = $newRow->valueByName('ipaddr');
    }
    my $hostNameId = $hostModel->add(hostname => 'ns', ipaddr => $nsIPAddr);
    my $nsModel   = $newRow->subModel('nameServers');
    $nsModel->add(hostName => { ownerDomain => 'ns' } );

}

# Method: viewCustomizer
#
#     Use our own customizer to hide dynamic field in add form
#
# Overrides:
#
#     <EBox::Model::Component::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::DNS::View::DomainTableCustomizer();
    $customizer->setModel($self);
    return $customizer;

}

# Group: Protected methods

sub _table
{
    my @tableHead =
        (

            new EBox::Types::DomainName
                            (
                                'fieldName' => 'domain',
                                'printableName' => __('Domain'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'hostnames',
                                'printableName' => __('Hostnames'),
                                'foreignModel' => 'HostnameTable',
                                'view' => '/ebox/DNS/View/HostnameTable',
                                'backView' => '/ebox/DNS/View/DomainTable',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'mailExchangers',
                                'printableName' => __('Mail Exchangers'),
                                'foreignModel' => 'MailExchanger',
                                'view' => '/ebox/DNS/View/MailExchanger',
                                'backView' => '/ebox/DNS/View/DomainTable',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'nameServers',
                                'printableName' => __('Name Servers'),
                                'foreignModel' => 'NameServer',
                                'view' => '/ebox/DNS/View/NameServer',
                                'backView' => '/ebox/DNS/View/DomainTable',
                             ),
            new EBox::Types::HostIP
                            (
                                'fieldName' => 'ipaddr',
                                'printableName' => __('IP Address'),
                                'size' => '20',
                                'optional' => 1,
                                'editable' => 1
                            ),
            new EBox::Types::Boolean(
                # This field indicates if the domain is dynamic, so not editable from interface
                                'fieldName'     => 'dynamic',
                                'printableName' => __('Dynamic'),
                                'editable'      => 0,
                                'hidden'        => 0,
                                'defaultValue'  => 0,
                                'help'          => __('A domain is dynamic when the DHCP server '
                                                      . 'updates the domain'),
                                'HTMLViewer'    => '/ajax/viewer/booleanViewer.mas',
                                ),
            new EBox::Types::Text(
                # This field is filled when the zone is dynamic and
                # indicates the TSIG key for the direct mapping and
                # the reversed zones for this domain hosts
                                'fieldName'    => 'tsigKey',
                                'editable'     => 0,
                                'optional'     => 1,
                                'hidden'       => 1,
                               ),
          );

    my $dataTable =
        {
            'tableName' => 'DomainTable',
            'printableTableName' => __('List of Domains'),
	    'pageTitle' => __('DNS'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Dns/Controller/DomainTable',
            'HTTPUrlView'=> 'DNS/View/DomainTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('domain'),
            'sortedBy' => 'domain',
        };

    return $dataTable;
}

# Group: Private methods

# Generate the secret key using HMAC-MD5 algorithm
sub _generateSecret
{
    my ($self) = @_;

    Crypt::OpenSSL::Random::random_seed(time() . rand(2**512));
    Crypt::OpenSSL::Random::random_egd('/dev/urandom');

    # Generate a key of 512 bits = 64Bytes
    return MIME::Base64::encode(Crypt::OpenSSL::Random::random_bytes(64), '');

}

1;
