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



package EBox::Mail::Model::GreylistConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::Host;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Port;


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
                               fieldName => 'service',
                               printableName => __('Enabled'),
                               editable => 1,
                               defaultValue => 1,
                              ),
         new EBox::Types::Int(
                              fieldName => 'delay',
                              printableName => __('Greylist duration (seconds)'),
                              editable => 1,
                              size     => 4,
                              defaultValue => 300,
                              min => 1,
                             ),
         new EBox::Types::Int(
                              fieldName => 'retryWindow',
                              printableName => __('Retry window (hours)'),
                              help => __('Time that will have the mail sender to retry before it will be greylisted again'),
                              editable => 1,
                              size     => 4,
                              defaultValue => 48,
                              min => 1,
                             ),
         new EBox::Types::Int(
                              fieldName => 'maxAge',
                              printableName => __('Entries time to live (days)'),
                              help => __('Period after that unseen entries will be deleted'),
                              editable => 1,
                              size     => 4,
                              defaultValue => 35,
                              min => 1,
                             ),

         

        );

      my $dataForm = {
                      tableName          => 'GreylistConfiguration',
                      printableTableName => __('Greylist configuration'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}




1;

