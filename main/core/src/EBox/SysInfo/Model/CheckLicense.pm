# Copyright (C) 2025 Zentyal S.L.
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

package EBox::SysInfo::Model::CheckLicense;

# Class: EBox::SysInfo::Model::CheckLicense
#
#     DataForm::Action to manually trigger a license status check
#     against the UCP API v2.
#

use base 'EBox::Model::DataForm::Action';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Exceptions::External;
use TryCatch;
use LWP::UserAgent;
use JSON::XS;
use HTTP::Request;

sub Viewer
{
    return '/ajax/form.mas';
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (
        new EBox::Types::Text(
            fieldName     => '_dummy',
            printableName => __('Check License'),
            hidden        => 1,
            defaultValue  => '',
        ),
    );

    my $dataTable = {
        'tableName'          => __PACKAGE__->nameFromClass(),
        'printableTableName' => __('Check License Status'),
        'printableActionName' => __('Check Now'),
        'modelDomain'        => 'SysInfo',
        'defaultActions'     => [ 'editField' ],
        'tableDescription'   => \@tableHead,
    };

    return $dataTable;
}

# Method: formSubmitted
#
#   Calls the UCP API v2 directly (in-process) to check the license
#   status, updates Redis, and refreshes the edition theme.
#   This avoids shelling out to check_license which would deadlock
#   on the Redis lock held by the webadmin process.
#
sub formSubmitted
{
    my ($self, $row, $oldRow) = @_;

    my $global = EBox::Global->getInstance();
    my $licenseData = $global->getLicenseData();

    unless ($licenseData and $licenseData->{license_key}) {
        throw EBox::Exceptions::External(
            __('No license key is configured. Please validate a license first.')
        );
    }

    my $licenseKey = $licenseData->{license_key};

    # Call UCP API v2 directly
    my $ua = LWP::UserAgent->new(timeout => 30);
    $ua->agent("ZentyalServer/8.1");
    my $apiUrl = 'https://ucp.zentyal.com/api/v2/licenses/status';
    my $requestBody = encode_json({ license_key => $licenseKey });
    my $req = HTTP::Request->new('POST', $apiUrl);
    $req->header('Content-Type' => 'application/json');
    $req->content($requestBody);

    my $response = $ua->request($req);

    unless ($response->is_success()) {
        my $code = $response->code();
        if ($code == 404) {
            throw EBox::Exceptions::External(
                __('The license key was not found. It may have been removed or is invalid.')
            );
        }
        throw EBox::Exceptions::External(
            __('Could not verify the license status. Please check your Internet connection and try again.')
        );
    }

    my $jsonData;
    try {
        $jsonData = decode_json($response->content());
    } catch ($e) {
        throw EBox::Exceptions::External(
            __('Received an invalid response from the license server. Please try again later.')
        );
    }

    my $statusCode = $jsonData->{status_code} // '';
    my $data = $jsonData->{data} // {};

    # Save updated license data to Redis (in-process, no lock conflict)
    my $newData = {
        license_key      => $data->{code}                      // $licenseKey,
        license_type     => $data->{license_type}{code}        // '',
        expiration_date  => $data->{expiration_date}           // '',
        users            => $data->{users}                     // 0,
        status_code      => $data->{status}{code}              // '',
        status_label     => $data->{status}{label}             // '',
        server_hash      => $data->{server_hash}               // '',
        ucp_client_id    => '',
        ucp_client_secret => '',
    };

    # Preserve OAuth credentials from previous data if API doesn't return them
    my $oauthClient = $jsonData->{oauth_client};
    if ($oauthClient and ref($oauthClient) eq 'HASH') {
        $newData->{ucp_client_id}     = $oauthClient->{id}     // '';
        $newData->{ucp_client_secret} = $oauthClient->{secret} // '';
    }

    $global->saveLicenseData($newData);

    # Invalidate the Edition model's table cache so it rebuilds
    # with fresh data on the next page render
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $editionModel = $sysinfo->model('Edition');
    delete $editionModel->{'table'};

    # Refresh edition settings in WebAdmin (theme and repositories)
    my $webadmin = EBox::Global->modInstance('webadmin');
    $webadmin->_setEdition();

    # Force page reload to show fresh license data
    $self->pushRedirection('/SysInfo/View/Edition');

    # Evaluate status
    if ($statusCode eq 'ACTIVE' or $statusCode eq 'INACTIVE') {
        $self->setMessage(__('License status verified successfully. The license is valid.'));
    } elsif ($statusCode eq 'EXPIRED') {
        my $licType = $data->{license_type}{code} // '';
        if ($licType eq 'TR') {
            throw EBox::Exceptions::External(
                __('The trial license has expired. The web administration interface will be stopped.')
            );
        }
        throw EBox::Exceptions::External(
            __('The license has expired. Please renew your license or contact support.')
        );
    } elsif ($statusCode eq 'DISABLED' or $statusCode eq 'CANCELLED' or $statusCode eq 'DUPLICATED') {
        throw EBox::Exceptions::External(
            __('The license is no longer valid. It may be disabled, cancelled, or duplicated. Please contact support or enter a new license key.')
        );
    } else {
        throw EBox::Exceptions::External(
            __x('Unexpected license status: {status}. Please contact support.', status => $statusCode)
        );
    }
}

1;
