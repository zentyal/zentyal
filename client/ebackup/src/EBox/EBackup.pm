# Copyright (C) 2009-2010 eBox Technologies S.L.
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


package EBox::EBackup;

# Class: EBox::EBackup
#
#

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider);

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Backup;
use EBox::Sudo;
use EBox::Logs::SlicedBackup;
use File::Slurp;
use EBox::FileSystem;
use Filesys::Df;
use EBox::DBEngineFactory;
use EBox::EBackup::Subscribed;
use EBox::EBackup::Password;

use String::ShellQuote;
use Date::Parse;
use Error qw(:try);
use Fcntl qw(:flock);

use EBox::Exceptions::MissingArgument;

use constant EBACKUP_CONF_FILE => EBox::Config::etc() . '82ebackup.conf';
use constant EBACKUP_MENU_ENTRY => 'ebackup_menu_enabled';
use constant DUPLICITY_WRAPPER => EBox::Config::share() . '/ebox-ebackup/ebox-duplicity-wrapper';
use constant LOCK_FILE     => EBox::Config::tmp() . 'ebox-ebackup-lock';




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
            printableName => __n('Backup'),
            domain => 'ebox-ebackup',
            @_);

    bless($self, $class);
    return $self;
}


# Method: modelClasses
#
# Overrides:
#
#      <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::EBackup::Model::RemoteSettings',
        'EBox::EBackup::Model::RemoteExcludes',
        'EBox::EBackup::Model::RemoteStatus',
        'EBox::EBackup::Model::RemoteFileList',
        'EBox::EBackup::Model::RemoteRestoreLogs',
        'EBox::EBackup::Model::RemoteRestoreConf',
        'EBox::EBackup::Model::RemoteStorage',
        'EBox::EBackup::Model::BackupDomains',
    ];
}


# Method: compositeClasses
#
# Overrides:
#
#      <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::EBackup::Composite::RemoteGeneral',
        'EBox::EBackup::Composite::Remote',
        'EBox::EBackup::Composite::ServicesRestore',
    ];
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

    unless (defined($file)) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    unless (defined($date)) {
        throw EBox::Exceptions::MissingArgument('date');
    }

    $destination or
        $destination = $file;

    my $rFile;
    if ($file eq '/') {
        $rFile = undef;
    } else {
        $rFile = $file;
        $rFile =~ s:^/::; # file must be relative

        # shell quote does not work well for espaces with duplicity...
        $rFile =~ s:\ :\\\ :g;
        $rFile = shell_quote($rFile);
    }

    # shell quote does not work well for espaces with duplicity...
    $destination =~ s:\ :\\\ :g;
    $destination = shell_quote($destination);

    my $time = Date::Parse::str2time($date);

    my $model = $self->model('RemoteSettings');
    my $url = $self->_remoteUrl(%{ $urlParams });

    my $cmd = DUPLICITY_WRAPPER .  " --force -t $time ";
    if ($rFile) {
        $cmd .= "--file-to-restore $rFile ";
    }
    $cmd .= " $url $destination";

    try {
        EBox::Sudo::root($cmd);
    } catch EBox::Exceptions::Sudo::Command with {
        my $ex = shift;
        my $error = join "\n", @{  $ex->error() };
        if ($error =~ m/not found in archive, no files restored/) {
            throw EBox::Exceptions::External(
                __x(
                    'File {f} not found in backup for {d}, try a later date',
                    f => $file,
                    d => $date,
                   )
               );
        } elsif ($error =~ m/No backup chains found/) {
            throw EBox::Exceptions::External(
                __(q{No backup archives found. Maybe they were deleted?.} .
                     q{ Run '/etc/init.d/ebox ebackup restart' to refresh backup's information.}
                    )
               );
        } else {
            $ex->throw();
        }
    };
}


# Method: lastBackupDate
#
#  Returns:
#   string with the date of the last backup made, undef if there are not backups
#
#  Warning:
#    the information is getted from the cache, remember you could call
#    _syncRemoteCaches to refresh the cache
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

