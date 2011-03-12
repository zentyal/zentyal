# Copyright (C) 2011 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Model::AlertsInfo
#
# This class is the model to show information about the server subscriptions
#
#     - QA updates enabled
#     - Latest QA update
#

package EBox::RemoteServices::Model::AlertsInfo;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;

# Core modules
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Create the subscription form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::AlertsInfo>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

}

# Method: headTitle
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
sub headTitle
{
    return undef;
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
       new EBox::Types::Text(
           fieldName     => 'n_last_month',
           printableName => __('Alerts generated during last month'),
           ),
       new EBox::Types::Text(
           fieldName     => 'n_info',
           printableName => __('Information-level alerts'),
          ),
       new EBox::Types::Text(
           fieldName     => 'n_warn',
           printableName => __('Warning-level alerts'),
          ),
       new EBox::Types::Text(
           fieldName     => 'n_error',
           printableName => __('Error-level alerts'),
          ),
       new EBox::Types::Text(
           fieldName     => 'n_fatal',
           printableName => __('Fatal-level alerts'),
          ),
      );

    my $dataForm = {
                    tableName          => 'AlertsInfo',
                    printableTableName => __('Alerts'),
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'changeView' ],
                    tableDescription   => \@tableDesc,
                   };

    return $dataForm;
}

# Method: _content
#
# Overrides:
#
#    <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{
    my ($self) = @_;

    my $evts = EBox::Global->modInstance('events');
    my $report = $evts->lastEventsReport();

    my $noneValue = __('None');
    my ($lastMonth, $nInfo, $nWarn, $nError, $nFatal) =
      ( $noneValue, $noneValue, $noneValue, $noneValue, $noneValue );

    if ($report->{total} > 0) {
        $lastMonth = $report->{total};
        $nInfo     = $report->{info} if ($report->{info} > 0);
        $nWarn     = $report->{warn} if ($report->{warn} > 0);
        $nError    = $report->{error} if ($report->{error} > 0);
        $nFatal    = $report->{fatal} if ($report->{fatal} > 0);
    }

    return {
        n_last_month => $lastMonth,
        n_info => $nInfo,
        n_warn => $nWarn,
        n_error => $nError,
        n_fatal => $nFatal,
       };
}

1;

