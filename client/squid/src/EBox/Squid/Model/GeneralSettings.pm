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

package EBox::Squid::Model::GeneralSettings;
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
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Port;
use EBox::Squid::Types::Policy;
use EBox::Sudo;

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
            new EBox::Types::Boolean(
                    fieldName => 'transparentProxy',
                    printableName => __('Transparent Proxy'),
                    editable => 1,
                    defaultValue   => 0,
                ),
            new EBox::Types::Port(
                    fieldName => 'port',
                    printableName => __('Port'),
                    editable => 1,
                    defaultValue   => 3128,
                 ),
            new EBox::Squid::Types::Policy(
               fieldName => 'globalPolicy',
               printableName => __('Default policy'),
               defaultValue => 'filter',
               ),
        );

      my $dataForm = {
                      tableName          => 'GeneralSettings',
                      printableTableName => __('General Settings '),
                      modelDomain        => 'Squid',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      messages           => {
                          update => __('Settings changed'),
                      },
                     };



    return $dataForm;
}


sub validateTypedRow
{
  my ($self, $action, $params_r) = @_;

  if (exists $params_r->{port}) {
    $self->_checkPortAvailable($params_r->{port}->value());
  }

}



sub _checkPortAvailable
{
  my ($self, $port) = @_;

  my $oldPort    = $self->portValue();
  if ($port == $oldPort) {
    # there isn't any change so we left tht things as they are
    return;
  }

  my $firewall = EBox::Global->modInstance('firewall');
  if (not $firewall->availablePort('tcp', $port )) {
      throw EBox::Exceptions::External(
              __x('{port} is already in use. Please choose another',
                  port => $port,
                 )
              );
  }
}



1;

