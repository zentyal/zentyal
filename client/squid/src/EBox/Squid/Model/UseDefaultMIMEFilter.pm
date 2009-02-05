# Copyright (C) 2009 Warp Networks S.L.
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


package EBox::Squid::Model::UseDefaultMIMEFilter;
use base 'EBox::Model::DataForm';

use strict;
use warnings;


use EBox::Gettext;

use EBox::Types::Boolean;



# eBox exceptions used 
use EBox::Exceptions::External;

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

# 
sub _table
{
    my @tableDesc = 
        ( 
         new EBox::Types::Boolean(
                  fieldName => 'useDefault',
                  printableName => __('Use default profile configuration'),
                  defaultValue => 0,
                  editable     => 1,
          ),


        );

    my $dataForm = {
        tableName          => 'UseDefaultMIMEFilter',
        printableTableName => __('Use default profile for MIME filtering'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        class              => 'dataForm',
    };



    return $dataForm;
}








1;

