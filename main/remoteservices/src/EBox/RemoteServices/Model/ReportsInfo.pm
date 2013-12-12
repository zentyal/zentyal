# Copyright (C) 2011-2012 Zentyal S.L.
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

# Class: EBox::RemoteServices::Model::ReportsInfo
#
# This class is the model to show information about the reports
#
#     - See latest report
#     - Last consolidation time
#     - Number of available reporters
#

package EBox::RemoteServices::Model::ReportsInfo;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::HTML;
use EBox::RemoteServices::Reporter;
use POSIX;

# Group: Public methods

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
       new EBox::Types::HTML(
           fieldName     => 'report_link',
           printableName => __('See latest report'),
          ),
       new EBox::Types::Text(
           fieldName     => 'last_consolidation',
           printableName => __('Last consolidation time'),
          ),
       new EBox::Types::Text(
           fieldName     => 'reporters_num',
           printableName => __('Number of available reporters'),
          ),
      );

    my $dataForm = {
                    tableName          => 'ReportsInfo',
                    printableTableName => __('Reports'),
                    defaultActions     => [ 'changeView' ],
                    modelDomain        => 'RemoteServices',
                    tableDescription   => \@tableDesc,
                    help               =>
                      __('Reports are done based on automatically gathered data in hourly basis'),
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

    my $rs = $self->parentModule();

    my $baseURL = $rs->controlPanelURL();
    my $docReportURL = "${baseURL}doc/report.html";

    my ($lastCon, $link, $reportersNum) =
      ( __('Not registered'),
        __x('{oh}Take a look on the documentation{ch}',
            oh => qq{<a target="_blank" href="$docReportURL">},
            ch => '</a>'),
        0);

    if ( EBox::Config::boolean('disable_consolidation') ) {
        $lastCon = __('The consolidation is disabled. No report data is gathered');
    } else {
        if ( $rs->subscriptionLevel() >= 5 ) {
            my $reporter = EBox::RemoteServices::Reporter->instance();
            $lastCon = $reporter->lastConsolidationTime();
            if ( defined( $lastCon ) ) {
                $lastCon = POSIX::strftime("%c", localtime($lastCon));
                # Show the link message
                my $subsUUID = $rs->subscribedUUID();
                my $reportURL = "${baseURL}services/report/newera/server/${subsUUID}/";
                $link = __x('{oh}Take a look{ch}',
                            oh => qq{<a target="_blank" href="$reportURL">},
                            ch => '</a>');
            } else {
                $lastCon = __('No consolidation done yet');
            }
            $reportersNum = $reporter->helpersNum();
        }
    }

    return {
        report_link        => $link,
        last_consolidation => $lastCon,
        reporters_num      => $reportersNum,
       };
}

1;