sub dumpExtraData
{
    my ($self, $readOnlyGlobal) = @_;

    my $extraDataDir = $self->extraDataDir();
    system "rm -rf $extraDataDir";
    system "mkdir -p $extraDataDir";
    if (not -w $extraDataDir) {
        EBox::error("Cannot write in extra backup data directory $extraDataDir");
        return;
    }
    my $global = EBox::Global->getInstance($readOnlyGlobal);

    # create backup domain files
    my @enabledBackupDomains = keys %{ $self->_enabledBackupDomains()  };
    File::Slurp::write_file($self->enabledDomainsListPath(),
                            join ',', @enabledBackupDomains);

    try {
        my $filename = 'confbackup.tar';
        my $bakFile = EBox::Backup->backupDir() . "/$filename";
        EBox::Backup->makeBackup(
                                 description => 'Configuration backup',
                                 destination => $filename,
                                );
        # XXX Some modules such as events are marked as changed after
        #     running ebox-make-backup.
        #     This is a temporary workaround
        $global->revokeAllModules();
        system "mv $bakFile $extraDataDir";
    } otherwise {
        my $ex = shift;
        EBox::error("Configuration backup failed: $ex. It will not be possible to restore the configuration from this backup, but the data will be backed up.");
    };

    my %enabled;
    if ($self->_fullMachineBackup()) {
        %enabled = (full => 1);
    } else {
        %enabled  = %{ $self->_enabledBackupDomains() };
    }

    foreach my $mod (@{ $global->modInstances() }) {
        if ($mod->can('dumpExtraBackupData')) {
            my $dir = $extraDataDir . '/' . $mod->name();
            mkdir $dir; # this directory could be empty if th next call doesnot
                        # put any file on it
            $mod->dumpExtraBackupData($dir, %enabled);
        }
    }
}

