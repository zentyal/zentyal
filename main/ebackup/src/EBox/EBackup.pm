# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::EBackup;

use base qw(EBox::Module::Service);

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Backup;
use EBox::Sudo;
use File::Slurp;
use File::Basename;
use EBox::FileSystem;
use Filesys::Df;
use EBox::DBEngineFactory;
use EBox::EBackup::Password;

use MIME::Base64;
use String::ShellQuote;
use Date::Parse;
use TryCatch;
use EBox::Util::Lock;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotConnected;
use EBox::Exceptions::EBackup::FileNotFoundInBackup;
use EBox::Exceptions::EBackup::BadSymmetricKey;
use EBox::Exceptions::EBackup::TargetNotReady;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

use constant EBACKUP_CONF_FILE => EBox::Config::etc() . 'ebackup.conf';
use constant DUPLICITY_WRAPPER => EBox::Config::share() . '/zentyal-ebackup/duplicity-wrapper';
use constant LOCK_FILE     => EBox::Config::tmp() . 'ebox-ebackup-lock';

use constant UPDATE_STATUS_IN_BACKGROUND_LOCK =>  'ebackup-collectionstatus';
use constant UPDATE_STATUS_SCRIPT =>   EBox::Config::share() . '/zentyal-ebackup/update-status';
use constant FINGERPRINT_FILE => EBox::Config::share() . 'zentyal-ebackup/server-fingerprints';


# Constructor: _create
#
#      Create a new EBox::EBackup module object
#
# Returns:
#
#      <EBox::EBackup> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'ebackup',
            printableName => __('Backup'),
            @_);

    bless($self, $class);
    return $self;
}

# Method: addModuleStatus
#
#       Overrides to show a custom status for ebackup module
#
# Overrides:
#
#       <EBox::Module::Service::addModuleStatus>
#
sub addModuleStatus
{
    my ($self, $section) = @_;

    # FIXME: Change the remote settings configuration to know if the
    # backup is being done correctly
    $section->add(new EBox::Dashboard::ModuleStatus(
        module        => $self->name(),
        printableName => $self->printableName(),
        enabled       => $self->isEnabled(),
        running       => $self->isEnabled(),
        nobutton      => 1));
}

# This hook is called before checking if a target is ready for the backup
# It is intended to be used to mount filesystems or
# to  do any operation needed to make ready the targer
sub preCheckTargetHook
{
    my ($self) = @_;
    $self->_hook('prechecktarget');
}

sub preBackupHook
{
    my ($self) = @_;
    $self->_hook('prebackup');
}

sub postBackupHook
{
    my ($self) = @_;
    $self->_hook('postbackup');
}

