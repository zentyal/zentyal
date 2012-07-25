# Copyright (C) 2011-2012 eBox Technologies S.L.
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
#     - Download latest PDF report
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

# Constants
use constant SAMPLE_REPORT_URL    => 'http://www.zentyal.com/sample-report-pdf';
use constant SAMPLE_ES_REPORT_URL => 'http://www.zentyal.com/es/sample-report-pdf';

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
#     <EBox::RemoteServices::Model::ReportsInfo>
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
       new EBox::Types::HTML(
           fieldName     => 'download',
           printableName => __('Download latest report'),
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
                      __('The download link is for the latest available report for '
                         . 'a group where this zentyal server belongs to'),
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

    my $rs = $self->{confmodule};

    my $sampleReportURL = SAMPLE_REPORT_URL;
    if ( EBox::locale() =~ m:^es: ) {
        $sampleReportURL = SAMPLE_ES_REPORT_URL;
    }

    my ($lastCon, $link, $reportersNum) =
      ( __('No consolidation done'),
        __x('{oh}Download sample{ch}',
            oh => qq{<a href="$sampleReportURL">},
            ch => '</a>'),
        0);

    if ( 1 > 0 ) { # $rs->subscriptionLevel() > 0 ) {
        if ( EBox::Config::boolean('disable_consolidation') ) {
            $lastCon = __('The consolidation is disabled. No report data is gathered');
        } else {
            my $reporter = EBox::RemoteServices::Reporter->instance();
            $lastCon = $reporter->lastConsolidationTime();
            if ( defined( $lastCon ) ) {
                $lastCon = POSIX::strftime("%c", localtime($lastCon));
                # Show the link message
                my $domain   = $rs->confKey('realm');
                my $subsName = $rs->confKey('subscribedHostname');
                my $reportURL = "https://www.${domain}/services/report/latest/${subsName}/";
                $link = __x('{oh}Download{ch}',
                            oh => qq{<a href="$reportURL">},
                            ch => '</a>');
            }
            $reportersNum = $reporter->helpersNum();
        }
    }

    return {
        download           => $link,
        last_consolidation => $lastCon,
        reporters_num      => $reportersNum,
       };
}

1;

