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
#   EBox::Squid::Model::ConfigureLogDataTable
#
#   This class is used as a model to describe a table which will be
#   used to select the logs domains the user wants to enable/disable.
#
#   It subclasses <EBox::Model::DataTable>
#
#  
# 

package EBox::Mail::Model::SMTPOptions;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Types::Boolean;
use EBox::Types::Host;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Port;
use EBox::Types::Composite;

# eBox exceptions used 
use EBox::Exceptions::External;

use constant MAX_MSG_SIZE                          => '100';


sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)    
#   enabled (EBox::Types::Boolean>)
# 
# The only avaiable action is edit and only makes sense for 'enabled'.
# 
sub _table
{
    my @tableDesc = 
        ( 
         new EBox::Types::Host(
                               fieldName => 'smarthost',
                               printableName => __('Smarthost to send mail'),
                               optional => 1,
                               editable => 1,
                              ),
         new EBox::Types::Union(
                              fieldName => 'smarthostAuth',
                              printableName => 
                                __('Smarthost authentication'),
                              editable => 1,
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'none',
                                  'printableName' => __('None'),
                                  ),
                              new EBox::Types::Composite(
                                   fieldName => 'userandpassword',
                                   printableName => __('User and password'),
                                   editable => 1,
                                   showTypeName => 0,
                                   types => [
                                             new EBox::Types::Text(
                                              fieldName => 'username',
                                              printableName => __('User'),
                                              size => 20,
                                              editable => 1,
                                                                  ),
                                             new EBox::Types::Password(
                                              fieldName => 'password',
                                              printableName => __('Password'),
                                              size => 12,
                                              editable => 1,                                            
                                                                  ),

                                            ],
                                                        )
                                  ],
             ),
         new EBox::Types::Union(
                              fieldName => 'maxSize',
                              printableName => 
                                __('Maximum message size accepted'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'unlimited',
                                  'printableName' => __('Unlimited size'),
                                  ),
                              new EBox::Types::Int(
                                  'fieldName' => 'size',
                                  'printableName' => __('size in Mb'),
                                  'editable'  => 1,
                                  'max'       => MAX_MSG_SIZE, 
                                      ),
                                  ],
             ),
         

        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Options'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}


#
# Method: maxMsgSize
#
#  Returns:
#   - the maximum message size allowed by the server in Mb or zero if we do
#      not have any limit set
#
sub maxMsgSize
{
    my ($self) = @_;

    my $maxSize = $self->row()->elementByName('maxSize');
    if ($maxSize->selectedType eq 'unlimited') {
        return 0;
    }

    my $size = $maxSize->subtype()->value();
    return $size;
}


1;

