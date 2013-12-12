# Copyright (C) 2010-2012 Zentyal S.L.
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
use EBox::Exceptions::NotConnected;
use EBox::Exceptions::EBackup::BadSymmetricKey;
use Error qw(:try);
use File::Slurp;
use Perl6::Junction qw(none);
use YAML::XS;
use Date::Calc qw( Add_Delta_DHMS);

use constant FINGERPRINT_FILE => EBox::Config::share() . 'zentyal-ebackup/server-fingerprints';

# Method: isSubscribed
#
# Returns:
#   bool - whether the disaster recovery addon is available for the server or not
#
sub isSubscribed
{
    my ($self, %params) = @_;

    return 0;
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
        # this means that it does not have disaster recovery
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

    $credentials->{confBackupDir} = confBackupDir($commonName);

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
    my $confBackupDir = $credentials->{confBackupDir};

    try {
        foreach my $dir (($dataDir, $metaDir, $confBackupDir)) {
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

sub _scppassCommandAsString
{
    my ($credentials, $src, $dst) = @_;

    my $password = $credentials->{password};
    EBox::EBackup::Password::setPasswdFile($password);
    my $passwdFile = EBox::EBackup::Password->PASSWD_FILE;

    my $fullCmd =  qq{ sshpass -f $passwdFile scp  } .
               q{-o GlobalKnownHostsFile=} . FINGERPRINT_FILE . " $src $dst";


    return $fullCmd;
}

sub _scppassCloudPath
{
    my ($credentials, $path) = @_;
    my $server = $credentials->{server};
    my $username = $credentials->{username};
    return $username . '@' . $server . ':' .  $path;
}


sub configuredEncryptionMode
{
    my $ebackup =  EBox::Global->getInstance()->modInstance('ebackup');
    my $remoteSettings = $ebackup->model('RemoteSettings');
    my $encryptionType = $remoteSettings->usedEncryptionMode();
    return $encryptionType;
}

sub configuredEncryptionPassword
{
    my $ebackup =  EBox::Global->getInstance()->modInstance('ebackup');
    my $remoteSettings = $ebackup->model('RemoteSettings');
    return $remoteSettings->row()->valueByName('symmetric');
}


# Method: writeDRMetadata
#
#   write to the remote server the backup metadata
#
#  Named parameters:
#    date - date of the backup. Must be in the same format used by duplicity
#    backupType - backup type (full, incremental)
#    backupDomains - hash ref backup domains stored indexed by backup
#    domain name containing the following keys: 'description', 'printableName'
#                                         and  optionally 'extraDataDump'
#    extraDataDumped - list of domaisn which dumepd its extra data in the backup
#
sub writeDRMetadata
{
    my %options =  @_;

    my $credentials = $options{credentials};
    my $date = $options{date};
    my $backupType = $options{backupType};
    my $backupDomains = $options{backupDomains};
    my %extraDataDumped = map { $_ => 1 } @{ $options{extraDataDumped} };

    # for convenience and compability
    my $hasConfiguration = $extraDataDumped{configuration} ? 1 : 0;
    $backupDomains->{'configuration'} = { description   => __('Configuration'),
                                          printableName => __('Configuration'),
                                          extraDataDump => 1,
                                         };

    # remove domains which need extraData if it was not correctly dumped
    my @domainNames = keys %{ $backupDomains };
    foreach my $domain (@domainNames) {
        if (exists $backupDomains->{$domain}->{extraDataDump} and
                   $backupDomains->{$domain}->{extraDataDump} and
                   (not $extraDataDumped{$domain})
           ) {
            $backupDomains->{$domain}->{failed} = 1;
        }
    }

    # add size to backup domains
    my $sizeByDomain = backupDomainsSize();
    foreach my $domain (keys %{ $backupDomains }) {
        if (exists $sizeByDomain->{$domain}) {
            $backupDomains->{$domain}->{size} = $sizeByDomain->{$domain};
        }
    }


    my $encryptionType = configuredEncryptionMode();
    my $commonName = $credentials->{commonName};
    my $filename = metaFilename($commonName, $date);

    my @modsInBackup =  map {
        $_->name()
    } @{ EBox::Backup->_modInstancesForBackup() };

    my $hostname;
    try {
        my $output = EBox::Sudo::command('hostname');
        $hostname = $output->[0];
        chomp $hostname;
    } otherwise {};

    my $metadata = {
        version => drDataVersion(),
        date => $date,
        encryptionType => $encryptionType,
        hasConfiguration => $hasConfiguration,
        backupType       => $backupType,
        backupDomains    => $backupDomains,
        eboxModules      => \@modsInBackup,
        hostname         => $hostname,
        commonName       => $commonName,
    };

    my $yaml = {};
    $yaml->{'backup'} = $metadata;

    my $tmpFile = EBox::Config::tmp() . $filename;
    YAML::XS::DumpFile($tmpFile, $yaml);

    my $metadataDir = _metadataDir($credentials);
    my $metadataFile = "$metadataDir/$filename";
    _uploadFileToCloud($credentials, $tmpFile, $metadataFile);
    unlink $tmpFile;
}

sub confBackupDir
{
    my ($commonName) = @_;
    return $commonName . '/confBak';
}

sub uploadConfigurationBackup
{
    my ($credentials, $date, $file) = @_;
    my $toUpload;
    # TODO encrypt if needed
    my $encrypt = configuredEncryptionMode();
    if ($encrypt eq 'disabled') {
        $toUpload = $file;
    } elsif ($encrypt eq 'symmetric') {
        my $pass = configuredEncryptionPassword();
        $toUpload = $file . '.gpg';
        _callGPG(
            gpgArgs => "-c -o $toUpload $file",
            password => $pass,
           );
    } else {
        EBox::error("Unknown encryption mode '$encrypt'. Configuration bakcup will NOT be uploaded" );
        return;
    }

    my $remotePath = _configurationBackupRemotePath($credentials, $date);
    _uploadFileToCloud($credentials, $toUpload, $remotePath);
}


sub downloadConfigurationBackup
{
    my ($credentials, $date, $dst) = @_;

    my $remotePath = _configurationBackupRemotePath($credentials, $date);
    if (not _existsFileInCloud($credentials, $remotePath)) {
        $remotePath = _oldConfigurationBackupRemotePath($credentials, $date);
        if (not _existsFileInCloud($credentials, $remotePath)) {
            throw EBox::Exceptions::External(
                __('Cannot found conifguration backup in cloud')
               );
        }
    }

    _downloadFileFromCloud($credentials, $remotePath, $dst);
    EBox::Sudo::root("chown ebox.ebox $dst");

    my $encryption = exists $credentials->{encSelected} ?
                            $credentials->{encSelected} :
                            'none';
    if (($encryption eq 'none') or ($encryption eq 'disabled')) {
        # no decrypt needed
        return $dst;
    } elsif ($encryption eq 'symmetric') {
        my $pass = $credentials->{encValue};
        my $decDst = $dst . '.clear';
        _callGPG(
            gpgArgs => "-d -o $decDst $dst",
            password => $pass,
           );
        return $decDst;
    } else {
        throw EBox::Exceptions::Internal("No decryption supported for method '$encryption'. Configuration backup not decrypted" );
    }

}

sub _configurationBackupRemotePath
{
    my ($credentials, $date) = @_;
    my $cn = $credentials->{commonName};
    my $gmtDate = _dateToGMT($date);
    my $path = $credentials->{confBackupDir};
    $path .= "/$cn-conf-" . $gmtDate .  '.tar';
    return $path;
}

sub _oldConfigurationBackupRemotePath

{
    my ($credentials, $date) = @_;
    $date =~ s/\s/-/g;
    my $path = $credentials->{confBackupDir};
    $path .= '/conf-' . $date .  '.tar';
    return $path;
}


sub _callGPG
{
    my (%params) = @_;
    my $gpgArgs = $params{gpgArgs};
    my $pass    = $params{password};

    my $gpgDir = EBox::Config::home() . '.gnupg';
    EBox::Sudo::root("chown -R ebox.ebox $gpgDir");

    my $statusFile = EBox::Config::tmp() . 'gpgStatus';
    EBox::Sudo::root("rm -f $statusFile");

    my $gpg = "gpg --passphrase-fd 0 --no-tty --status-file $statusFile $gpgArgs";
    open my $GPG_PROC, "|$gpg" or
        throw EBox::Exceptions::Internal("Error opening process $gpg");
    print $GPG_PROC "$pass/n" or
        throw EBox::Exceptions::Internal("Error piping to process $gpg");
    if (not close $GPG_PROC) {
        if (not $!) {
            my $exitValue = $?;
            my $status = File::Slurp::read_file($statusFile);
            print $status;
            print "\n";
            if ($status =~ m/^\[GNUPG:\]\s+DECRYPTION_FAILED/m) {
                throw EBox::Exceptions::EBackup::BadSymmetricKey();
            } else {
                throw EBox::Exceptions::External("GPG failed. Exit code $exitValue");
            }
        }else {
            throw EBox::Exceptions::Internal("Error closing process $gpg: $!");
        }
    }
}


sub _existsFileInCloud
{
    my ($credentials, $path) = @_;

    if ($path =~ m/[\s'"]/) {
        throw EBox::Exceptions::Internal("this method could not beused with paths with spaces or quotes: $path");
    }
    my $cmd = _sshpassCommandAsString($credentials, "ls $path");
    EBox::Sudo::silentRoot($cmd);
    return $? == 0;
}

sub _uploadFileToCloud
{
    my ($credentials, $fromLocalPath, $toCloudPath) = @_;
    my $scpTo = _scppassCloudPath($credentials, $toCloudPath);
    my $cmd = _scppassCommandAsString($credentials, $fromLocalPath, $scpTo);
    EBox::Sudo::root($cmd);
}


sub _downloadFileFromCloud
{
    my ($credentials, $fromCloudPath, $toLocalPath) = @_;
    my $scpFrom = _scppassCloudPath($credentials, $fromCloudPath);
    my $cmd = _scppassCommandAsString($credentials, $scpFrom, $toLocalPath);
    EBox::Sudo::root($cmd);
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
    my $cn          = $credentials->{commonName};
    my $metadataDir =  _metadataDir($credentials);

    my $filename = metaFilename($cn, $date);
    my $fromPath = $metadataDir . '/' . $filename;
    if (not _existsFileInCloud($credentials, $fromPath)) {
        $filename = _oldMetaFilenameFromDate($date);
        $fromPath = $metadataDir . '/' . $filename;
        if (not _existsFileInCloud($credentials, $fromPath)) {
            throw EBox::Exceptions::External(
                __x('Cannot find metadata for backup date {date} in cloud',
                    date => $date
                   )
               );
        }

    }

    my $toPath = "$dir/$filename";
    _downloadFileFromCloud($credentials, $fromPath, $toPath);
    return $toPath;
}

my %nmonthByName = (
    'Jan' => 1,
    'Feb' => 2,
    'Mar' => 3,
    'Apr' => 4,
    'May' => 5,
    'Jun' => 6,
    'Jul' => 7,
    'Aug' => 8,
    'Sep' => 9,
    'Oct' => 10,
    'Nov' => 11,
    'Dec' => 12,
   );

# Method: metaFilename
# Parameters:
#  cn   - server common name
#  date - date of the backup in the same format which is used by duplicity
#
# Returns: path of the file which contains the matainformation for the backup in
#    the given date
#
sub metaFilename
{
    my ($cn, $date) = @_;

    my $filename = "$cn-";
    $filename .= _dateToGMT($date);
    $filename .= '.backup.yaml';
    return $filename;
}

sub _dateToGMT
{
    my ($date) = @_;

    my $timezone = `date +%z`;
    my ($tzSign, $tzHour, $tzMin) = $timezone =~m/^([+-])(\d\d)(\d\d)/;
    if ($tzSign eq '+') {
        $tzHour = - $tzHour;
        $tzMin = - $tzMin;
    }

    # date are like this: 'Fri Oct 14 23:01:51 2011'
    my ($wday, $month, $day, $time, $year) = split '\s+', $date;
    my $nmonth = $nmonthByName{$month};
    $nmonth or $nmonth = $month;
    my ($hour, $min, $sec) = split ':', $time;

    # calc GMT
    ($year,$nmonth,$day, $hour,$min,$sec) =
        Add_Delta_DHMS($year,$nmonth,$day, $hour,$min,$sec, 0,$tzHour,$tzMin,0);

    my $gmt = "$year-$nmonth-$day";
    $gmt .= "T$hour:$min:$sec" . 'Z';
    return $gmt;
}

sub _oldMetaFilenameFromDate
{
    my ($date) = @_;
    my $filename = $date;
    $filename =~ s/\s/-/g;
    $filename .= '.backup.yaml';
    return $filename;
}

sub _dataDir
{
    my ($credentials) = @_;
    my $commonName = $credentials->{commonName};
    return "$commonName/data";
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
    return 2;
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

    my @collectionMD = map { metaFilename($credentials->{commonName}, $_->{date}) } @{$collectionStatus};

    my @filesToDelete = grep { $_ ne none(@collectionMD) } @{$ret};

    if ( @filesToDelete ) {
        @filesToDelete = map { _metadataDir($credentials) . $_ } @filesToDelete;
        _sshCommand($credentials, 'rm -f ' . join(' ', @filesToDelete));
    }
}

sub collectionEncrypted
{
    my ($credentials) = @_;
    my $dir = _dataDir($credentials);
    my $cmd = "ls -1 $dir";
    my $output;
    try {
       $output  = _sshCommand($credentials, $cmd);
   } catch EBox::Exceptions::Sudo::Command with {
       my $ex =shift;
       # probably a file not exists error (or permission..), benign
       $output = [];
   };

    my $encrypted = undef;
    foreach my $line (@{ $output }) {
        chomp $line;
        if ($line =~ m/^duplicity-full-signatures.*sigtar\.gpg$/) {
            $encrypted = 1;
            last ;
        } elsif ($line =~ m/^duplicity-full-signatures.*sigtar\.gz$/) {
            $encrypted = 0;
            last;
        }

    }

    return $encrypted;
}

# in Kbs
sub backupDomainsSize
{
    my ($globalRO) = @_;

    my $global  = EBox::Global->getInstance($globalRO);
    my $ebackup =  $global->modInstance('ebackup');

    my %sizeByDomain;
    my @domains = keys %{ $ebackup->_enabledBackupDomains(0) };
    foreach my $domain (@domains) {
        my $selection = $ebackup->_rawModulesBackupDomainsFileSelections($domain => 1);
        my $size = 0;

        my %dirs;
        foreach my $sel (@{ $selection }) {
            foreach my $ex (@{ $sel->{excludes} }) {
                my $alreadyMatched = 0;
                foreach my $dir (keys %dirs) {
                    if (EBox::FileSystem::isSubdir($ex, $dir)) {
                        $alreadyMatched = 1;
                        last;
                    } elsif (EBox::FileSystem::isSubdir($dir, $ex)) {
                        # we remove it to avoid counting same files more than
                        # one time
                        delete $dirs{$dir};
                    }
                }
                if (not $alreadyMatched) {
                    $dirs{$ex} = undef;
                }
            }

            foreach my $inc (@{ $sel->{includes} }) {
                my $alreadyMatched = 0;
                my $dirSize = 0;
                foreach my $dir (keys %dirs) {
                    if (EBox::FileSystem::isSubdir($inc, $dir)) {
                        $alreadyMatched = 1;
                        last;
                    } elsif (EBox::FileSystem::isSubdir($dir, $inc)) {
                        if (not defined $dirs{$dir}) {
                            # lazy initialzation exclude
                            if (EBox::Sudo::fileTest('-e', $dir)) {
                                $dirs{$dir} = EBox::FileSystem::dirDiskUsage($dir);
                            } else {
                                $dirs{$dir} = 0;
                            }

                        }
                        # either should not be added or is already added, so i
                        # neither case we remove the,
                        $size -= $dirs{$dir};
                    }
                }
                if (not $alreadyMatched) {
                    if (EBox::Sudo::fileTest('-e', $inc)) {
                        $dirSize  += EBox::FileSystem::dirDiskUsage($inc);
                    }
                    $dirs{$inc} = $dirSize;
                    $size += $dirSize
                }
            }
        }

        # add size from extra data
        foreach my $mod (@{ $global->modInstances() }) {
            if ($mod->can('dumpExtraBackupDataSize')) {
                my $dir =   $ebackup->extraDataDir() . '/' . $mod->name();
                $size += $mod->dumpExtraBackupDataSize($dir, $domain => 1);
            }
        }

        $sizeByDomain{$domain} = $size;
        # next domain...
    }

    return \%sizeByDomain;
}

1;