sub enabledDomainsListPath
{
    my ($self) = @_;
    my $path = $self->extraDataDir() .  '/enabled-domains.csv';
    return $path;
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

# Method: availableBackupDomains
#
# Parameters: modNames - names of modules to look for backup domains (Default:
# all installed modules)
#
# Returns:
#
#    hash reference whose backup domain name as key and backup
#      domain attributes as values
sub availableBackupDomains
{
    my ($self, $modNames) = @_;
    my %backupDomains = ();

    my $global = EBox::Global->getInstance();
    if (not defined $modNames) {
        $modNames = $global->modNames();
    }

    foreach my $name (@{ $modNames }) {
        my $mod = $global->modInstance($name);
        # the mod shouldnt to exist when we supply a list of modules
        defined $mod or
            next;
        if ($mod->isa('EBox::Module::Service')) {
            $mod->configured() or
                next;
        }

        if ($mod->can('backupDomains')) {
            my @modBackupDomains = $mod->backupDomains();
            while (my ($name, $attrs) = splice( @modBackupDomains, 0, 2)) {
                $backupDomains{$name} = $attrs;
                $backupDomains{$name}->{enabled} = $mod->configured();
            }

            # the same domain can be provided by different modules this is
            # intentional to allow than more of one module for each backup
            # domain  but assure that their $attr valeus are identical or you can
            # run into trouble
        }
    }

    # special filesIncludes ebackup domain
    $backupDomains{filesIncludes} = {
        enabled => 1,
        printableName => __('Other files'),
        description   => __(q{Extra data manually included in the backup}),
    };

    return \%backupDomains;
}

sub selectableBackupDomains
{
    my ($self, $modNames) = @_;
    my $backupDomains = $self->availableBackupDomains($modNames);

    # remove non-selectable domains
    delete $backupDomains->{filesIncludes};

    return $backupDomains;
}

sub _enabledBackupDomains
{
    my ($self, $filesIncludesDomain) = @_;
    defined $filesIncludesDomain or
        $filesIncludesDomain = 1;

    if ($self->_fullMachineBackup()) {
        # we add logs, otherwise it would be required to stop the postgre
        # database to have a correct backup
        return { full => 1, logs => 1};
    }

    my $domainsModel = $self->model('BackupDomains');
    my $enabled =  $domainsModel->enabled();

    if ($filesIncludesDomain) {
        my $excludesModel =$self->model('RemoteExcludes');
        $enabled->{filesIncludes} = $excludesModel->hasIncludes();
    }

    return $enabled;
}


sub _fullMachineBackup
{
    # XXX TODO
    return 0;
}


sub backupDomainsFileSelectionsRowPrefix
{
    return 'ds';
}

# Method: modulesBackupDomainsFileSelections
#
#  Returns:
#   list with all file selections for the enabled backup domains in the system
sub modulesBackupDomainsFileSelections
{
    my ($self) = @_;

    my %enabled = %{ $self->_enabledBackupDomains(0) };
    if (not keys %enabled) {
        return [];
    }

    my $mods = EBox::Global->getInstance()->modInstances();
    my @domainSelections = ();
    foreach my $mod (@{ $mods }) {
        if ($mod->can('backupDomainsFileSelection')) {
            my $bds = $mod->backupDomainsFileSelection(%enabled);
            $bds->{mod} = $mod->{name};
            push @domainSelections, $bds;
        }
    }

    @domainSelections = sort {
                       my $pA = exists $a->{priority} ?
                                       $a->{priority} : 1;
                       my $pB = exists $b->{priority} ?
                                       $b->{priority} : 1;
                       $pA <=> $pB
                     } @domainSelections ;


    my $prefix = $self->backupDomainsFileSelectionsRowPrefix();
    my @selections;
    foreach my $ds (@domainSelections) {
        foreach my $type (qw(exclude exclude-regexp include)) {
            my $typeList = $type . 's';
            if ($ds->{$typeList}) {
                foreach my $value (@{ $ds->{$typeList} }) {
                        my $escapedValue = $value;
                        $escapedValue =~ s{/}{R}g;
                        my $id =  $prefix .  '_' .
                            $ds->{mod} . '_' . $type . '_' .$escapedValue;
                        push @selections, {
                                           id   => $id,
                                           type => $type,
                                           value => $value };
                }
            }
        }
    }

    return \@selections;
}


sub _backupDomainsFileSelectionArguments
{
    my ($self) = @_;

    my @selections = @{ $self->modulesBackupDomainsFileSelections };

    my $args = '';
    foreach my $selection (@selections) {
        $args .= '--' . $selection->{type} . ' ' . $selection->{value} . ' ';
    }

    return $args;
}



sub _fullMachineBackupSelectionArguments
{
    my ($self) = @_;

    # here we only excldue things that has no sense in any scenario

    my $args = $self->_autoExcludesArguments();

    # temp directories
    $args .= ' --exclude=/tmp ';

    # special directories
    $args .= ' --exclude=/dev ';
    $args .= ' --exclude=/proc ';
    $args .= ' --exclude=/sys ';
    $args .= ' --exclude=**/lost+found';

    # use (--delete excluded) ? It seems that some devices
    # are not automatically created under /dev

    # Include
    # + /dev/console
    # + /dev/initctl
    # + /dev/null
    # + /dev/zero

    # external devices directory
    $args .= ' --exclude=/media ';

    return $args;
}

sub remoteFileSelectionArguments
{
    my ($self) = @_;

    if ($self->_fullMachineBackup()) {
        return $self->_fullMachineBackupSelectionArguments();
    }

    my $args = '';
    # Include configuration backup
    $args .= ' --include=' . $self->extraDataDir . ' ';

    $args .= $self->_autoExcludesArguments();

    # high level selection arguments
    $args .= $self->_backupDomainsFileSelectionArguments();

    my $model = $self->model('RemoteExcludes');
    for my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $type = $row->valueByName('type');
        if ($type eq 'exclude_path') {
            my $path = shell_quote($row->valueByName('target'));
            $args .= "--exclude=$path ";
        } elsif ($type eq 'include_path') {
            my $path = shell_quote($row->valueByName('target'));
            if ($path eq '/') {
                EBox::warn(
  q{Not neccesary to include '/' directory in ebakcup. Ignoring}
                   );
                next;
            }
            $args .= "--include=$path ";
        } elsif ($type eq 'exclude_regexp') {
            my $regexp = shell_quote($row->valueByName('target'));
            $args .= "--exclude-regexp $regexp " ;
        }
    }

    return $args;
}

