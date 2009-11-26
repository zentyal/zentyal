# Copyright (C) 2008 Warp Networks S.L.
# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::RemoteServices::Jobs;
use base 'EBox::RemoteServices::Auth';

# Class: EBox::RemoteServices::Jobs
#
#      This class sends job results to the Control Panel using the SOAP
#      client through VPN. It already takes into account to establish
#      the VPN connection and the required data to auth data
#

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::DataNotFound;

use Error qw(:try);

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
    my ($self, @wsParams) = @_;

    $self->_transmitResult('jobResult', @wsParams);
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
    my ($self, @wsParams) = @_;

    $self->_transmitResult('cronJobResult', @wsParams);
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

    return $self->soapCall('cronJobs', @wsParams);
}

# Group: Protected methods

# Method: _serviceUrnKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceUrnKey>
#
sub _serviceUrnKey
{
    return 'jobsServiceUrn';
}

# Method: _serviceHostNameKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceHostNameKey>
#
sub _serviceHostNameKey
{
    return 'managementProxy';
}

# Group: Private methods

# Upload the job result separated in tracks if required
sub _transmitResult
{
    my ($self, $type, @wsParams) = @_;

    my %originalWSParams = @wsParams;
    my $lengthStdOut = length($originalWSParams{stdout});
    my $lengthStdErr = length($originalWSParams{stderr});
    if ( $lengthStdOut > MAX_SIZE or $lengthStdErr > MAX_SIZE) {
        my %wsParams = %originalWSParams;
        my $startPos = 0;
        $wsParams{stdout} = substr($wsParams{stdout}, $startPos, MAX_SIZE);
        $wsParams{stderr} = substr($wsParams{stderr}, $startPos, MAX_SIZE);
        my $jobResultId = $self->soapCall($type, %wsParams);
        while ( $lengthStdOut > $startPos or $lengthStdErr > $startPos) {
            $startPos += MAX_SIZE;
            my $stdout = $startPos > $lengthStdOut ? '' : substr($originalWSParams{stdout}, $startPos, MAX_SIZE);
            my $stderr = $startPos > $lengthStdErr ? '' : substr($originalWSParams{stderr}, $startPos, MAX_SIZE);
            $self->soapCall('appendJobResult',
                            jobInstanceResultId => $jobResultId,
                            stdout => $stdout,
                            stderr => $stderr);
        }
    } else {
        $self->soapCall($type, @wsParams);
    }

}

1;