# Method: restoreFile
#
#   Given a file and date it tries to restore it
#
# Parameters:
#
#   (POSTIONAL)
#
#   file - strings containing the file name to restore
#   date - string containing a date that can be parsed by Date::Parse
#   destination - path to restore in place of the previous path (optional)
#   urlParams
#
sub restoreFile
{
    my ($self, $file, $date, $destination, $urlParams) = @_;
    defined $urlParams or
        $urlParams = {};

    if ((not $self->configurationIsComplete()) and
        (keys %{ $urlParams} == 0) ) {
        return;
    }

    $destination or
        $destination = $file;
    my $destinationDir = File::Basename::dirname($destination);
    if ($destinationDir ne '/') {
        if (not EBox::Sudo::fileTest('-e', $destinationDir)) {
            throw EBox::Exceptions::External(
                __x('Cannot restore to {d}: {dd} does not exist',
                    d => $destination,
                    dd => $destinationDir,
                   )
               );
        }
        if (not EBox::Sudo::fileTest('-d', $destinationDir)) {
            throw EBox::Exceptions::External(
                __x('Cannot restore to {d}: {dd} is not a directory',
                    d => $destination,
                    dd => $destinationDir,

                   )
               );
        }
    }

    my $url = $self->_remoteUrl(%{ $urlParams });
    my $cmd = $self->_duplicityRestoreFileCmd($url,
                                              $file, $date,
                                              $destination,
                                              );
    try {
        EBox::Sudo::root($cmd);
    } catch (EBox::Exceptions::Sudo::Command $e) {
        my $error = join "\n", @{ $e->error() };
        if ($error =~ m/not found in archive, no files restored/) {
            throw EBox::Exceptions::EBackup::FileNotFoundInBackup(
                    file => $file,
                    date => $date,
               );
        } elsif ($error =~ m/gpg: decryption failed: bad key/) {
            throw EBox::Exceptions::EBackup::BadSymmetricKey();
        } elsif ($error =~ m/No backup chains found/) {
            throw EBox::Exceptions::External(
                __x(q{No backup archives found. Maybe they were deleted?.} . ' ' .
                    q{Run '{cmd}' to refresh backup's information.},
                    cmd => 'service zentyal ebackup restart')
            );
        } else {
            $e->throw();
        }
    }
}

sub _duplicityRestoreFileCmd
{
    my ($self, $url, $file, $date, $destination) = @_;

    unless (defined($file)) {
        throw EBox::Exceptions::MissingArgument('file');
    }
    unless (defined($date)) {
        throw EBox::Exceptions::MissingArgument('date');
    }

    my $rFile;
    if ($file eq '/') {
        $rFile = undef;
    } else {
        $rFile = $file;
        $rFile =~ s:^/+::; # file must be relative

        # Escape metacharacters
        $rFile = $self->_escapeFile($rFile);
    }
    $destination = $self->_escapeFile($destination);

    my $time = Date::Parse::str2time($date);
    my $cmd = DUPLICITY_WRAPPER .  " --force -t $time ";
    if ($rFile) {
        $cmd .= "--file-to-restore $rFile ";
    }
    $cmd .= " $url $destination";
    return $cmd;
}

sub _escapeFile
{
    my ($self, $file) = @_;
    $file = shell_quote($file);
    return $file;
}

# Method: lastBackupDate
#
#  Returns:
#   string with the date of the last backup made, undef if there are not backups
#
#  Warning:
#    the information is getted from the cache, remember you could call
#    _syncBackupCaches to refresh the cache
sub lastBackupDate
{
    my ($self, $urlParams) = @_;
    my $status = $self->remoteStatus($urlParams);
    if (not @{ $status }) {
        return undef;
    }

    return $status->[-1]->{date};
}

# Method: remoteArguments
#
#   Return the arguments to be used by duplicty
#
#
# Arguments:
#
#       type - full or incremental
#       urlParams -
#
# Returns:
#
#   String contaning the arguments for duplicy
sub remoteArguments
{
    my ($self, $type, $urlParams) = @_;
    defined $urlParams or
        $urlParams = {};

    my $volSize = $self->_volSize();
    my $fileArgs = $self->remoteFileSelectionArguments();
    my $cmd =  DUPLICITY_WRAPPER .  " $type " .
            "--volsize $volSize " .
            "$fileArgs " .
            " / " . $self->_remoteUrl(%{ $urlParams });
    return $cmd;
}

sub extraDataDir
{
    return EBox::Config::home() . 'extra-backup-data';
}

# Method: dumpExtraData
#
#    dumps into an always-backuped directory extra data regardless of the
#    includes or the excludes. Now the extra dumped data is only a configuration backup
#
sub dumpExtraData
{
    my ($self, $readOnlyGlobal) = @_;

    my $extraDataDir = $self->extraDataDir();
    EBox::Sudo::root("rm -rf $extraDataDir");
    system "mkdir -p $extraDataDir" ;
    ($? == 0) or
        throw EBox::Exceptions::Internal("Cannot create directory $extraDataDir. $!");
    if (not -w $extraDataDir) {
        EBox::error("Cannot write in extra backup data directory $extraDataDir");
        return [];
    }

    my $global = EBox::Global->getInstance($readOnlyGlobal);
    try {
        my $filename = 'confbackup.tar';
        my $bakFile = EBox::Backup->backupDir() . "/$filename";
        EBox::Backup->makeBackup(
                                 description => 'Configuration backup',
                                 destination => $filename,
                                 fallbackToRO => 1,
                                );
        if (not $readOnlyGlobal) {
            # XXX Some modules such as events are marked as changed after
            #     running ebox-make-backup.
            #     This is a temporary workaround
            $global->revokeAllModules();
        }

        EBox::Sudo::command("mv $bakFile $extraDataDir");
    } catch ($e) {
        EBox::error("Configuration backup failed: $e. It will not be possible to restore the configuration from this backup, but the data will be backed up.");
    }
}

# Method: includedConfigBackupPath
#
# Returns:
#  path of the config backup in the backed-up file system
sub includedConfigBackupPath
{
    my ($self) = @_;
    my $path = $self->extraDataDir() .  '/confbackup.tar';
    return $path;
}


sub remoteFileSelectionArguments
{
    my ($self) = @_;
    my $args = '';
    # Include configuration backup
    $args .= ' --include=' . $self->extraDataDir . ' ';

    $args .= $self->_autoExcludesArguments();

    my $excludesModel = $self->model('BackupExcludes');
    $args .= $excludesModel->fileSelectionArguments();
    return $args;
}

sub _autoExcludesArguments
{
    my ($self) = @_;

    my $args = '';
    # directories excluded to avoid risk of
    # duplicity crash_remoteUrl
    $args .= "--exclude=/proc --exclude=/sys ";

    # exclude backup directory if we are using 'filesystem' mode
    my $settings = $self->model('BackupSettings');
    my $row = $settings->row();
    if ($row->valueByName('method') eq 'file') {
        my $dir = $row->valueByName('target');
        $args .=  "--exclude=$dir ";
    }

    return $args;
}

# Method: remoteDelOldArguments
#
#   Return the arguments to be used by duplicty to delete old files
#
# Returns:
#
#   String contaning the arguments for duplicy
sub remoteDelOldArguments
{
    my ($self, $type, $urlParams) = @_;
    defined $urlParams
        or $urlParams = {};

    my $model = $self->model('BackupSettings');
    my $removeArgs = $model->removeArguments();

    return DUPLICITY_WRAPPER . " $removeArgs --force " . $self->_remoteUrl(%{ $urlParams });
}

# Method: remoteListFileArguments
#
#   Return the arguments to be used by duplicty to list remote files
#
# Returns:
#
#   String contaning the arguments for duplicity
#
sub remoteListFileArguments
{
    my ($self, $type, $urlParams) = @_;
    defined $urlParams
        or $urlParams = {};

    my $model = $self->model('BackupSettings');

    return DUPLICITY_WRAPPER . ' list-current-files ' .
             $self->_remoteUrl(%{ $urlParams });
}

#  Method: remoteGenerateListFile
#
#  Warning: it will raise exception if there isnt at least one backup yet
sub remoteGenerateListFile
{
    my ($self) = @_;
    my $tmpFile = $self->tmpFileList();
    if (not $self->configurationIsComplete()) {
        EBox::Sudo::root("rm -f $tmpFile");
        return;
    }

    my $collectionCmd = $self->remoteListFileArguments();

    my $success = 0;
    try {
        EBox::Sudo::root("$collectionCmd > $tmpFile");
        $success = 1;
    } catch (EBox::Exceptions::Sudo::Command $e) {
        my $error = join "\n", @{ $e->error() };
        # check if there is a no-backup yet error
        if ($error =~ m/No signature chains found/ or
            $error =~ m/No such file or directory/
           ) {
            $success = 0;
        } else {
            $e->throw();
        }
    }

    if ($success) {
        EBox::Sudo::root("chown ebox:ebox $tmpFile");
    } else {
        EBox::Sudo::root("rm -f $tmpFile");
    }
}

# Method: remoteStatus
#
#  Return the status of the remote backup.
#
#  Params:
#  noCacheUrl - if present use this URL specification instead of
#               the module configuration and cached results.
#
# Returns:
#
#  Array ref of hash refs containing:
#
#  type - full or incremental backup
#  date - backup date
#  volumes - the number of stored volumes
sub remoteStatus
{
    my ($self, $noCacheUrl) = @_;

    my @lines;
    my $retrieve;
    if ($noCacheUrl) {
        $retrieve = 1;
    } elsif (_currentStatusIsCached()) {
        @lines = @{ _currentStatusFromCache() };
    } else {
        $retrieve = 1;
    }

    if ($retrieve) {
        my $status = $self->_retrieveBackupStatus($noCacheUrl);
        if (not $status) {
            throw EBox::Exceptions::External(
                                             __('Could not get backup collection status, check whether the parameters and passwords are correct')
                                            );
        }

        @lines = @{ $status  };
    }

    my @status;
    for my $line (@lines) {
        # We are trying to match this:
        #  Full Wed Sep 23 13:30:56 2009 95
        #  Incr Fri Sep 23 13:30:56 2009 95
        my $regexp = '^\s+(\w+)\s+(\w+\s+\w+\s+\d\d? '
            . '\d\d:\d\d:\d\d \d{4})\s+(\d+)';
        if ($line =~ /$regexp/ ) {
            push (@status, {
                type => $1,
                date => $2,
                volumes => $3,
                           }
                 );
        }
    }

    return \@status;
}

# Method: tmpCurrentStatus
#
#   Return the patch to store the temporary current status cache
#
# Returns:
#
#   string
sub tmpCurrentStatus
{
    return EBox::Config::tmp() . "backupstatus-cache";
}

sub _currentStatusIsCached
{
    return (-f tmpCurrentStatus());
}

sub _currentStatusFromCache
{
    if (not _currentStatusIsCached()) {
        throw EBox::Exceptions::Internal("No cache for current status");
    }
    my @lines = File::Slurp::read_file(tmpCurrentStatus());
    foreach my $line (@lines) {
        utf8::decode($line);
    }
    return \@lines;
}

# Method: remoteGenerateStatusCache
#
#   Generate a current status cache. This is to be called
#   from a crontab script or restarting the module
#
sub remoteGenerateStatusCache
{
    my ($self, $urlParams) = @_;
    $self->_clearStorageUsageCache();
    my $status = $self->_retrieveBackupStatus($urlParams);
    $self->_setCurrentStatus($status);
}

sub _setCurrentStatus
{
    my ($self, $status) = @_;
    my $file = tmpCurrentStatus();
    if (defined $status) {
        File::Slurp::write_file($file, { binmode => ':raw' }, $status);
    } else {
        ( -e $file) and
            unlink $file;
    }
}

sub _retrieveBackupStatusInBackground
{
    my ($self, $urlParams) = @_;
    my $args = '';
    if ($urlParams) {
        $args = join ' ' , %{ $urlParams };
    }

    my $cmd = 'sudo ' .
        UPDATE_STATUS_SCRIPT .
        ' ' . $args .
        ' &';
    system $cmd;
}

sub _retrieveBackupStatus
{
    my ($self, $urlParams,) = @_;
    defined $urlParams
        or $urlParams = {};

    if ((not keys %{ $urlParams }) and
        (not $self->configurationIsComplete())) {
        return;
    }

    my $remoteUrl = $self->_remoteUrl(%{ $urlParams  });
    my $cmd = DUPLICITY_WRAPPER . " collection-status $remoteUrl";
    my $status = undef;
    try {
        $status =  EBox::Sudo::root($cmd);
    } catch (EBox::Exceptions::Sudo::Command $e) {
        my $error = join "\n", @{ $e->error() };
        if ($error =~ m/gpg: decryption failed: bad key/) {
            throw EBox::Exceptions::EBackup::BadSymmetricKey();
        }elsif ($error =~ m/No signature chains found/) {
            $status = [];
        }
    }

    foreach my $line (@{ $status  }) {
        utf8::decode($line);
    }

    return $status;
}

sub updateStatusInBackgroundLock
{
    my ($self) = @_;

    my $res;
    try {
        $res = EBox::Util::Lock::lock(UPDATE_STATUS_IN_BACKGROUND_LOCK);
    } catch {
        throw EBox::Exceptions::External(__('Another process is updating the collection status. Please, wait and retry'));
    }

    return $res;
}

sub updateStatusInBackgroundUnlock
{
    my ($self) = @_;
    my $res = EBox::Util::Lock::unlock(UPDATE_STATUS_IN_BACKGROUND_LOCK);
    system "rm -f " . _updateStatusInBackgroundLockFile();
    return $res;
}

sub updateStatusInBackgroundRunning
{
    my ($self) = @_;
    return -f _updateStatusInBackgroundLockFile()
}

sub waitForUpdateStatusInBackground
{
    my ($self) = @_;

    if (not $self->updateStatusInBackgroundRunning()) {
        return;
    }

    EBox::info('Waiting for update status in background');
    sleep 5;

    my $maxWait = 360; # half four
    # wait for any update status backgroud process
    while ($self->updateStatusInBackgroundRunning()) {
        if (not $maxWait) {
            EBox::warn("Aborted wait for background running");
            return;
        }
        sleep 5;
        $maxWait -= 1;
    }

    EBox::info("Wait for update status in background finished");
}

sub _updateStatusInBackgroundLockFile
{
    return EBox::Util::Lock::_lockFile(UPDATE_STATUS_IN_BACKGROUND_LOCK);
}

# Method: tmpFileList
#
#   Return the patch to store the temporary remote file list
#
# Returns:
#
#   string
sub tmpFileList
{
    return EBox::Config::tmp() . "backuplist-cache";
}

# Method: remoteListFiles
#
#  Return the list of the remote backed up files
#
# Returns:
#
#  Array ref of strings containing the file path
#
sub remoteListFiles
{
    my ($self) = @_;

    my $file = tmpFileList();
    return [] unless (-f $file);

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime) = stat $file;
    my $updateCache;
    if (not $self->{files}) {
        $updateCache = 1 ;
    } elsif (not $self->{files_mtime}) {
        $updateCache = 1;
    } elsif ($mtime > $self->{files_mtime}) {
        $updateCache = 1;
    }

    if ($updateCache) {
        $self->{files_mtime} = $mtime;
        my @files;
        foreach my $line (File::Slurp::read_file($file)) {
            utf8::decode($line);
            my $regexp = '^\s*(\w+\s+\w+\s+\d\d? '
                . '\d\d:\d\d:\d\d \d{4} )(.*)';
            if ($line =~ /$regexp/ ) {
                push (@files, "/$2");
            }
        }
        $self->{files} = \@files;
    }

    return $self->{files};
}

