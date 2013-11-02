# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::RemoteServices::Jobs;

use base qw(EBox::RemoteServices::Cred);

# Class: EBox::RemoteServices::Jobs
#
#      This class sends job results to the Control Panel using the REST client
#

use EBox::Config;
use EBox::Exceptions::DataNotFound;

use TryCatch::Lite;

use constant MAX_SIZE => 65524;

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Jobs> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

# Method: jobResult
#
#     Push job result to the CC
#
# Parameters:
#
#     jobId - Int the unique identifier for the job instance, it
#     corresponds to the same job to runJob web service
#
#     stdout - String the standard output produced by the script
#
#     stderr - String the standard error output produced by the script
#
#     exitValue - Int the exit value as standard UNIX
#                  (0 -> ok, ~0 -> fail)
#
#     - Named parameters
#
sub jobResult
{
    my ($self, %wsParams) = @_;

    $self->_transmitResult('/v1/jobs/', %wsParams);
}

# Method: cronJobResult
#
#     Push job result to the CC
#
# Parameters:
#
#     jobId - Int the unique identifier for the cron job
#
#     stdout - String the standard output produced by the script
#
#     stderr - String the standard error output produced by the script
#
#     exitValue - Int the exit value as standard UNIX
#                  (0 -> ok, ~0 -> fail)
#
#     - Named parameters
#
sub cronJobResult
{
    my ($self, %wsParams) = @_;

    $self->_transmitResult('/v1/jobs/cron/', %wsParams);
}

# Method: cronJobs
#
#     Get the available cronjobs for this eBox
#
# Returns:
#
#     array ref - containing the cron jobs in a hash ref:
#
#         * period - The period in minutes
#         * jobId  - The job identifier within CC
#         * script - The job itself
#
sub cronJobs
{
    my ($self, @wsParams) = @_;

    my $response = $self->RESTClient()->GET('/v1/jobs/cron/');
    return $response->data();
}

# Group: Private methods

# Upload the job result separated in tracks if required
sub _transmitResult
{
    my ($self, $url, %wsParams) = @_;

    my %originalWSParams = %wsParams;
    my $lengthStdOut = length($originalWSParams{stdout});
    my $lengthStdErr = length($originalWSParams{stderr});
    if ( $lengthStdOut > MAX_SIZE or $lengthStdErr > MAX_SIZE) {
        my %wsParams = %originalWSParams;
        my $startPos = 0;
        $wsParams{stdout} = substr($wsParams{stdout}, $startPos, MAX_SIZE);
        $wsParams{stderr} = substr($wsParams{stderr}, $startPos, MAX_SIZE);
        # Create the job result and get its id
        my $ret = $self->RESTClient()->POST($url . "$wsParams{'jobId'}/result/", query => \%wsParams)->data();
        my $jobResultId = $ret->{'job_result_id'};

        # Append all the remaining data
        while ( $lengthStdOut > $startPos or $lengthStdErr > $startPos) {
            $startPos += MAX_SIZE;
            my $stdout = $startPos > $lengthStdOut ? '' : substr($originalWSParams{stdout}, $startPos, MAX_SIZE);
            my $stderr = $startPos > $lengthStdErr ? '' : substr($originalWSParams{stderr}, $startPos, MAX_SIZE);
            $self->RESTClient()->PUT($url . "$jobResultId/result/",
                                     query => {jobInstanceResultId => $jobResultId,
                                               stdout => $stdout,
                                               stderr => $stderr});
        }
    } else {
        $self->RESTClient()->POST($url . "$wsParams{'jobId'}/result/", query => \%wsParams, retry => 1);
    }

}

1;
