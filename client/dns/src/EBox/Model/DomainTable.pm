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
#   EBox::DNS::Model::DomainTable
#
#   This class inherits from <EBox::Model::DataTable> and represents
#   the object table which basically contains domains names, the IP
#   address for the domain and a reference to a member
#   <EBox::DNS::Model::HostnameTable>
#
package EBox::DNS::Model::DomainTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::DomainName;
use EBox::Types::HasMany;
use EBox::Types::HostIP;
use EBox::Sudo;

use EBox::Model::ModelManager;

use Net::IP;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

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
            new EBox::Types::HostIP
                            (
                                'fieldName' => 'ipaddr',
                                'printableName' => __('IP Address'),
                                'size' => '20',
                                'optional' => 1,
                                'editable' => 1
                            ),
          );

    my $dataTable = 
        { 
            'tableName' => 'DomainTable',
            'printableTableName' => __('Domains'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Dns/Controller/DomainTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Domains'),
            'printableRowName' => __('domain'),
            'sortedBy' => 'domain',
        };

    return $dataTable;
}

# Method: addDomain
#
#   Add a domain to the domainss table. Note this method must exist
#   because we must provide an easy way to migrate old dns module
#   to this new one.
#
# Parameters:
#
#   (NAMED)
#   domain_name - String domain's name
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

   my $id = $self->addRow('domain' => $name);

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

1;
