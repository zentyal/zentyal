# Copyright (C) 2008-2011 eBox Technologies S.L.
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

# Class: EBox::Monitor::Model::ThresholdConfiguration
#
# This class is the model base to configurate thresholds for the different measures
#
# These fields are the common to all measures:
#
#    - enabled - Boolean enable/disable a threshold
#    - warningMin - Float the minimum value to start notifying a warning
#    - failureMin - Float the minimun value to start notifying a failure
#    - warningMax - Float the maximum value to start notifying a warning
#    - failureMax - Float the maximum value to start notifying a failure
#    - invert - Boolean the change the meaning of the bounds
#    - persist - Union the notification must be constantly sent or
#                once after level change or after X seconds
#
#
# These ones are dependant on the measure, that is the parent model
#
#    - measureInstance - Select if there are more than one measure
#    instance, it should be displayed as a select
#
#    - typeInstance - Select if there are more than one type per
#    measure, it should be displayed as a select in this combo
#
#    - dataSource - Select if there are more than one data source per
#    type, it should be displayed as a select in this combo
#
package EBox::Monitor::Model::ThresholdConfiguration;

use base 'EBox::Model::DataTable';

use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::Monitor::Exceptions::ThresholdOverride;
use EBox::Gettext;
use EBox::Global;
use EBox::Monitor::Configuration;
use EBox::Monitor::Types::MeasureAttribute;
use EBox::Types::Boolean;
use EBox::Types::Float;
use EBox::Types::Int;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Core modules
use Error qw(:try);

# Constants
use constant RESOLUTION => EBox::Monitor::Configuration::QueryInterval();

# Group: Public methods

# Constructor: new
#
#     Create the threshold configuration model instance
#
# Overrides:
#
#     <EBox::Model::DataTable::new>
#
# Returns:
#
#     <EBox::Monitor::Model::ThresholdConfiguration>
#
sub new
{
      my $class = shift;

      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      return $self;

}

# Method: viewCustomizer
#
#     Provide a custom HTML title with breadcrumbs
#
# Overrides:
#
#     <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $custom = $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle( [
        {
         title => __('Events'),
         link  => '/ebox/Events/Composite/GeneralComposite',
        },
        {
         title => __('Monitor Watcher'),
         link  => '/ebox/Monitor/View/MeasureWatchers',
        },
        {
         title => __('Threshold Configuration'),
         link  => '',
        }
       ]);
    return $custom;
}

# Method: validateTypedRow
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    # Check at least one threshold is set
    my $anyThresholdSet = 0;
    foreach my $th (qw(warningMin failureMin warningMax failureMax)) {
        if (exists $changedFields->{$th}) {
            if ($changedFields->{$th}->value()) {
                $anyThresholdSet = 1;
                last;
            }
        }
        if (exists $allFields->{$th} and $allFields->{$th}->value()) {
            $anyThresholdSet = 1;
            last;
        }
    }

    unless($anyThresholdSet) {
        throw EBox::Exceptions::External(
            __('At least a threshold (maximum or minimum) must be set')
           );
    }

    # Try not to override a rule with the remainder ones
    my $excStr = __('This threshold rule will override the current ones');
    if (exists($changedFields->{typeInstance}) or exists($changedFields->{measureInstance})
        or exists($changedFields->{dataSource}) ) {
        my $matchedIds;
        # If there two are any-any, then only a row must be on the table
        if ( $allFields->{typeInstance}->value() eq 'none'
            and $allFields->{measureInstance}->value() eq 'none'
            and $allFields->{dataSource}->value() eq 'value') {
            if ( ($action eq 'add' and $self->size() > 0)
                  or
                 ($action eq 'update' and $self->size() > 1)
                ) {
                throw EBox::Monitor::Exceptions::ThresholdOverride($excStr);
            }
        }

        if ( $allFields->{typeInstance}->value() eq 'none' ) {
            $matchedIds = $self->findAllValue(measureInstance => $allFields->{measureInstance}->value());
        } else {
            $matchedIds = $self->findAllValue(typeInstance => $allFields->{typeInstance}->value());
        }
        foreach my $id (@{$matchedIds}) {
            my $row = $self->row($id);
            next if (($action eq 'update') and ($id eq $allFields->{id}));
            if ( $allFields->{typeInstance}->value() eq 'none'
                 and $row->elementByName('dataSource')->isEqualTo($allFields->{dataSource})) {
                # There should be no more typeInstance with the same measure instance
                throw EBox::Monitor::Exceptions::ThresholdOverride($excStr);
            } else {
                if ( $row->elementByName('typeInstance')->isEqualTo($allFields->{typeInstance})
                     and $row->elementByName('measureInstance')->isEqualTo($allFields->{measureInstance})
                     and $row->elementByName('dataSource')->isEqualTo($allFields->{dataSource})) {
                    throw EBox::Exceptions::DataExists(
                        data  => $self->printableRowName(),
                        value => '',
                       );
                } elsif ( $row->elementByName('typeInstance')->isEqualTo($allFields->{typeInstance})
                            and
                         ( ( $row->valueByName('measureInstance') eq 'none'
                             and $row->valueByName('dataSource') eq 'value')
                            or
                           ( $allFields->{measureInstance}->value() eq 'none'
                             and $allFields->{dataSource}->value() eq 'value'))
                        ) {
                    throw EBox::Monitor::Exceptions::ThresholdOverride($excStr);
                }
                # elsif ( $row->elementByName('typeInstance')->isEqualTo($allFields->{typeInstance})
                #             and $row->elementByName('measureInstance')->isEqualTo($allFields->{measureInstance})) {
                #     throw EBox::Exceptions::External(
                #         __('Current monitoring tool version does not support distinction among data sources')
                #        );
                # }
            }
        }
    }

    if ( exists $changedFields->{persist}
         and $changedFields->{persist}->selectedType() eq 'persist_after' ) {
        unless ( ($changedFields->{persist}->value() % EBox::Monitor::Configuration::QueryInterval()) == 0 ) {
            throw EBox::Exceptions::InvalidData(
                data   => $changedFields->{persist}->printableName(),
                value  => $changedFields->{persist}->value(),
                advice => __x('It should be a multiple of {interval}',
                              interval => EBox::Monitor::Configuration::QueryInterval()));
        }
    }

}