# Method: setBackupBackupCron
#
#   configure crontab according to user configuration
#   to call our backup script
#
sub setBackupBackupCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('BackupSettings')->crontabStrings();

    my $nice = EBox::Config::configkey('ebackup_scheduled_priority');
    my $script = '';
    if ($nice) {
        if ($nice =~ m/^\d+$/) {
            $script = "nice -n $nice " if $nice > 0;
        } else {
            EBox::error("Scheduled backup priority must be a positive number" );
        }
    }
    $script .= EBox::Config::share() . 'zentyal-ebackup/backup-tool';

    my $fullList = $strings->{full};
    if ($fullList) {
        foreach my $full (@{ $fullList }) {
            push (@lines, "$full $script --full");
        }
    }

    my $incrList = $strings->{incremental};
    if ($incrList) {
        foreach my $incr (@{ $incrList }) {
            push (@lines, "$incr $script --incremental");
        }
    }

    my $tmpFile = EBox::Config::tmp() . 'ebackup-cron';
    open(my $tmp, '>', $tmpFile);

    my $onceList = $strings->{once};
    if ($onceList) {
        foreach my $once (@{ $onceList }) {
            push (@lines, "$once $script --full-only-once");
        }
    }

    if ($self->isEnabled()) {
        for my $line (@lines) {
            print $tmp "$line\n";
        }
    }
    close($tmp);

    my $dst = backupCronFile();
    EBox::Sudo::root("install --mode=0644 $tmpFile $dst");
}

