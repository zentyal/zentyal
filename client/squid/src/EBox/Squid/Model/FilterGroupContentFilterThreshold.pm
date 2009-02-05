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

package EBox::Squid::Model::FilterGroupContentFilterThreshold;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;

use EBox::Types::Boolean;
use  EBox::Squid::Types::WeightedPhrasesThreshold;


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
                  printableName => __('Use default profile threshold'),
                  defaultValue => 0,
                  editable     => 1,
          ),
         new  EBox::Squid::Types::WeightedPhrasesThreshold(
             fieldName => 'contentFilterThreshold',
             printableName => __('Threshold'),
             editable => 1,
             ), 


        );

    my $dataForm = {
        tableName          => 'FilterGroupContentFilterThreshold',
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



sub threshold
{
    my ($self) = @_;

    if ($self->useDefaultValue()) {
        # fetch and return default profile threshold value
        my $squid = EBox::Global->modInstance('squid');
        return $squid->model('ContentFilterThreshold')->contentFilterThresholdValue();
    }

    return $self->contentFilterThresholdValue();
}






1;

