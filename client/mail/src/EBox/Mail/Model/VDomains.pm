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

package EBox::Mail::Model::VDomains;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

# Class: EBox::Mail::Model::VDomains
#
#       This a class used it as a proxy for the vodmains stored in LDAP.
#       It is meant to improve the user experience when managing vdomains,
#       but it's just a interim solution. An integral approach needs to 
#       be done.
#       
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::DomainName;
#use EBox::Types::Link;


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

                new EBox::Types::DomainName(
                                        'fieldName' => 'vdomain',
                                        'printableName' => __('Name'),
                                        'size' => '20',
                                        'editable' => 1,
                                        'unique' => 1,
                                      ),
#                 new EBox::Types::Link(
#                                         'fieldName' => 'edit',
#                                         'printableName' => __('Edit'),
#                                       ),

         );

        my $dataTable = 
                { 
                        'tableName' => 'VDomains',
                        'printableTableName' => __('Mail virtual domains'),
                        'defaultController' =>
            '/ebox/Mail/Controller/VDomains',
                        'defaultActions' =>
                                ['add', 'del', 'changeView'],
                        'tableDescription' => \@tableHead,
                        'menuNamespace' => 'Mail/VDomains',
                        'automaticRemove'  => 1,
                        'help' => '',
                        'printableRowName' => __('virtual domain'),
                        'sortedBy' => 'vdomain',
                };

        return $dataTable;
}

# Method: precondition
#       
#       Check if the module is configured
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
sub precondition
{
        my $mail = EBox::Global->modInstance('mail');
        return $mail->configured();
}

# Method: preconditionFailMsg
#       
#       Check if the module is configured
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
sub preconditionFailMsg
{
        return __('You must enable the module mail in the module ' .
                  'status section in order to use it.');
}





1;