sub removeBackupBackupCron
{
    my $rmCmd = "rm -f " . backupCronFile();
    EBox::Sudo::root($rmCmd);
}

sub backupCronFile
{
    return '/etc/cron.d/zentyal-ebackup';
}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    if (not $self->configurationIsComplete()) {
        $self->removeBackupBackupCron();
        return;
    }

    my $model = $self->model('BackupSettings');

    # Store password
    my $pass = $model->row()->valueByName('password');
    defined $pass or
        $pass = '';
    EBox::EBackup::Password::setPasswdFile($pass);


    my $symPass = $model->row->valueByName('encryption');
    $self->$symPass = '' unless (defined($symPass));
    EBox::EBackup::Password::setSymmetricPassword($symPass);

    if ($self->isEnabled()) {
        $self->setBackupBackupCron();
    } else {
        $self->removeBackupBackupCron();
    }

    $self->_syncBackupCachesInBackground;
}

# this calls to remoteGenerateStatusCache and if there was change it regenerates
# also the files list

sub _syncBackupCachesInBackground
{
    my ($self) = @_;
    $self->_clearStorageUsageCache();
    $self->_retrieveBackupStatusInBackground();
}

# Method: menu
#
# Overrides:
#
#      <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'EBackup/Composite/General',
                                    'icon' => 'ebackup',
                                    'text' => $self->printableName(),
                                    'order' => 800));
}

