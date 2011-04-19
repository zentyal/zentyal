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
use EBox::Backup;
use EBox::Config;
use EBox::EBackup::Password;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Exceptions::RemoteServices::NotConnected;
use Error qw(:try);
use File::Slurp;
use Perl6::Junction qw(none);
use YAML::Tiny;

use constant FINGERPRINT_FILE => EBox::Config::share() . 'ebox-ebackup/server-fingerprints';

# Method: isSubscribed
#
# Returns:
#   bool - wether the disaster recovery addon is available for the server or not
#
sub isSubscribed
{
    my ($self, %params) = @_;

    if (EBox::Global->modExists('remoteservices')) {
        my $remoteServices = EBox::Global->modInstance('remoteservices');
        my $disasterAddOn = 0;
        try {
            $disasterAddOn = $remoteServices->disasterRecoveryAddOn();
        } catch EBox::Exceptions::RemoteServices::NotConnected with {
            my ($ex) = @_;
            unless ($params{ignoreConnectionError}) {
                $ex->throw();
            }

        };

        return $disasterAddOn;
    } else {
        return 0;
    }
}

# Method: credentials
#
# Get the credentials required for the backup processes
#
# Returns:
#
#  undef - in case the server has not the disaster recovery add-on
#  hash ref - with the fields
#           username - String the user name
#           password - String the password for that user in that server
#           server   - String the backup server host name
#           quota    - Int the allowed quota (in Mb)
#           commonName - common name of the server
#           machineTarget - URL for remote server's directory
#           target - URL for remote server's duplicity data directory
#           metaTarget - URL for remote server's meta data directory
#           method    - backend method to be used by duplicity
#
sub credentials
{
    my ($self) = @_;

    if (not isSubscribed()) {
        EBox::error("Trying to get DR credentials in a server without DR addon");
        return undef;
    }

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
    $credentials->{commonName} = $commonName;
    # add  machine directory
    my $machineTarget =  $credentials->{server} . '/' . $commonName;
    $credentials->{machineTarget} = $machineTarget;

    my $dataTarget = $machineTarget . '/data';
    $credentials->{target} = $dataTarget;

    my $metaTarget = $machineTarget . '/meta';
    $credentials->{metaTarget} = $metaTarget;

    $credentials->{method} = 'scp';

    # quota must be in Mb
    $credentials->{quota} *= 1024;

    return $credentials;
}

# Method: quota
#
# Returns:
#    scalar contenxt - quota in Mb
#    list content   - (used space, quota) in Mb
#
sub quota
{
    my $credentials = credentials();
    if (not defined $credentials) {
        return undef;
    }

    my $quota = $credentials->{quota};
    my $output = _sshCommand($credentials, q{ du -s -m});
    my ($used) = split '\s+', $output->[0];

    return wantarray ? ($used, $quota) : $quota;
}

# Method: createStructure
#
#      Create the structure for meta and data in our remote structure
#
sub createStructure
{
    my $credentials = credentials();

    my $dataDir = $credentials->{target};
    my $metaDir = $credentials->{metaTarget};
    my $server  = $credentials->{server};
    $dataDir =~ s:$server/::;
    $metaDir =~ s:$server/::;

    try {
        foreach my $dir (($dataDir, $metaDir)) {
            my $mkdirCmd = "mkdir -p $dir";
            _sshCommand($credentials, $mkdirCmd);
        }
    } otherwise {
        # Network failure, do nothing
    };
}


# executes a command in the remote server using ssh
sub _sshCommand
{
    my ($credentials, $cmd) = @_;

    my $fullCmd = _sshpassCommandAsString($credentials, $cmd);
    return EBox::Sudo::root($fullCmd);
}

sub _sshpassCommandAsString
{
    my ($credentials, $cmd) = @_;

    my $server = $credentials->{server};
    my $username = $credentials->{username};

    my $password = $credentials->{password};
    EBox::EBackup::Password::setPasswdFile($password);
    my $passwdFile = EBox::EBackup::Password->PASSWD_FILE;

    my $fullCmd =  qq{ sshpass -f $passwdFile ssh  } .
               q{-o GlobalKnownHostsFile=} . FINGERPRINT_FILE . ' ' .
               $username . '@' .  $server . ' ' . "'$cmd'";

    return $fullCmd;
}

