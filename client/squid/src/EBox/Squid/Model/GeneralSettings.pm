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
use EBox::Types::Select;
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
	   new EBox::Types::Select(
		 fieldName => 'contentFilterThreshold',

		 printableName => __('Content filter threshold'),

		 editable => 1,
		 defaultValue  => 0,
		 populate => \&_populateContentFilterThreshold ,
		 filter =>   \&_contentThresholdToString,
				  ), 

           new EBox::Squid::Types::Policy(
				   fieldName => 'globalPolicy',
				   printableName => __('Default policy'),
				  ),


        );

      my $dataForm = {
                      tableName          => 'GeneralSettings',
                      printableTableName => __('General Settings '),
		      modelDomain        => 'Squid',
                      modelDomain        => 'Squid',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                     };



    return $dataForm;
}


sub validateTypedRow
{
  my ($self, $action, $params_r) = @_;

  my $globalPolicy = exists $params_r->{globalPolicy} ? 
                        $params_r->{globalPolicy} : undef;
  my $cfThreshold  = exists $params_r->{contentFilterThreshold} ?
                       $params_r->{contentFilterThreshold} : undef;
  $self->_checkGlobalPolicyAndThreshold($globalPolicy, $cfThreshold);


  if (exists $params_r->{port}) {
    $self->_checkPortAvailable($params_r->{port}->value());

    
  }

  

}

sub _checkGlobalPolicyAndThreshold
{
  my ($self, $globalPolicy, $cfThreshold) = @_;
  
  if ((not defined $globalPolicy) and (not defined $cfThreshold)) {
    # none parameter has changed so we don;t ned to check
    return;
  }

  if (not defined $globalPolicy) {
    $globalPolicy = $self->globalPolicy();
  }

  if (not defined $cfThreshold) {
    $cfThreshold = $self->contentFilterThreshold();
  }

 if ($globalPolicy->value() eq 'filter') {
    if ($cfThreshold->value() == 0) {
      throw EBox::Exceptions::External(
            __(q{The configuration is invalid becuase a 'filter' policy requires an active content filter})				       
				      );
    }
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





sub _contentThresholdToString
  {
    my ($instancedType) = @_;
    my $value = $instancedType->value();

 
    if ( $value >= 200) {
      return __('Very permissive');
    } elsif ( $value >= 160) {
      return __('Permissive');
    } elsif ( $value >= 120) {
      return __('Medium');
    } elsif ( $value >= 80) {
      return __('Strict');
    } elsif ( $value > 0) {
      return __('Very strict');
    } elsif ( $value == 0) {
      return __('Disabled');
    } else {
      throw EBox::Exceptions::Internal("Bad content threshold value: $value");
    }
  }

1;