# XXX TODO: refactor parameters from model and/or subscription its own method
sub _remoteUrl
{
    my ($self, %forceParams) = @_;

    my ($method, $user, $target);
    my ($encSelected, $encValue);
    my $model = $self->model('BackupSettings');

    my $sshKnownHosts = 0;

    if (%forceParams) {
        $method= $forceParams{method};
        $method or
            throw EBox::Exceptions::MissingArgument('method');

        $target = $forceParams{target};
        $target or
            throw EBox::Exceptions::MissingArgument('target');

        $forceParams{encValue} or
            $forceParams{encValue} = 'disabled';

        my @noFileNeededParams = qw(user password);
        foreach my $param (@noFileNeededParams) {
            if (not $forceParams{$param}) {
                if ($method eq 'file') {
                    $forceParams{$param} = '';
                } else {
                    throw EBox::Exceptions::MissingArgument($param);
                }
            }
        }

        $user = $forceParams{user};
        my $passwd = $forceParams{password};
        EBox::EBackup::Password::setPasswdFile($passwd, 1);
        $encSelected = $forceParams{encSelected};
        $encValue = $forceParams{encValue};
        $sshKnownHosts = ($method eq 'scp');

    } else {
        $method = $model->row()->valueByName('method');
        $target = $model->row()->valueByName('target');
        $user = $model->row()->valueByName('user');
    }

    my $url = "$method://";

    if ($method eq 'ftp') {
        $url = "ncftp+$url";
    }
    if ($method eq 'scp') {
        $url = "pexpect+$url";
    }

    if ($user and ($method ne 'file')) {
        $url .= "$user@";
    }
    $url .= $target if defined($target);

    if ($method eq 'scp') {
        $url .= ' --ssh-askpass';
    }

    if ($sshKnownHosts) {
        $url .= ' --ssh-options="-oUserKnownHostsFile='
            . FINGERPRINT_FILE . '"';
    }

    if (not %forceParams) {
        my $encryption = $model->row()->elementByName('encryption');
        $encValue = $encryption->value();
        $encSelected = $encryption->selectedType();
    }

    if ($encValue eq 'disabled') {
        $url .= ' --no-encryption';
    } else {
        if ($encSelected eq 'asymmetric') {
            $url .= " --encrypt-key $encValue";
        }
    }

    if ($forceParams{alternativePassword}) {
        $url .= ' --alternative-password';
    }

    return $url;
}

