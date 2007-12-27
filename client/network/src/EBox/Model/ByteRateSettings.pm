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
#   EBox::Network::model::ByteRateSetting
#
#   This class is used as a model to describe a table which will be
#   used to select the logs domains the user wants to enable/disable.
#
#   It subclasses <EBox::Model::DataTable>
#
#  
# 

package EBox::Network::Model::ByteRateSettings;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Text;
use EBox::Types::Select;

use EBox::Sudo;

# eBox exceptions used 
use EBox::Exceptions::External;

use Perl6::Junction qw(all);

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}



sub _table
{
    my @tableDesc = 
        ( 
            new EBox::Types::Boolean(
                    fieldName => 'service',

                    printableName => __('Traffic rate monitor active'),
 
                    editable => 1,

		    defaultValue   => 0,
                ),
            new EBox::Types::Select(
                    fieldName => 'iface',

                    printableName => __('Interface to listen'),

                    editable => 1,

		    populate       => \&_populateIfaceSelect,
		    defaultValue   => 'all',
                 ),

        );

      my $dataForm = {
                      tableName          => 'ByteRateSettings',
                      printableTableName => __('Traffic rate monitor settings'),
		      modelDomain        => 'Network',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,


		      messages           => {
			    update => __('Settings changed'),
			   },
                     };



    return $dataForm;
}



sub _populateIfaceSelect
{
  my $network = EBox::Global->modInstance('network');
  my @ifaces = @{ $network->ifaces };


  my @options = map {
    { value => $_, printableValue => $_ }
  } @ifaces;
  
  push @options,
    { value => 'all', printableValue => __('all')};

  return \@options;
}






1;

