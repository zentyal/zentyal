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
#   EBox::Squid::Model::ContentFilterThreshold
#
#   This class is used as a model to describe a table which will be
#   used to select the logs domains the user wants to enable/disable.
#
#   It subclasses <EBox::Model::DataTable>
#
#  
# 

package EBox::Squid::Model::ContentFilterThreshold;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;



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

	   new EBox::Types::Select(
		 fieldName => 'contentFilterThreshold',

		 printableName => __('Threshold'),

		 editable => 1,
		 defaultValue  => 0,
		 populate => \&_populateContentFilterThreshold ,
	   ), 


        );

      my $dataForm = {
                      tableName          => 'ContentFilterThreshold',
                      printableTableName => __('Content filter threshold'),
		      modelDomain        => 'Squid',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
		      messages           => {
			    update => __('Content filter threshold changed'),
			   },
                     };



    return $dataForm;
}




sub _populateContentFilterThreshold
  {
    return [
	    { value => 0, printableValue => __('Disabled'),  },
	    { value => 200, printableValue => __('Very permissive'),  },
	    { value => 160, printableValue => __('Permissive'),  },
	    { value => 120, printableValue => __('Medium'),  },
	    { value => 80, printableValue => __('Strict'),  },
	    { value => 50, printableValue => __('Very strict'),  },
	   ];

  }







1;