sub _volSize
{
    my $volSize = EBox::Config::configkeyFromFile('volume_size',
                                                  EBACKUP_CONF_FILE);
    if (not $volSize) {
        $volSize = 25;
    }
    return $volSize;
}

# Method: tempdir
#
#  Returns:
#    temporal directory for duplicity (default: /tmp)
sub tempdir
{
    my $tmpdir = EBox::Config::configkeyFromFile('temp_dir',
                                                  EBACKUP_CONF_FILE);
    if ($tmpdir) {
        return $tmpdir;
    }

    return '/tmp';
}

# Method: archivedir
#
#  Returns:
#    arhcive dir for dupliciry
sub archivedir
{
    my $archivedir = EBox::Config::configkeyFromFile('archive_dir',
                                                  EBACKUP_CONF_FILE);
    if ($archivedir) {
        return $archivedir;
    }

    return '/var/cache/zentyal/duplicity';
}

sub configurationIsComplete
{
    my ($self) = @_;

    my $model = $self->model('BackupSettings');
    return $model->configurationIsComplete();
}

sub _backupProcessLockName
{
    return 'ebackup-process';
}

sub backupProcessLock
{
    my $name = _backupProcessLockName();
    EBox::Util::Lock::lock($name);
}

sub backupProcessUnlock
{
    my $name = _backupProcessLockName();
    EBox::Util::Lock::unlock($name);
}

