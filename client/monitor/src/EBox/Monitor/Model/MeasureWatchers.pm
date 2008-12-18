# Copyright (C) 2008 eBox Technologies S.L.
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

# Class: EBox::Monitor::Model::MeasureWatchers
#
# This class is the model based to watch measures using our Event
# architecture
#
package EBox::Monitor::Model::MeasureWatchers;

use base 'EBox::Model::DataTable';

# eBox uses
use EBox::Exceptions::DataNotFound;
use EBox::Gettext;
use EBox::Global;
use EBox::Monitor;
use EBox::Types::Text;
use EBox::Types::HasMany;

# Core modules
use Error qw(:try);

# Constants

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

# Method: rows
#
#   It is overriden because this table is kind of different in
#   comparation to the normal use of generic data tables.
#
#   - The user does not add rows. When we detect the table is
#   empty we populate the table with the available measures.
#
# Overrides:
#
#      <EBox::Model::DataTable>
#
sub rows
{
    my ($self, $filter, $page) = @_;

    my $monitor = EBox::Global->modInstance('monitor');

    # Fetch current measures stored in GConf
    my $currentRows = $self->SUPER::rows();
    my %storedMeasures = map { $_->valueByName('measure') => 1 } @{$currentRows};

    my $measures = $monitor->measures();
    my %currentMeasures = map { $_->name() => 1 } @{$measures};

    # Add new measures
    foreach my $measure (keys(%currentMeasures)) {
        next if (exists($storedMeasures{$measure}));
        $self->add(measure => $measure);
    }

    # Remove removed ones
    foreach my $row (@{$currentRows}) {
        my $measure = $row->valueByName('measure');
        next if (exists($currentMeasures{$measure}));
        $self->removeRow($row->id());
    }

    return $self->SUPER::rows($filter, $page);

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

    my @tableDesc =
      (
          new EBox::Types::Text(
              fieldName     => 'measure',
              printableName => __('Measure'),
              editable      => 0,
              filter        => \&_printableMeasure,
             ),
          new EBox::Types::HasMany(
              fieldName     => 'thresholds',
              printableName => __('Thresholds'),
              foreignModel  => 'ThresholdConfiguration',
              view          => '/ebox/Monitor/View/ThresholdConfiguration',
              backView      => '/ebox/Monitor/View/MeasureWatchers',
             ),
       );

      my $dataTable = {
                      tableName           => 'MeasureWatchers',
                      printableTableName  => __('Configure monitor watchers'),
                      printableRowName    => __('measure'),
                      modelDomain         => 'Monitor',
                      defaultActions      => [ 'changeView' ],
                      tableDescription    => \@tableDesc,
                      class               => 'dataTable',
                      help                => __('Every measure may have several thresholds to monitor'),
                  };

      return $dataTable;

}

# Group: Callback functions

# Filter the printable value for measures
sub _printableMeasure
{
    my ($type) = @_;

    my $monitor = EBox::Global->modInstance('monitor');
    my ($measure) = grep { $_->name() eq $type->value() } @{$monitor->measures()};

    return $measure->printableName();

}

1;