sub _autoExcludesArguments
{
    my ($self) = @_;

    my $args = '';
    # directories excluded to avoid risk of
    # duplicity crash_remoteUrl
    $args .= "--exclude=/proc --exclude=/sys ";

    # exclude sliced backups directory
    my $slicesDir = EBox::Logs::SlicedBackup::archiveDir();
    if ($slicesDir) {
        $args .= "--exclude $slicesDir ";
    }

    # exclude backup directory if we are using 'filesystem' mode
    my $settings = $self->model('RemoteSettings');
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

    my $model = $self->model('RemoteSettings');
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

    my $model = $self->model('RemoteSettings');

    return DUPLICITY_WRAPPER . ' list-current-files ' .
             $self->_remoteUrl(%{ $urlParams });
}

#  Method: remoteGenerateListFile
#
#  Warning: it will raise exception if there isnt at least one backup yet
sub remoteGenerateListFile
{
    my ($self) = @_;
    my $collectionCmd = $self->remoteListFileArguments();
    my $tmpFile = $self->tmpFileList();

    my $success = 0;
    try {
        EBox::Sudo::root("$collectionCmd > $tmpFile");
        $success = 1;
    } catch EBox::Exceptions::Sudo::Command with {
        my $ex = shift;
        my $error = join "\n", @{ $ex->error() };
        if ($error =~ m/No signature chains found/) {
            $success = 0;
        } else {
            $ex->throw();
        }
    };

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

    my @status;
    my @lines;
    if ($noCacheUrl) {
        my $status = $self->_retrieveRemoteStatus($noCacheUrl);
        if (not $status) {
            throw EBox::Exceptions::External(
                                             __('Could not get backup collection status, check whether the parameters and passwords are correct')
                                            );
        }

        @lines = @{ $status  };
    } else {
        if (-f tmpCurrentStatus()) {
            @lines = File::Slurp::read_file(tmpCurrentStatus());
        }
    }

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

# Method: remoteGenerateStatusCache
#
#   Generate a current status cache. This is to be called
#   from a crontab script or restarting the module
#
sub remoteGenerateStatusCache
{

    my ($self, $urlParams) = @_;
    $self->_clearStorageUsageCache();

    my $file = tmpCurrentStatus();
    my $status = $self->_retrieveRemoteStatus($urlParams);

    if (defined $status) {
        File::Slurp::write_file($file, $status);
    } else {
        ( -e $file) and
            unlink $file;
    }
}

sub _retrieveRemoteStatus
{
    my ($self, $urlParams) = @_;
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
    } catch EBox::Exceptions::Sudo::Command with {
        my $ex = shift;
        my $error = join "\n", @{  $ex->error() };
        if ($error =~ m/No signature chains found/) {
            $status = '';
        }
    };

    return $status;
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

    unless ($self->{files}) {
    my @files;
    for my $line (File::Slurp::read_file($file)) {
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

# Method: setRemoteBackupCron
#
#   configure crontab according to user configuration
#   to call our backup script
#
sub setRemoteBackupCron
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('RemoteSettings')->crontabStrings();

    my $script = EBox::Config::share() . 'ebox-ebackup/ebox-remote-ebackup';

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


sub removeRemoteBackupCron
{
    my $rmCmd = "rm -f " . backupCronFile();
    EBox::Sudo::root($rmCmd);
}


sub backupCronFile
{
    return '/etc/cron.d/ebox-ebackup';
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
        $self->removeRemoteBackupCron();
        return;
    }

    # Store password
    my $model = $self->model('RemoteSettings');
    my $pass = '';
    if (not $self->EBox::EBackup::Subscribed::isSubscribed()) {
        $pass = $model->row()->valueByName('password');
        defined $pass or
            $pass = '';
    } else {
        my $credentials = EBox::EBackup::Subscribed::credentials();
        $pass = $credentials->{password};
    }
    EBox::EBackup::Password::setPasswdFile($pass);

    my $symPass = $model->row->valueByName('encryption');
    $self->$symPass = '' unless (defined($symPass));
    EBox::EBackup::Password::setSymmetricPassword($symPass);

    if ($self->isEnabled()) {
        $self->setRemoteBackupCron();
    } else {
        $self->removeRemoteBackupCron();
    }

    if ( $model->row()->valueByName('method') eq 'cloud' ) {
        EBox::EBackup::Subscribed::createStructure();
    }

    $self->_syncRemoteCaches();
}


# this calls to remoteGenerateStatusCache and if there was change it regenerates
# also the files list

sub _syncRemoteCaches
{
    my ($self) = @_;

    my @oldRemoteStatus = @{ $self->remoteStatus() };
    $self->remoteGenerateStatusCache();
    my @newRemoteStatus = @{ $self->remoteStatus() };

    if ($self->configurationIsComplete()) {
        return;
    }

    my $genListFiles = 0;
    if (@newRemoteStatus == 0) {
        # no files, clear fileList archive if it exists
        my $fileList = tmpFileList();
        (-e $fileList) and
            unlink $fileList;

        # no needed to make any file list, bz there aren't files
        $genListFiles = 0;
    } elsif (@oldRemoteStatus != @newRemoteStatus) {
        $genListFiles =1;
    } else {
        while (@oldRemoteStatus) {
            my $old = shift @oldRemoteStatus;
            my $new = shift @newRemoteStatus;
            foreach my $attr (keys %{ $new }) {
                if ((not exists $old->{$attr}) or
                    ($old->{$attr} ne $new->{$attr})
                   ) {
                    $genListFiles = 1;
                    last;
                }
            }
        }
    }

    if ($genListFiles) {
        $self->remoteGenerateListFile();
    }
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

    my $enabledMenu = EBox::Config::configkeyFromFile(EBACKUP_MENU_ENTRY,
                                                      EBACKUP_CONF_FILE);
    if (defined($enabledMenu) and ($enabledMenu eq 'yes' )) {
        $root->add(new EBox::Menu::Item(
            'url' => 'EBackup/Composite/Remote',
            'separator' => 'Core',
            'order' => 95,
            'text' => $self->printableName()));
    }
}

# Method: lock
#
#      Lock backup process to avoid overlapping of two processes
#
#
sub lock
{
    my ($self) = @_;

    open( $self->{lock}, '>', LOCK_FILE);
    my $ret = flock( $self->{lock}, LOCK_EX | LOCK_NB );
    return $ret;
}

# Method: unlock
#
#      Unlock backup process to avoid overlapping of two processes
#
#
sub unlock
{
    my ($self) = @_;

    flock( $self->{lock}, LOCK_UN );
    close($self->{lock});
}

# XXX TODO: refactor parameters from model and/or subscription its own method
sub _remoteUrl
{
    my ($self, %forceParams) = @_;

    my ($method, $user, $target);
    my ($encSelected, $encValue);
    my $model = $self->model('RemoteSettings');

    my $subscribed = EBox::EBackup::Subscribed::isSubscribed();
    my $sshKnownHosts = 0;

    if (%forceParams) {
        foreach my $param (qw(method user target password)) {
            $forceParams{$param} or
                throw EBox::Exceptions::MissingArgument($param);
        }

        $forceParams{encValue} or
            $forceParams{encValue} = 'disabled';

        $method= $forceParams{method};
        $user = $forceParams{user};
        $target = $forceParams{target};
        my $passwd = $forceParams{password};
        EBox::EBackup::Password::setPasswdFile($passwd, 1);
        $encSelected = $forceParams{encSelected};
        $encValue = $forceParams{encValue};
        $sshKnownHosts = ($method eq 'scp');

    }  else {
        $method = $model->row()->valueByName('method');
        if ($method eq 'cloud')  {
            if (not $subscribed) {
                throw EBox::Exceptions::External(
__('You need to have the disaster recovery add-on to use this backup method')
                                                );
            }

            my $credentials = EBox::EBackup::Subscribed::credentials();
            if (not $credentials) {
                throw EBox::Exceptions::External(
                                                 __('Could not retrieve backup credentials, check your conexion to Zentyal Cloud')
                                                );
            }

            $sshKnownHosts = 1;
            $method = $credentials->{method};
            $target = $credentials->{target};
            $user = $credentials->{username};
            my $passwd = $credentials->{password};
            EBox::EBackup::Password::setPasswdFile($passwd);

        } else {
            # no cloud method!
            $target = $model->row()->valueByName('target');

            if ($method ne 'file') {
                $user = $model->row()->valueByName('user');
            }
        }
    }

    my $url = "$method://";
    if ($user) {
        $url .= "$user@";
    }
    $url .= $target if defined($target);

    if ($method eq 'scp') {
        $url .= ' --ssh-askpass';
    }

    if ($sshKnownHosts) {
        $url .= ' --ssh-options="-oUserKnownHostsFile='
            . EBox::EBackup::Subscribed::FINGERPRINT_FILE . '"';
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


sub canUnsubscribeFromCloud
{
    my ($self) = @_;
    my $model = $self->model('RemoteSettings');
    my $method = $model->row()->valueByName('method');
    if ($method eq 'cloud') {
        throw EBox::Exceptions::External(
__x('Could not unsubscribe because the backup module is configured to use the Zentyal Cloud. If you want to unsubscribe, you must change this {ohref}setting{chref}.',
    ohref => q{<a href='/ebox/EBackup/Composite/Remote#RemoteGeneralSettings'>},
    chref => '</a>'
  )
                                        );
    }
}

sub configurationIsComplete
{
    my ($self) = @_;

    if (EBox::EBackup::Subscribed::isSubscribed()) {
        return 1;
    }

    my $model = $self->model('RemoteSettings');
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

## Report methods

# Method: storageUsage
#
#   get the available and used space in the storage place used to save the
#   backup collection
#
#  Returns:
#    hash ref with the keys:
#              - used: space used in Mb
#              - available: space available in Mb
#              - total: in Mb
#
# Warning:
# the results cache will fail if more space is taken or free without using
# ebox-remote-ebackup, this will be very possible with file storage
sub storageUsage
{
    my ($self) = @_;
    if (not $self->configurationIsComplete()) {
        return undef;
    }

    my $file = _storageUsageCacheFile();
    if (-f $file) {
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
            $self->_clearStorageUsageCache();
        }
    }

    my ($total, $used, $available);

    my $model  = $self->model('RemoteSettings');
    my $method = $model->row()->valueByName('method');
    my $target = $model->row()->valueByName('target');

    if ($method eq 'cloud') {
        my $quota;
        ($used, $quota) = EBox::EBackup::Subscribed::quota();
        $total = $quota;
        $available = $quota - $used;
    } elsif ($method eq 'file') {
        my $blockSize = 1024*1024; # 1024*1024 - 1Mb blocks
        my $df = df($target, $blockSize);
        $available = $df->{bfree};
        $total     = $df->{blocks};
        $used = $total - $available;
    }

    # XXX TODO SCP, FTP

    if (not defined $used) {
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


sub consolidateReportInfoQueries
{
    return [
        {
            'target_table' => 'ebackup_storage_usage_report',
            'query' => {
                'select' => 'used, available',
                'from' => 'ebackup_storage_usage',
            },
        }
    ];
}

# Method: report
#
# Overrides:
#   <EBox::Module::Base::report>
sub report
{
    my ($self, $beg, $end, $options) = @_;
    if (not $self->configurationIsComplete()) {
        return {};
    }

    my $report = {};
    $report->{included} = $self->model('BackupDomains')->report();
    $report->{settings} = $self->model('RemoteSettings')->report();
    $report->{'storage_usage'} = $self->runMonthlyQuery($beg, $end, {
        'select' => 'used, available',
        'from' => 'ebackup_storage_usage_report',
    });

    return $report;
}

1;