# Method: storageUsage
#
#   get the available and used space in the storage place used to save the
#   backup collection
#
# Parameters:
#   force - dont use cached results
#
#  Returns:
#    hash ref with the keys:
#              - used: space used in Mb
#              - available: space available in Mb
#              - total: in Mb
#
# Warning:
# the results cache will fail if more space is taken or free without using
# backup-tool, this will be very possible with file storage
#
sub storageUsage
{
    my ($self, $force) = @_;
    if (not $self->configurationIsComplete()) {
        return undef;
    }

    my $file = _storageUsageCacheFile();
    if (not $force and -f $file) {
        my $cacheContents = File::Slurp::read_file($file);
        my ($usedCache,$availableCache, $totalCache) =
            split ',', $cacheContents;
        if ((defined $usedCache ) and (defined $availableCache) and
             (defined $totalCache)) {
            return {
                    used => $usedCache,
                    available => $availableCache,
                    total    => $totalCache,
                   }
        } else {
            # incorrect cache file, we get rid of it
            $self->_clearStorageUsageCache();
        }
    }

    my ($total, $used, $available);

    my $model  = $self->model('BackupSettings');
    my $method = $model->row()->valueByName('method');
    my $target = $model->row()->valueByName('target');

    if ($method eq 'file') {
        my $blockSize = 1024*1024; # 1024*1024 - 1Mb blocks
        my $df = df($target, $blockSize);
        $available = $df->{bfree};
        $total     = $df->{blocks};
        $used = $total - $available;
    }

    # XXX TODO SCP, FTP

    if (not defined $used) {
        $self->_clearStorageUsageCache();
        return undef;
    }

    my $result = {
            used => int($used),
            available => int($available),
            total     => int ($total),
                 };

    # update cache
    my $cacheStr = $result->{used} . ','  . $result->{available} .
                    ',' . $result->{total};
    File::Slurp::write_file($file, $cacheStr);

    return $result;
}

sub _storageUsageCacheFile
{
    return EBox::Config::tmp() . 'ebackup-storage-usage';
}

sub _clearStorageUsageCache
{
    my ($self) = @_;
    my $file = _storageUsageCacheFile();
    system "rm -f $file";
}

sub checkTargetStatus
{
    my ($self, $backupType) = @_;
    if (not $self->configurationIsComplete()) {
        throw EBox::Exceptions::External(__('Backup configuration not complete'));
    }

    my $model  = $self->model('BackupSettings');
    my $method = $model->row()->valueByName('method');
    my $target = $model->row()->valueByName('target');
    my $checkSize;

    if ($method eq 'file') {
        $self->_checkFileSystemTargetStatus($target);
    }

    my $storageUsage = $self->storageUsage(1);
    if ($storageUsage) {
        # check sizes
        my $free = $storageUsage->{available};
        my $estimated=  $self->_estimateBackupSize($backupType);
        if ($estimated > $free) {
            throw EBox::Exceptions::EBackup::TargetNotReady(
              __x('Free space in {target} too low. {free} Mb available and backup estimated size is  {req}',
                  target => $target,
                  free => $free,
                  req => $estimated
                 )
             );
        }
    }

    return 1;
}

sub _checkFileSystemTargetStatus
{
    my ($self, $target) = @_;

    if (EBox::Sudo::fileTest('-e', $target) and not (EBox::Sudo::fileTest('-d', $target))) {
        throw EBox::Exceptions::EBackup::TargetNotReady(
          __x(' {target} exists and is not longer a directory',
              target => $target
             )
           );
    }

    my $mountPoint;
    my %staticFs = %{ EBox::FileSystem::fileSystems() };
    foreach my $fsAttr (values %staticFs) {
        my $fsMountPoint = $fsAttr->{mountPoint};
        if ($fsMountPoint eq 'none') {
            next;
        }
        if ($fsMountPoint eq $target) {
            # exact match
            $mountPoint = $fsMountPoint;
            last;
        }
        EBox::FileSystem::isSubdir($target, $fsMountPoint) or
              next;
        if ($mountPoint) {
            # check if the mount point is more specific than the stored one
            my $mpComponents = split '/+', $mountPoint;
            my $fsMpComponents = split '/+', $fsMountPoint;
            ($fsMpComponents > $mpComponents) or
                next;
        }
        $mountPoint = $fsMountPoint;
    }

    if (not $mountPoint or ($mountPoint eq '/')) {
        my @parts = split '/+', $target;
        if (($parts[1] eq 'media') or ($parts[1] eq 'mnt')) {
            $mountPoint = '/' . $parts[1] . '/' . $parts[2];
        } else {
            # no mount point, so we don't check if it is  mounted
            return;
        }
    }

    # check if the mount poitn is mounted
    if (EBox::FileSystem::mountPointIsMounted($mountPoint)) {
        return;
    } else {
        # no mounted
        if ($mountPoint eq $target) {
            throw EBox::Exceptions::EBackup::TargetNotReady(
                __x('{target} is not mounted',
                    target => $target
                   )
               );
        } else {
            throw EBox::Exceptions::EBackup::TargetNotReady(
                __x('{mp} is not mounted and {target} is inside it',
                    mp => $mountPoint,
                    target => $target
                   )
               );
        }
    }
}

