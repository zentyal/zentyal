# Copyright (C) 2017 Zentyal S.L.
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

package EBox::SysInfo::Model::Edition;

# Class: EBox::SysInfo::Model::Edition
#
#     Model to perform all operations related to subscription
#

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::HTML;
use EBox::Exceptions::External;
use Time::Piece;
use TryCatch;
use JSON::XS;
use File::Slurp;
use LWP::UserAgent;

sub _license
{
    my $global = EBox::Global->getInstance();
    my $lk = $global->getLicenseData('license_key');
    return defined($lk) ? $lk : '';
}

# Function: _licenseInfoHTML
#
#   Volatile acquirer that builds the license info HTML block
#   from fresh Redis data on every render. Returns empty string
#   when no valid license exists.
#
sub _licenseInfoHTML
{
    my ($type) = @_;

    my $global = EBox::Global->getInstance();
    my $licenseData = $global->getLicenseData();

    return '<span></span>' unless ($licenseData and $licenseData->{license_key}
        and $licenseData->{license_key} ne 'ACTIVATION-REQUIRED');

    my $editionName = EBox::GlobalImpl->instance()->_licenseEditionName(
        $licenseData->{license_type}
    );

    return '<span></span>' unless ($editionName and $editionName ne 'community');

    my $editionDisplay = ucfirst($editionName);

    # Expiration date
    my $dateStr = $licenseData->{expiration_date} // '';
    my $dateDisplay = $dateStr;
    try {
        my $exp = Time::Piece->strptime("$dateStr", "%Y-%m-%d");
        # Use explicit format to avoid locale-dependent UTF-8 issues with %x
        $dateDisplay = $exp->strftime('%d/%m/%Y');
        if ($exp->strftime('%Y') >= 2030) {
            $dateDisplay = __('Perpetual');
        }
    } catch {
        # keep raw date string
    }

    # Users
    my $usersDisplay = $licenseData->{users} // 0;
    if ($usersDisplay >= 9999) {
        $usersDisplay = __('Unlimited');
    }

    my $checkBtnLabel = __('Check Now');
    my $checkingLabel = __('Checking...');

    my $html = '<div class="license-info">'
             . '<p><label>' . __('Server edition') . '</label> ' . $editionDisplay . '</p>'
             . '<p><label>' . __('Users') . '</label> ' . $usersDisplay . '</p>'
             . '<p><label>' . __('Renovation date') . '</label> ' . $dateDisplay . '</p>'
             . '<div style="margin-top: 10px;">'
             . '<button type="button" id="checkLicenseBtn" class="btn btn-default btn-sm"'
             . " onclick=\"this.disabled=true; this.innerHTML='$checkingLabel';"
             . " Zentyal.TableHelper.formSubmit("
             . "'/SysInfo/Controller/CheckLicense', 'CheckLicense',"
             . " ['_dummy'], 'SysInfo/CheckLicense', 'form'"
             . ');">' . $checkBtnLabel . '</button>'
             . '</div>'
             . '</div>';

    return $html;
}

# Function: _editionTitle
#
#   Returns the dynamic form title based on current license data.
#
sub _editionTitle
{
    my $global = EBox::Global->getInstance();
    my $licenseData = $global->getLicenseData();

    if ($licenseData and $licenseData->{license_key}
        and $licenseData->{license_key} ne 'ACTIVATION-REQUIRED') {

        my $editionName = EBox::GlobalImpl->instance()->_licenseEditionName(
            $licenseData->{license_type}
        );

        if ($editionName and $editionName ne 'community') {
            return "Zentyal " . ucfirst($editionName) . " Edition";
        }
    }

    return __('License Validation');
}

