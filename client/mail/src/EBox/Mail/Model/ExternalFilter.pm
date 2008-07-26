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
#   EBox::Squid::Model::ExternalFilter
#
#
#   It subclasses <EBox::Model::DataTable>
#
#  
# 

package EBox::Mail::Model::ExternalFilter;
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
use EBox::Types::Union;
use EBox::Types::Port;
use EBox::Types::HostIP;

# XXX TODO: disable custom filter controls when custom filter is not selected

# eBox exceptions used 
use EBox::Exceptions::External;

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: pageTitle
#
# Overrides:
#   
#   <EBox::Model::Component::pageTitle>
#
sub pageTitle
{
    return undef; 
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
         new EBox::Types::Select(
                                 fieldName => 'externalFilter',
                                 printableName => __('Filter in use'),
                                 editable => 1,
                                 populate => \&_availableFilters
                                ),
         new EBox::Types::Port(
                               fieldName => 'fwport',
                               printableName => __("Custom filter's mail forward port"), 
                               editable => 1,
                               defaultValue => 10025,
                              ),
         new EBox::Types::HostIP(
                                 fieldName => 'ipfilter',
                                 printableName =>  __("Custom filter's IP address"),
                                 editable => 1,
                                 defaultValue => '127.0.0.1',  
                                ),
         new EBox::Types::Port(
                               fieldName => 'portfilter',
                               printableName => __("Custom filter's Port"),
                               editable => 1,
                               defaultValue => 10024,
                              ),

        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Mail filter options'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}






sub _availableFilters
{
    my @options = (
                       { value => 'none' , printableValue => __('none') },
                       { value => 'custom'   , printableValue => __('custom')},
                  ); 

    my $mail = EBox::Global->modInstance('mail');
    my %availableFilters = %{ $mail->externalFiltersFromModules() };
    while (my ($name, $propierties) = each %availableFilters) {
        my $option = {
                      value => $name,
                      printableValue => $propierties->{prettyName},
                     };

        if (not $propierties->{active}) {
            $option->{disabled} = 'disabled';
        }
        
        push @options, $option;
        
    };

    return \@options;
}

sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;

  $self->_checkFWPort($action, $params_r, $actual_r);
}


sub _checkFWPort
{
  my ($self, $action, $params_r, $actual_r) = @_;

  if (not $params_r->{fwport}) {
      return;
  }

  # check if port is available
  my $firewall = EBox::Global->modInstance('firewall');
  defined $firewall or
      return;
  $firewall->isEnabled() or
      return;
  $firewall->availablePort('tcp', $params_r->{fwport}->value());
}

1;

