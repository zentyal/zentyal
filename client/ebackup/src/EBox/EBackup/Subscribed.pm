# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::EBackup::Subscribed;

use EBox::Global;
use EBox::EBackup::Password;
use EBox::Config;
use EBox::Sudo;
use Error qw(:try);

use constant FINGERPRINT_FILE => EBox::Config::share() . 'ebox-ebackup/server-fingerprints';

sub isSubscribed
{
    if (EBox::Global->modExists('remoteservices')) {
        my $remoteServices = EBox::Global->modInstance('remoteservices');
        return $remoteServices->disasterRecoveryAddOn();
    } else {
        return 0;
    }
}

sub credentials
{
    my ($self) = @_;

    my $remoteServices = EBox::Global->modInstance('remoteservices');
    my $credentials;

    try {
        $credentials = $remoteServices->backupCredentials();
    } catch EBox::Exceptions::DataNotFound with {
        # this means that it does not have a disasterRecoveryAddOn
        $credentials = undef;
    };

    if (not defined $credentials) {
        return undef;
    }

    my $commonName = $remoteServices->eBoxCommonName();
    # add  machine directory
    $credentials->{target} = $credentials->{server} . '/' . $commonName;

    $credentials->{method} = 'scp';

    # quota must be in Mb
    $credentials->{quota} *= 1024;

    return $credentials;
}


# Method: quota
# Returns:
#    scalar contentx - quota in Mb
#     lsit content   - (used space, quota) in Mb
sub quota
{
    my $credentials = credentials();
    if (not defined $credentials) {
        return undef;
    }

    my $server = $credentials->{server};
    my $username = $credentials->{username};

    my $password = $credentials->{password};
    EBox::EBackup::Password::setPasswdFile($password);

    my $quota = $credentials->{quota};

    my $passwdFile = EBox::EBackup::Password::PASSWD_FILE;
    my $cmd =  qq{ sshpass -f $passwdFile ssh  } .
               q{-o GlobalKnownHostsFile=} . FINGERPRINT_FILE . ' ' .
               $username . '@' .  $server .
               q{ du -s -m};
    my $output = EBox::Sudo::command($cmd);
    my ($used) = split '\s+', $output->[0];

    return wantarray ? ($used, $quota) : $quota;
}

1;
