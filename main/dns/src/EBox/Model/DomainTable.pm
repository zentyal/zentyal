# Copyright (C) 2008-2012 eBox Technologies S.L.
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

    my $name = $params->{'domain_name'};
    unless (defined($name)) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    my $id;
    my $address = $params->{'ipaddr'};

    if (defined($address)) {
        $id = $self->addRow('domain' => $name, 'ipaddr' => $address);
    } else {
        $id = $self->addRow('domain' => $name);
    }

    unless (defined($id)) {
        throw EBox::Exceptions::Internal("Couldn't add domain's name: $name");
    }

    my $hostnames = $params->{'hostnames'};
    return unless (defined($hostnames) and @{$hostnames} > 0);

    my $hostnameModel =
                EBox::Model::ModelManager::instance()->model('HostnameTable');

    $hostnameModel->setDirectory($self->{'directory'} . "/$id/hostnames");
    foreach my $hostname (@{$hostnames}) {
        $hostnameModel->addHostname(%{$hostname});
    }
}

# Method: addHost
#
#   Adds a new host to the domain
#
# Parameters:
#
#   host - A hash ref containing:
#             - hostname
#             - ipaddr
#             - subdomain (optional)
#             - alias (optional)
#             - readOnly (optional)
#
sub addHost
{
    my ($self, $domain, $host) = @_;

    unless (defined ($domain)) {
        throw EBox::Exceptions::MissingArgument('domain');
    }

    unless (defined ($host->{hostname})) {
        throw EBox::Exceptions::MissingArgument('hostname');
    }

    unless (defined ($host->{ipaddr})) {
        throw EBox::Exceptions::MissingArgument('ipaddr');
    }

    my %params = ( hostname => $host->{hostname},
                   ipaddr   => $host->{ipaddr},
                   subdomain => $host->{subdomain} );

    EBox::debug('Adding host record');
    my $domainRow = $self->_getDomainRow($domain);
    my $hostModel = $domainRow->subModel('hostnames');
    my $hostRowId = $hostModel->addRow(%params, readOnly => $host->{readOnly});
    my $hostRow   = $hostModel->row($hostRowId);

    my $aliasModel = $hostRow->subModel('alias');
    foreach my $alias (@{$host->{alias}}) {
        EBox::debug('Adding host alias');
        $aliasModel->addRow('alias' => $alias);
    }
}

# Method: delHost
#
#   Deletes a host from the domain
#
sub delHost
{
    my ($self, $domain, $host) = @_;

    unless (defined ($domain)) {
        throw EBox::Exceptions::MissingArgument('domain');
    }

    unless (defined $host->{hostname}) {
        throw EBox::Exceptions::MissingArgument('hostname');
    }

    my $rowId = undef;
    my $domainRow = $self->_getDomainRow($domain);
    my $model = $domainRow->subModel('hostnames');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);

        my $rowHostname  = $row->valueByName('hostname');
        my $rowIpaddr    = $row->valueByName('ipaddr');
        my $rowSubdomain = $row->valueByName('subdomain');

        if ((not defined ($host->{hostname})  or $rowHostname  eq $host->{hostname})  and
            (not defined ($host->{ipaddr})    or $rowIpaddr    eq $host->{ipaddr})    and
            (not defined ($host->{subdomain}) or $rowSubdomain eq $host->{subdomain})) {
            $rowId = $id;
            last;
        }
    }

    if (defined ($rowId)) {
        $model->removeRow($rowId);
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'hostname', value => $host->{hostname});
    }
}

# Method: addService
#
#   Add a new SRV record to the domain
#
# Parameters:
#
#   service - A hash ref containing:
#             - service (The name of the service, must match a name in /etc/services)
#             - protocol ('tcp' or 'udp')
#             - name (the domain name for which this record is valid)
#             - priority (optional)
#             - weight (optional)
#             - port (port number)
#             - target_type (custom or hostDomain)
#             - target (The name of a host domain or a FQDN)
#             - readOnly
#
sub addService
{
    my ($self, $domain, $service) = @_;

    unless (defined ($domain)) {
        throw EBox::Exceptions::MissingArgument('domain');
    }

    unless (defined ($service->{priority})) {
        $service->{priority} = 0;
    }

    unless (defined ($service->{weight})) {
        $service->{weight} = 0;
    }

    my $domainRow = $self->_getDomainRow($domain);
    my $model = $domainRow->subModel('srv');
    my %params = (service_name => $service->{service},
                  protocol => $service->{protocol},
                  name => $service->{name},
                  priority => $service->{priority},
                  weight => $service->{weight},
                  port => $service->{port});

    # Check if the service already exists
    my $add = 1;
    my $ids = $model->findAll(service_name => $params{service_name});
    foreach my $id (@{$ids}) {
        my $row = $model->row($id);
        my $matchAll = 1;
        foreach my $param (keys %params) {
            my $value = $row->valueByName($param);
            if ($params{$param} ne $value) {
                $matchAll = 0;
                last;
            }
        }
        if ($matchAll) {
            $add = 0;
            last;
        }
    }

    return unless ($add);

    if ($service->{target_type} eq 'domainHost' ) {
        $params{hostName_selected} = 'ownerDomain';
        my $hostsModel = $domainRow->subModel('hostnames');
        my $ids = $hostsModel->ids();
        foreach my $id (@{$ids}) {
            my $row = $hostsModel->row($id);
            my $rowHostName = $row->valueByName('hostname');
            if ($rowHostName eq $service->{target}) {
                $params{ownerDomain} = $id;
                last;
            }
        }
        unless ($params{ownerDomain}) {
            throw EBox::Exceptions::DataNotFound(
                    data => 'hostname',
                    value => $service->{target});
        }
    } elsif ($service->{target_type} eq 'custom' ) {
        $params{hostName_selected} = 'custom';
        $params{custom} = $service->{target};
    } else {
        throw EBox::Exceptions::MissingArgument('target_type');
    }

    EBox::debug('Adding SRV record');
    $model->addRow(%params, readOnly => $service->{readOnly});
}

