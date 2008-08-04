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



package EBox::MailFilter::Model::AntivirusConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;

use EBox::Types::Boolean;
use EBox::MailFilter::Types::Policy;


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

sub _table
{
    my @tableDesc = 
        ( 
         new EBox::Types::Boolean(
                                  fieldName => 'enabled',
                                  printableName => __('Antivirus enabled'),
                                  defaultValue => 1,
                                  editable => 1
                                 ),
         new EBox::MailFilter::Types::Policy(
                                             fieldName => 'policy',
                                             printableName => __('Virus policy'),
                                             defaultValue  => 'D_DISCARD',
                                             editable => 1,
                                            ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Antivirus configuration'),
                      modelDomain        => 'mailfilter',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}


sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;


}





1;

