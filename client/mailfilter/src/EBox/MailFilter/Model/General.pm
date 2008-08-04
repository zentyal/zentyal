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



package EBox::MailFilter::Model::General;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Port;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::MailAddress;

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
         new EBox::Types::Port(
                               fieldName => 'port',
                               printableName => __(q{Service's port}),
                               editable => 1,
                               defaultValue => 10024,
                              ),
         new EBox::Types::Union(
                                fieldName => 'notification',
                                printableName => 
                                __('Notify of non-spam problematic messages'),
                                subtypes => [
                                             new EBox::Types::Text(
                                         'fieldName' => 'disabled',
                                         'printableName' => __('Disabled'),
                                                                  ),
                                             new EBox::Types::MailAddress(
                                               'fieldName' => 'address',
                                               'printableName' => 
                                                 __('mail address'),
                                               'editable'  => 1,
                                                                 ),

                                            ],
                               ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('General settings'),
                      modelDomain        => 'mailfilter',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}


sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;

  if (not exists $params_r->{port}) {
      return;
  }

  my $port = $params_r->{port}->value();

  my $global  = EBox::Global->getInstance();
  my @mods = grep {  $_->can('usesPort') } @{ $global->modInstances  };
  foreach my $mod (@mods) {
    if ($mod->usesPort('tcp', $port)) {
      throw EBox::Exceptions::External(
                                       __x('The port {port} is already used by module {mod}',
                                           port => $port,
                                           mod  => $mod->name,
                                          )
                                      );
    }
  }


}


sub notificationAddress
{
    my ($self) = @_;
    my $notify = $self->notificationType();

    if ($notify->selectedType() eq 'disabled') {
        return undef;
    }

    my $addr = $notify->subtype()->value();
    return $addr;
}



1;