# Method: delService
#
#   Deletes a SRV record from the domain
#
# Parameters:
#
#   service - A hash ref containing the service attributes
#             to check for deletion
#
sub delService
{
    my ($self, $domain, $service) = @_;

    if (not defined ($service->{service})) {
        throw EBox::Exceptions::MissingArgument('service');
    }

    my $rowId = undef;
    my $domainRow = $self->_getDomainRow($domain);
    my $model = $domainRow->subModel('srv');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);

        my $rowService  = $row->valueByName('service_name');
        my $rowProtocol = $row->valueByName('protocol');
        my $rowPriority = $row->valueByName('priority');
        my $rowWeight   = $row->valueByName('weight');
        my $rowPort     = $row->valueByName('port');

        if ((not defined ($service->{service})  or $rowService  eq $service->{service})  and
            (not defined ($service->{protocol}) or $rowProtocol eq $service->{protocol}) and
            (not defined ($service->{priority}) or $rowPriority eq $service->{priority}) and
            (not defined ($service->{weight})   or $rowWeight   eq $service->{weight})   and
            (not defined ($service->{port})     or $rowPort     eq $service->{port})) {
            $rowId = $id;
            last;
        }
    }

    if (defined ($rowId)) {
        $model->removeRow($rowId);
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'service_name', value => $service->{service});
    }
}

# Method: addText
#
#   Add a new TXT record to the domain
#
# Parameters:
#
#   txt - A hash ref containing:
#           - name
#           - data
#           - readOnly
#
sub addText
{
    my ($self, $domain, $txt) = @_;

    unless (defined ($domain)) {
        throw EBox::Exceptions::MissingArgument('domain');
    }

    my $domainRow = $self->_getDomainRow($domain);
    my $model = $domainRow->subModel('txt');
    my $id = $model->findRow(hostName => $txt->{name},
                             txt_data => $txt->{data});
    unless ($id) {
        my %params = ( hostName_selected => 'custom',
                       custom   => $txt->{name},
                       txt_data => $txt->{data} );
        $model->addRow( %params, readOnly => $txt->{readOnly});
    }
}

# Method: delText
#
#   Deletes a TXT record from the domain
#
# Parameters:
#
#   name - The record name
#
sub delText
{
    my ($self, $domain, $txt) = @_;

    if (not defined ($txt->{name})) {
        throw EBox::Exceptions::MissingArgument('name');
    }

    if (not defined ($txt->{data})) {
        throw EBox::Exceptions::MissingArgument('data');
    }

    my $domainRow = $self->_getDomainRow($domain);
    my $model = $domainRow->subModel('txt');
    my $rowId = $model->findRow(hostName => $txt->{name}, txt_data => $txt->{data});

    if (defined ($rowId)) {
        $model->removeRow($rowId);
    } else {
        throw EBox::Exceptions::DataNotFound(data => 'hostName', value => $txt->{name});
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
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $hostModel = $newRow->subModel('hostnames');
    my $ipaddr  = '127.0.0.1';
    if (defined($newRow->valueByName('ipaddr'))) {
        $ipaddr = $newRow->valueByName('ipaddr');
    }
    my $hostNameId = $hostModel->add(hostname => $hostname, ipaddr => $ipaddr);
    my $nsModel   = $newRow->subModel('nameServers');
    $nsModel->add(hostName => { ownerDomain => $hostname } );

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
                                'view' => '/DNS/View/HostnameTable',
                                'backView' => '/DNS/View/DomainTable',
                                'size' => '1',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'mailExchangers',
                                'printableName' => __('Mail Exchangers'),
                                'foreignModel' => 'MailExchanger',
                                'view' => '/DNS/View/MailExchanger',
                                'backView' => '/DNS/View/DomainTable',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'nameServers',
                                'printableName' => __('Name Servers'),
                                'foreignModel' => 'NameServer',
                                'view' => '/DNS/View/NameServer',
                                'backView' => '/DNS/View/DomainTable',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'txt',
                                'printableName' => __x('{txt} records', txt => 'TXT'),
                                'foreignModel' => 'Text',
                                'view' => '/DNS/View/Text',
                                'backView' => '/DNS/View/Text',
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'srv',
                                'printableName' => __x('Services'),
                                'foreignModel' => 'Services',
                                'view' => '/DNS/View/Services',
                                'backView' => '/DNS/View/Services',
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
            'printableTableName' => __('Domains'),
            'automaticRemove' => 1,
            'defaultController' => '/Dns/Controller/DomainTable',
            'HTTPUrlView'=> 'DNS/Composite/Global',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('domain'),
            'sortedBy' => 'domain',
            'help' => __('Here you can add the domains for this DNS server. '
                       . 'Each domain can have different hostnames with aliases '
                       . ' (A and CNAME) and other special records (MX, NS, TXT and SRV).'),
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

# Method: _getDomainRow
#
#   Return the row for the specified domain name
#
# Throws:
#
#   DataNotFoundException
#
sub _getDomainRow
{
    my ($self, $domain) = @_;

    my $domainRow = undef;
    foreach my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $rowDomain = $row->valueByName('domain');
        if ($rowDomain eq $domain) {
            $domainRow = $row;
            last;
        }
    }

    unless (defined ($domainRow)) {
        throw EBox::Exceptions::DataNotFound(data => 'domain', value => $domain);
    }

    return $domainRow;
}

1;