sub _estimateBackupSize
{
    my ($self, $type) = @_;
    my $sql = 'select size from ebackup_stats' .
               " where type='$type'" .
               ' order by timestamp desc limit 5';
    my $db = EBox::DBEngineFactory::DBEngine();
    my $results = $db->query($sql);
    my @lasts = map {
        $_->{size}
    } @{ $results };

    if (not @lasts) {
        EBox::debug("Cannot estimate backup size because we have not backup statistics yet for type: $type");
        return 0;
    }
    my $average =0;
    $average += $_ foreach @lasts;
    $average /= scalar @lasts;
    if ($average <= 0) {
        EBox::debug("Estimation error. Bad average: $average.");
        return 0;
    }
    # to MB
    $average /= 1024*1024;
    # add 20% to have some room
    $average *= 1.2;
    EBox::debug("Estimated backup size: $average");
    return $average;
}

## Report methods

# Method: gatherReportInfo
#
#  This method should be called after each backup to gather information for the
#  report; for this module this method is used instead of the usual reportInfo
#
# Parameters:
#
#  type - String the data backup done
#         Possible values: 'full' or 'incremental'
#
#  backupStats - Hash ref containing the stats from the backup if it
#                was successful
#
#                time - Int the elapsed time
#                nFiles - Int the number of files in the target to
#                         back up
#                nNew     - Int the number of new files
#                nDeleted - Int the number of deleted files
#                nChanged - Int the number of changed files
#                size     - Int the size of the backup in bytes
#                nErrors  - Int the number of errors in the backup
#
sub gatherReportInfo
{
    my ($self, $type, $backupStats) = @_;

    if (not $self->configurationIsComplete()) {
        return;
    }

    my $usage = $self->storageUsage();
    if (not defined $usage) {
        return;
    }

    my $values = {
                  used => $usage->{used},
                  available => $usage->{available}
                 };

    my $stats = {};

    if (defined ($backupStats)) {
        $stats = {
            elapsed           => sprintf("%.0f", $backupStats->{time}),
            files_num         => $backupStats->{nFiles},
            new_files_num     => $backupStats->{nNew},
            del_files_num     => $backupStats->{nDeleted},
            changed_files_num => $backupStats->{nChanged},
            size              => $backupStats->{size},
            errors            => $backupStats->{nErrors},
            type              => $type,
        };
    }

    my $db = EBox::DBEngineFactory::DBEngine();
    my @time = localtime(time);
    my ($year, $month, $day) = ($time[5] + 1900, $time[4] + 1, $time[3]);
    my ($hour, $min, $sec) = ($time[2], $time[1], $time[0]);
    my $date = "$year-$month-$day $hour:$min:$sec";

    my @reportInfo = (
                      {
                       table  => 'ebackup_storage_usage',
                       values => $values,
                       insert => 1,
                      },
                      {
                       table  => 'ebackup_stats',
                       values => $stats,
                       insert => defined($backupStats),
                      },
                     );

    for my $i (@reportInfo) {
        $i->{'values'}->{'timestamp'} = $date;
        if ( $i->{'insert'} ) {
            $db->insert($i->{'table'}, $i->{'values'});
        }
    }

    # Perform the buffered inserts done above
    $db->multiInsert();
}

1;
