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

# Class: EBox::DHCP::Model::LeaseTimes
#
# This class is the model to configurate lease times for the dhcp
# server on a static interface. The fields are the following:
#
#     - default leased time
#     - maximum leased time
#

package EBox::DHCP::Model::LeaseTimes;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox uses
use EBox::DHCP;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Int;
use EBox::Validate;

# Constants
use constant DEFAULT_LEASED_TIME => 1800;
use constant MAX_LEASED_TIME     => 7200;

# Group: Public methods

# Constructor: new
#
#     Create the lease times to the dhcp server
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Parameters:
#
#     interface - String the interface where the DHCP server is
#     attached
#
# Returns:
#
#     <EBox::DHCP::Model::LeaseTimes>
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#     argument is missing
#
sub new
  {

      my $class = shift;
      my %opts = @_;
      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      throw EBox::Exceptions::MissingArgument('interface')
        unless defined ( $opts{interface} );

      $self->{interface} = $opts{interface};

      return $self;

  }

# Method: index
#
# Overrides:
#
#      <EBox::Model::DataTable::index>
#
sub index
{

    my ($self) = @_;

    return $self->{interface};

}

# Method: printableIndex
#
# Overrides:
#
#     <EBox::Model::DataTable::printableIndex>
#
sub printableIndex
{

    my ($self) = @_;

    return __x("interface {iface}",
              iface => $self->{interface});

}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    # Validate leased times
    if ( exists $changedFields->{default_leased_time} ) {
        # Check if the default time is lower than maximum
        my $defaultTime = $changedFields->{default_leased_time}->value();
        if ( $defaultTime < 0 ) {
            throw EBox::Exceptions::External(__('Default leased time must be '
                                                . 'higher than 0 seconds'));
        }
        if ( defined($allFields->{max_leased_time}) ) {
            my $maxTime = $allFields->{max_leased_time}->value();
            if ( $defaultTime > $maxTime ) {
                throw EBox::Exceptions::External(__x('Default leased time {default} '
                                                     . 'must be lower than maximum '
                                                     . 'one {max}',
                                                     default => $defaultTime,
                                                     max     => $maxTime));
            }
        }
    }
    if ( exists $changedFields->{max_leased_time} ) {
        # Check if the default time is lower than maximum
        my $maxTime = $changedFields->{max_leased_time}->value();
        if ( $maxTime < 0 ) {
            throw EBox::Exceptions::External(__('Maximum leased time must be '
                                                . 'higher than 0 seconds'));
        }
        if (defined($allFields->{default_leased_time})) {
            my $defaultTime = $allFields->{default_leased_time}->value();
            if ( $maxTime < $defaultTime ) {
                throw EBox::Exceptions::External(__x('Maximum leased time {max} '
                                                     . 'must be higher than default '
                                                     . 'one {default}',
                                                     max     => $maxTime,
                                                     default => $defaultTime));
            }
        }
    }
}

# Method: formSubmitted
#
#       When the form is submitted, the model must set up the jabber
#       dispatcher client service and sets the output rule in the
#       firewall
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

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
       new EBox::Types::Int(
                            fieldName        => 'default_leased_time',
                            printableName    => __('Default leased time'),
                            editable         => 1,
                            defaultValue     => DEFAULT_LEASED_TIME,
                            trailingText     => __('seconds'),
                           ),
       new EBox::Types::Int(
                            fieldName        => 'max_leased_time',
                            printableName    => __('Maximum leased time'),
                            editable         => 1,
                            defaultValue     => MAX_LEASED_TIME,
                            trailingText     => __('seconds'),
                           ),
      );

    my $dataForm = {
                    tableName          => 'LeaseTimes',
                    printableTableName => __('Lease times'),
                    modelDomain        => 'DHCP',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    class              => 'dataForm',
                    help               => __('Leased time is the time which a given '
                                             . 'IP address is valid by the DHCP server'),
                   };

    return $dataForm;

}

1;