sub _table
{
    my ($self) = @_;

    my @tableHead;

    # Single volatile HTML field for license info — never stored in
    # the DataForm's Redis row, so it reads fresh data on every render.
    push (@tableHead, new EBox::Types::HTML(
        fieldName    => 'license-info',
        defaultValue => '<span></span>',
        volatile     => 1,
        acquirer     => \&_licenseInfoHTML,
    ));

    push (@tableHead, new EBox::Types::Text(fieldName     => 'key',
                                            printableName => __('License Key'),
                                            size          => 24,
                                            defaultValue  => \&_license,
                                            editable      => 1));

    my $dataTable =
    {
        'tableName' => 'Edition',
        'printableTableName' => _editionTitle(),
        'printableActionName' => __('Validate License'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

# Map of API v2 error codes to user-friendly messages
my %ERROR_MESSAGES = (
    'LICENSE_NOT_FOUND'                    => __('The license key does not exist. Please check the key and try again.'),
    'LICENSE_ALREADY_ACTIVE_ON_THIS_SERVER' => __('This license is already active on this server.'),
    'LICENSE_ALREADY_ACTIVE_ON_OTHER_SERVER' => __('This license is already active on another server. Please deactivate it first.'),
    'LICENSE_EXPIRED'                      => __('This license has expired. Please renew your license.'),
    'LICENSE_DISABLED'                     => __('This license has been disabled by an administrator. Please contact support.'),
    'LICENSE_CANCELLED'                    => __('This license was cancelled and cannot be reactivated.'),
    'LICENSE_INVALID_STATUS'               => __('This license cannot be activated in its current state. Please contact support.'),
    'VERSION_MISMATCH'                     => __('This license is not valid for this server version. Please upgrade the server or get a compatible license.'),
);

sub validateTypedRow
{
    my ($self, $action, $changed, $all) = @_;

    my $global = EBox::Global->getInstance();
    my $curLicenseData = $global->getLicenseData();
    my $curEdition;

    if ($curLicenseData and $curLicenseData->{license_type}) {
        $curEdition = EBox::GlobalImpl->instance()->_licenseEditionName(
            $curLicenseData->{license_type}
        );
    }
    $curEdition //= 'community';

    my $key = defined $changed->{key} ? $changed->{key}->value() : $all->{key}->value();

    # Sanitize key to prevent shell injection (must match XXXXX-XXXXX-XXXXX-XXXXX)
    unless ($key =~ /^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/) {
        throw EBox::Exceptions::External(
            __('Invalid license key format. Expected format: XXXXX-XXXXX-XXXXX-XXXXX')
        );
    }

    # Run the enable_license script (API v2) with EBOX_SKIP_REDIS_SAVE
    # to avoid Redis lock deadlock (webadmin holds the lock, subprocess would block)
    my $output = EBox::Sudo::silentRoot(
        "EBOX_SKIP_REDIS_SAVE=1 /usr/share/zentyal/enable_license '$key'"
    );
    if ($? != 0) {
        # The script outputs the v2 error_code on stdout
        my $errorCode = '';
        if ($output and ref($output) eq 'ARRAY' and @{$output}) {
            $errorCode = $output->[0];
            chomp($errorCode);
        }

        # Check for specific v2 error codes
        if ($errorCode and exists $ERROR_MESSAGES{$errorCode}) {
            throw EBox::Exceptions::External($ERROR_MESSAGES{$errorCode});
        }

        throw EBox::Exceptions::External(
            __('License key cannot be validated. Please try again or check your Internet connection.')
        );
    }

    # Read license data from the JSON file written by enable_license
    # and save to Redis in-process (avoids lock deadlock)
    my $licenseJsonFile = '/var/lib/zentyal/tmp/.license-data.json';
    if (-f $licenseJsonFile) {
        try {
            my $jsonContent = File::Slurp::read_file($licenseJsonFile);
            my $newData = decode_json($jsonContent);
            $global->saveLicenseData($newData);
        } catch ($e) {
            EBox::warn("Could not read license data from $licenseJsonFile: $e");
        }
    }

    # Re-read the freshly saved license data from Redis
    my $newLicenseData = $global->getLicenseData();
    my $newEdition = EBox::GlobalImpl->instance()->_licenseEditionName(
        $newLicenseData->{license_type} // ''
    ) // 'community';

    # Block trial-to-trial transitions
    if (($curEdition eq 'trial') and ($newEdition eq 'trial')) {
        # Disable the new trial via API
        try {
            my $ua = LWP::UserAgent->new;
            $ua->agent("ZentyalServer/8.1");
            my $url = "https://ucp.zentyal.com/api/lk/disable";
            my $data = {"code" => $key};
            my $res = $ua->post($url, $data);
            if ($res->code() eq 500) {
                EBox::error('Something was wrong with UCP server disabling the new trial');
            }
            if ($res->code() eq 200) {
                EBox::error('The trial ' . $key . ' was disabled in UCP because you cannot use a trial license twice');
            }
        } catch ($e) {
            EBox::error("Error disabling trial: $e");
        }

        throw EBox::Exceptions::External(__("You cannot use a trial more than one time."));
    }

    # Check expiration from Redis data
    my $expDate = $newLicenseData->{expiration_date} // '';
    if ($expDate) {
        try {
            my $exp = Time::Piece->strptime("$expDate", "%Y-%m-%d");
            if (localtime > $exp) {
                throw EBox::Exceptions::External(__("License key is expired."));
            }
        } catch (EBox::Exceptions::External $e) {
            $e->throw();
        } catch {
            # could not parse date, skip expiration check
        }
    }
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow, $force) = @_;

    # Invalidate the cached table so _table() is called again on the
    # next page render, picking up fresh license data from Redis
    delete $self->{'table'};

    # License data is already saved to Redis by validateTypedRow.
    # Apply edition changes to WebAdmin (theme and repositories).
    my $webadmin = EBox::Global->modInstance('webadmin');
    $webadmin->_setEdition();

    # Force a page redirect so the browser reloads the form with fresh data
    $self->pushRedirection('/SysInfo/View/Edition');
}

1;
