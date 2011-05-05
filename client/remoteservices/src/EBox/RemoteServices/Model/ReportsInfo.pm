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

# Class: EBox::RemoteServices::Model::ReportsInfo
#
# This class is the model to show information about the server subscriptions
#
#     - QA updates enabled
#     - Latest QA update
#

package EBox::RemoteServices::Model::ReportsInfo;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::HTML;
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
       new EBox::Types::Text(
           fieldName     => 'latest',
           printableName => __('Latest generated report'),
           ),
       new EBox::Types::HTML(
           fieldName     => 'download',
           printableName => __('Download latest report'),
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
                         . 'a group where this zentyal belongs to'),
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

    my $rs = $self->{gconfmodule};

    my $sampleReportURL = SAMPLE_REPORT_URL;
    if ( EBox::locale() =~ m:^es: ) {
        $sampleReportURL = SAMPLE_ES_REPORT_URL;
    }

    my ($latest, $link) =
      ( __('None'),
        __x('{oh}Download sample{ch}',
            oh => qq{<a href="$sampleReportURL">},
            ch => '</a>') );

    if ( $rs->subscriptionLevel() > 0 ) {
        my $lastGen = $rs->lastGeneratedReport();
        if ( defined( $lastGen ) ) {
            $latest = POSIX::strftime("%c", localtime($lastGen));
            # Show the link message
            my $domain   = $rs->confKey('realm');
            my $subsName = $rs->confKey('subscribedHostname');
            my $reportURL = "https://www.${domain}/services/report/latest/${subsName}/";
            $link = __x('{oh}Download{ch}',
                        oh => qq{<a href="$reportURL">},
                        ch => '</a>');
        } else {
            $latest = __('No report generated yet');
        }
    }

    return {
        latest   => $latest,
        download => $link,
       };
}

1;