# Method: writeDRMetadata
#
#   write to the remote server the backup metadata
#
#  Named parameters:
#    configurationDumped - whether the backup contains the configuration or not
#    date - date of the backup. Must be in the same format used by duplicity
#    backupType - backup type (full, incremental)
#    backupDomains - hash ref backup domains stored indexed by backup
#    domain name containing the following keys: description and printableName
#
sub writeDRMetadata
{
    my %options =  @_;

    my $hasConfiguration = $options{configurationDumped} ? 1 : 0;
    my $date = $options{date};
    my $backupType = $options{backupType};
    my $backupDomains = $options{backupDomains};
    if ($hasConfiguration) {
        $backupDomains->{'configuration'} = { description   => __('Configuration'),
                                              printableName => __('Configuration') };
    }

    my $ebackup =  EBox::Global->modInstance('ebackup');
    my $remoteSettings = $ebackup->model('RemoteSettings');
    my $encryptionType = $remoteSettings->usedEncryptionMode();
    my $filename = metaFilenameFromDate($date);

    my @modsInBackup =  map {
        $_->name()
    } @{ EBox::Backup->_modInstancesForBackup() };

    my $metadata = {
        version => drDataVersion(),
        date => $date,
        encryptionType => $encryptionType,
        hasConfiguration => $hasConfiguration,
        backupType       => $backupType,
        backupDomains    => $backupDomains,
        eboxModules      => \@modsInBackup,
    };

    my $yaml = YAML::Tiny->new;
    $yaml->[0]->{'backup'} = $metadata;

    my $tmpFile = EBox::Config::tmp() . $filename;
    $yaml->write($tmpFile);
    my $yamlData = $yaml->write_string();

    my $credentials = credentials();

    my $metadataDir = _metadataDir($credentials);
    my $metadataFile = "$metadataDir/$filename";
    _uploadFileToCloud($credentials, $tmpFile, $metadataFile);
    unlink $tmpFile;
}

sub _uploadFileToCloud
{
    my ($credentials, $localPath, $remotePath) = @_;
    my $ddCmd = qq{dd of=$remotePath};
    my $cmd =  "cat $localPath | " .  _sshpassCommandAsString($credentials, $ddCmd);
    EBox::Sudo::command($cmd);
}

# Method: downloadDRMetadata
#
#  Download the DR metadata files (currently is only one YAML file)
#
#  Parameters:
#      credentials - backup server credentials
#      date        - backup date (same format that is used by duplicity)
#      dir         - directory where put the downloaded files
#
sub downloadDRMetadata
{
    my ($credentials, $date, $dir) = @_;
    my $filename = metaFilenameFromDate($date);
    my $fromPath = _metadataDir($credentials) . '/' . $filename;
    my $toPath = "$dir/$filename";

    my $catCmd = qq{cat $fromPath};
    my $cmd = _sshpassCommandAsString($credentials, $catCmd);

    my $output = EBox::Sudo::command($cmd);
    File::Slurp::write_file($toPath, $output);
}

# Method: metaFilenameFromDate
# Parameters:
#  date - date of the backup in the same format which is used by duplicity
#
# Returns: path of the file which contains the matainformation for the backup in
#    the given date
#
sub metaFilenameFromDate
{
    my ($date) = @_;
    my $filename = $date;
    $filename =~ s/\s/-/g;
    $filename .= '.backup.yaml';
    return $filename;
}

sub _metadataDir
{
    my ($credentials) = @_;
    my $commonName = $credentials->{commonName};
    return "$commonName/meta";
}

# Method: drDataVersion
#
#   Returns:
#         int -  the current version of DR metadata used
#
sub drDataVersion
{
    return 1;
}

# Method: deleteAll
#
#   Delete all the backups found in cloud. It NOT regenerates any cache
#
sub deleteAll
{
    my $credentials = credentials();
    if (not defined $credentials) {
        return undef;
    }

    my $server = $credentials->{server};
    my $username = $credentials->{username};
    my $password = $credentials->{password};
    EBox::EBackup::Password::setPasswdFile($password);

    my $remoteServices = EBox::Global->modInstance('remoteservices');
    my $commonName = $remoteServices->eBoxCommonName();

    my $rmCommand = "rm -rf $commonName/*";

    my $passwdFile = EBox::EBackup::Password->PASSWD_FILE;
    my $cmd =  qq{ sshpass -f $passwdFile ssh  } .
               q{-o GlobalKnownHostsFile=} . FINGERPRINT_FILE . ' ' .
               $username . '@' .  $server .
               ' ' . $rmCommand;
    EBox::Sudo::root($cmd);
}

# Method: deleteOrphanMetadata
#
#   Delete the orphaned metadata files from the cloud. These files are
#   the ones which are left when the backup (data) is removed
#
# Parameters:
#
#   collectionStatus - Hash ref the collection status for this server
#                      as it is returned by <EBox::EBackup::remoteStatus>
#
sub deleteOrphanMetadata
{
    my ($collectionStatus) = @_;

    return unless (scalar(@{$collectionStatus}) > 0);

    my $credentials = credentials();

    if (not defined $credentials) {
        return undef;
    }

    my $ret = _sshCommand($credentials, 'ls ' . _metadataDir($credentials));
    foreach my $line (@{$ret}) {
        chomp($line);
    }

    my @collectionMD = map { metaFilenameFromDate($_->{date}) } @{$collectionStatus};

    my @filesToDelete = grep { $_ ne none(@collectionMD) } @{$ret};

    if ( @filesToDelete ) {
        @filesToDelete = map { _metadataDir($credentials) . $_ } @filesToDelete;
        _sshCommand($credentials, 'rm -f ' . join(' ', @filesToDelete));
    }
}

1;
