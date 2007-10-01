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

# Class: EBox::Logs::Model::ForcePurge
#


package EBox::Logs::Model::ForcePurge;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Logs::Model::ConfigureLogDataTable;


# Core modules
use Error qw(:try);
use Clone qw(clone);

# Group: Public methods

# Constructor: new
#
#      Create an enabled form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
# Parameters:
#
#      enableTitle - String the i18ned title for the printable name
#      for the enabled attribute
#
#      modelDomain - String the model domain which this form belongs to
#
#      - Named parameters
#
# Returns:
#
#      <EBox::Common::Model::EnableForm> - the recently created model
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
sub new
  {
      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);
      bless( $self, $class );

      return $self;
  }



# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
  {

      my ($self) = @_;

      my @tableDesc =
        (
	 new EBox::Types::Select(
				 'fieldName' => 'lifeTime',
				 'printableName' => __('Purge logs older than'),
				 populate       => \&_populateSelectLifeTime,
				 editable       => 1,
				 defaultValue   => 1,
				),
        );

      my $dataForm = {
                      tableName          => 'ForcePurge',
                      printableTableName => __('Force log purge'),
                      modelDomain        => 'Logs',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                     };

      return $dataForm;

  }


sub setRow
  {
    my ($self, $force, %params) = @_;
  my $lifeTime = $params{lifeTime};

  my $logs = EBox::Global->modInstance('logs');

  EBox::debug("lifetime $lifeTime");
  $logs->forcePurge($lifeTime);
}

sub _populateSelectLifeTime
{
  # life time values must be in hours
  return  [
	   {
	    printableValue => __('one hour'),
	    value          => 1,
	   },
	   {
	    printableValue => __('twelve hours'),
	    value          => 12,
	   },
	   {
	    printableValue => __('one day'),
	    value          => 24,
	   },
	   {
	    printableValue => __('three days'),
	    value          => 72,
	   },
	   {
	    printableValue => __('one week'),
	    value          =>  168,
	   },
	   {
	    printableValue => __('fifteeen days'),
	    value          =>  360,
	   },
	   {
	    printableValue => __('thirty days'),
	    value          =>  720,
	   },
	   {
	    printableValue => __('ninety days'),
	    value          =>  2160,
	   },
	  ];
}


1;
