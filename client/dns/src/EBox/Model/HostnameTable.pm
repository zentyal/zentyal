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
#   EBox::DNS::Model::HostnameTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains domains names and a reference
#   to a member <EBox::DNS::Model::DomainTable>
#
#   
package EBox::DNS::Model::HostnameTable;

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
                                'fieldName' => 'hostname',
                                'printableName' => __('Hostname'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::HostIP
                            (
                                'fieldName' => 'ipaddr',
                                'printableName' => __('IP Address'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::HasMany
                            (
                                'fieldName' => 'alias',
                                'printableName' => __('Alias'),
                                'foreignModel' => 'AliasTable',
                                'view' => '/ebox/DNS/View/AliasTable',
                                'backView' => '/ebox/DNS/View/AliasTable',
                                'size' => '1',
                             )
          );

    my $dataTable = 
        {
            'tableName' => 'HostnameTable',
            'printableTableName' => __('Hostnames'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Dns/Controller/HostnameTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Hostnames'),
            'printableRowName' => __('hostname'),
            'sortedBy' => 'hostname',
        };

    return $dataTable;
}

# Method: addHostname
#
#   Add a hostname to the hostnames table. Note this method must exist
#   because we must provide an easy way to migrate old dns module
#   to this new one.
#
# Parameters:
#
#   (NAMED)
#   hostname   - String host name
#   ip         - String host ipaddr
#   aliases    - array ref containing the alias names
#
#   Example:
#
#      'hostname'     => 'bar',
#      'ip'           => '192.168.1.2',
#      'aliases'      => [
#                         { 'bar',
#                           'b4r'
#                         }
#                        ]
sub addHostname
{
   my ($self, %params) = @_;

   my $name = delete $params{'hostname'};
   my $ip = delete $params{'ip'};

   return unless (defined($name) and defined($ip));

   my $id = $self->addRow('hostname' => $name, 'ipaddr' => $ip);

   unless (defined($id)) {
       throw EBox::Exceptions::Internal("Couldn't add hostname: $name");
   }

   my $aliases = delete $params{'aliases'};
   return unless (defined($aliases) and @{$aliases} > 0);

   my $aliasModel =
   		EBox::Model::ModelManager::instance()->model('AliasTable');

   $aliasModel->setDirectory($self->{'directory'} . "/$id/alias");
   foreach my $alias (@{$aliases}) {
       $aliasModel->addRow('alias' => $alias);
   }
}

1;
