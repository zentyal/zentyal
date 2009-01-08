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



package EBox::MailFilter::Model::AmavisPolicy;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;

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
         new EBox::MailFilter::Types::Policy(
                                             fieldName => 'virus',
                                             printableName => __('Virus policy'),
                                             defaultValue  => 'D_DISCARD',
                                             editable => 1,
                                            ),
         new EBox::MailFilter::Types::Policy(
                                             fieldName => 'spam',
                                             printableName => __('Spam policy'),
                                             defaultValue  => 'D_PASS',
                                             editable => 1,
                                            ),
         new  EBox::MailFilter::Types::Policy(
                                              fieldName => 'banned',
                                              printableName => __('Banned files policy'),
                                              defaultValue  => 'D_BOUNCE',
                                              editable      => 1,
                                             ),
         new  EBox::MailFilter::Types::Policy(
                                              fieldName => 'bhead',
                                              printableName => __('Bad header policy'),
                                              defaultValue  => 'D_PASS',
                                              editable      => 1,
                                             ),


        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('SMTP filter policies'),
                      modelDomain        => 'MailFilter',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}

# Method: headTitle
#
#   Overrides <EBox::Model::Component::headTitle> to not
#   write a head title within the tabbed composite
sub headTitle
{
    return undef;
}

1;