# Method: findDumpThresholds
#
#     Return those thresholds which are enabled
#
# Returns:
#
#     array ref - those rows which must be dumped to the threshold
#     configuration file
#
sub findDumpThresholds
{
    my ($self) = @_;

    my $enabledRows = $self->enabledRows();

    my @dumpedRows = map { $self->row($_) } @{$enabledRows};

    return \@dumpedRows;

}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataTable::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
          new EBox::Types::Float(
              fieldName     => 'failureMin',
              printableName => __('Failure minimum'),
              optional      => 1,
              editable      => 1,
              help          => __('Set the lower bound of acceptable values. '
                                  . 'If unset defaults to negative infinity.'),
             ),
          new EBox::Types::Float(
              fieldName     => 'warningMin',
              printableName => __('Warning minimum'),
              optional      => 1,
              editable      => 1,
              help          => __x('If the value is less than this value '
                                  . 'and greater than {fmin} a warn event is sent',
                                  fmin => __('failure minimum')),
             ),
          new EBox::Types::Float(
              fieldName     => 'warningMax',
              printableName => __('Warning maximum'),
              optional      => 1,
              editable      => 1,
              help          => __x('If the value is greater than this value '
                                  . 'and less than {fmax} a warn event is sent',
                                  fmax => __('failure maximum')),
             ),
          new EBox::Types::Float(
              fieldName     => 'failureMax',
              printableName => __('Failure maximum'),
              optional      => 1,
              editable      => 1,
              help          => __('Set the upper bound of acceptable values. '
                                  . 'If unset defaults to positive infinity.'),
             ),
          new EBox::Types::Boolean(
              fieldName     => 'invert',
              printableName => __('Invert'),
              defaultValue  => 0,
              editable      => 1,
              help          => __x('If set to true, the range of acceptable values is inverted, '
                                  . 'i.e. values between {fmin} and {fmax} ({wmin} and {wmax}) are '
                                  . 'not okay.', fmin => __('failure minimum'), fmax => __('failure maximum'),
                                  wmin => __('warning minimum'), wmax => __('warning maximum')),
             ),
          new EBox::Types::Union(
              fieldName     => 'persist',
              printableName => __('Send events'),
              help          =>
                __('If set to Always, an event will be dispatched '
                   . 'for each value that is out of the acceptable range.'),
              subtypes      => [
                  new EBox::Types::Union::Text(
                      fieldName     => 'persist_always',
                      printableName => __('Always'),
                      ),
                  new EBox::Types::Union::Text(
                      fieldName     => 'persist_once',
                      printableName => __('After a change in event level'),
                      ),
                  new EBox::Types::Int(
                      fieldName     => 'persist_after',
                      printableName => __('After'),
                      trailingText  => 's',
                      min           => EBox::Monitor::Configuration::QueryInterval(),
                      editable      => 1,
                      size          => 8,
                     ),
                 ],
              editable      => 1,
             ),
          new EBox::Monitor::Types::MeasureAttribute(
              fieldName     => 'measureInstance',
              printableName => __('Measure instance'),
              attribute     => 'measureInstance',
              editable      => 1,
             ),
          new EBox::Monitor::Types::MeasureAttribute(
              fieldName     => 'typeInstance',
              printableName => __('Type'),
              attribute     => 'typeInstance',
              editable      => 1,
             ),
          new EBox::Monitor::Types::MeasureAttribute(
              fieldName     => 'dataSource',
              printableName => __('Data Source'),
              attribute     => 'dataSource',
              editable      => 1,
             ),
         );

    my $dataTable = {
        tableName           => 'ThresholdConfiguration',
        printableTableName  => __(q{Threshold's list}),
        modelDomain         => 'Monitor',
        printableRowName    => __('Threshold'),
        defaultActions      => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        class               => 'dataTable',
        help                => __x('Every check is done with the highest possible '
                                     . 'resolution: {nSec} seconds', nSec => RESOLUTION) . '.<br>'
                               . __x('Take into account this configuration will be '
                                     . 'only applied if monitor {openhref}event watcher is enabled{closehref}',
                                     openhref  => '<a href="/ebox/Events/Composite/GeneralComposite">',
                                     closehref => '</a>')
                               ,
        enableProperty      => 1,
        defaultEnabledValue => 1,
        automaticRemove     => 1,
        rowUnique           => 1,
    };

    return $dataTable;

}

1;
