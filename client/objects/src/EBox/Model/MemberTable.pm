# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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
#   EBox::Object::Model::ObjectTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   membembers beloging to an object
#
#   
package EBox::Objects::Model::MemberTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Sudo;
use EBox::Types::Text;
use EBox::Types::MACAddr;
use EBox::Types::IPAddr;
use EBox::Model::ModelManager;

use EBox::Exceptions::External;

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

            new EBox::Types::Text
                            (
                                'fieldName' => 'name',
                                'printableName' => __('Name'),
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::IPAddr
                            (
                                'fieldName' => 'ipaddr',
                                'printableName' => __('IP Address'),
                                'editable'      => 1,
                            ),
            new EBox::Types::MACAddr
                            (
                                'fieldName' => 'macaddr',
                                'printableName' => __('MAC Address'),
                                'editable'      => 1,
                                'optional' => 1
                            ),


          );

    my $dataTable = 
        { 
            'tableName' => 'MemberTable',
            'printableTableName' => __('Members'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Objects/Controller/MemberTable',
            'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Objects'),
            'printableRowName' => __('member'),
            'sortedBy' => 'name',
        };

    return $dataTable;
}

# Method: validateRow
#
#      Override <EBox::Model::DataTable::validateRow> method
#
sub validateRow()
{
    my ($self, $action, %params) = @_;

    my $id = $params{'id'};
    my $ip = $params{'ipaddr_ip'};
    my $mask = $params{'ipaddr_mask'};
    my $mac = $params{'macaddr'};

    if (defined($mac) and $mask ne '32') {
        throw EBox::Exceptions::External(
            __("You can only use MAC addresses with hosts"));
    }
    
    checkIP($ip, __('network address'));
    checkCIDR("$ip/$mask", __('network address'));

    if ($self->_alreadyInObject($id, $ip, $mask)) {
         throw EBox::Exceptions::DataExists(
                                            'data' => __('network address'),
                                            'value' => "$ip/$mask");
    }

}

# Method: alreadyInObject
#
#       Checks if a member (i.e: its ip and mask) are already in some object
#
# Parameters:
#
#	    (POSITIONAL)
#	    
#        memberId - memberId
#       ip - IPv4 address
#       mask - network masl
#
# Returns:
#   
#       booelan - true if it's already in other object, otherwise false
sub _alreadyInObject # (ip, mask) 
{
    my ($self, $memberId, $iparg, $maskarg) = @_;
     
    my $model = EBox::Model::ModelManager->instance()->model('ObjectTable');
    return unless (defined($model));
    my $objs = $model->printableValueRows();

    for my $obj (@{$objs}) {
        next unless (exists $obj->{'members'}->{'values'});
        for my $member (@{$obj->{'members'}->{'values'}}) {
            next if (defined($memberId) and ($member->{'id'} eq $memberId));	
            my $memaddr = new Net::IP($member->{'ipaddr'});
            my $new = new Net::IP("$iparg/$maskarg");
            if ($memaddr->overlaps($new) != $IP_NO_OVERLAP){
                return 1;
            }
        }
    }
    return undef;
}


1;

