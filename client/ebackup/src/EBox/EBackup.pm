# Copyright (C) 2008-2009 eBox Technologies S.L.
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
use File::Slurp;

use String::ShellQuote;
use Date::Parse;
use Error qw(:try);
use Fcntl qw(:flock);

use EBox::Exceptions::MissingArgument;

use constant EBACKUP_CONF_FILE => EBox::Config::etc() . '82ebackup.conf';
use constant EBACKUP_MENU_ENTRY => 'ebackup_menu_enabled';
use constant DUPLICITY_WRAPPER => EBox::Config::share() . '/ebox-ebackup/ebox-duplicity-wrapper';
use constant DUPLICITY_PASSWORD =>  EBox::Config::conf . '/ebox-ebackup.password';
use constant DUPLICITY_SYMMETRIC_PASSWORD =>  EBox::Config::conf . '/ebox-ebackup-symmetric.password';
use constant LOCK_FILE     => EBox::Config::tmp() . 'ebox-ebackup-lock';
use constant EBACKUP_EBOX_FINGERPRINT_FILE => EBox::Config::share() . '/ebox-ebackup/server-fingerprints';

my %servers = (
    'ebox_eu' => 'ch-s010.rsync.net',
    'ebox_us_denver' => 'usw-s008.rsync.net',
    'ebox_us_w' => 'usw-s004.rsync.net',
);


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
#
sub restoreFile
{
    my ($self, $file, $date, $destination) = @_;

    unless (defined($file)) {
        throw EBox::Exceptions::MissingArgument('file');
    }

    unless (defined($date)) {
        throw EBox::Exceptions::MissingArgument('date');
    }

    $destination or
        $destination = $file;


    my $time = Date::Parse::str2time($date);

    my $model = $self->model('RemoteSettings');
    my $url = $self->_remoteUrl();
    my $rFile = $file;
    $rFile =~ s:^.::;

    my $cmd = DUPLICITY_WRAPPER .  " --force -t $time --file-to-restore $rFile $url $destination";

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
            ex->throw();
        }
            
    };
}


# Method: remoteArguments
#
#   Return the arguments to be used by duplicty
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
    my ($self, $type) = @_;

    my $volSize = $self->_volSize();
    my $fileArgs = $self->remoteFileSelectionArguments();
    my $cmd =  DUPLICITY_WRAPPER .  " $type " . 
            "--volsize $volSize " .
            "$fileArgs " .
            " / " . $self->_remoteUrl();
    return $cmd;
}


sub extraDataDir
{
    return EBox::Config::home() . 'extra-backup-data';
}

sub dumpExtraData
{
    my ($self) = @_;

    my $extraDataDir = $self->extraDataDir();
    system "rm -rf $extraDataDir";
    system "mkdir -p $extraDataDir";
    if (not -w $extraDataDir) {
        EBox::error("Cannot write in extra backup data directory $extraDataDir");
        return;
    }

    my $global = EBox::Global->getInstance();
    
    # Backup configuration
    my $bakCmd = EBox::Config::pkgdata() .
        '/ebox-make-backup --destination confbackup.tar';
    
    try {
        EBox::Sudo::root($bakCmd);
        # XXX Some modules such as events are marked as changed after
        #     running ebox-make-backup.
        #     This is a temporary workaround
        $global->revokeAllModules();
        my $bakFile = EBox::Backup::backupDir() . '/confbackup.tar';
        system "mv $bakFile $extraDataDir";
    } otherwise {
        EBox::debug("ebox-make-backup failed");
    };


    foreach my $mod (@{ $global->modInstances() }) {
        if ($mod->can('dumpExtraBackupData')) {
            my $dir = $extraDataDir . '/' . $mod->name();
            mkdir $dir;
            $mod->dumpExtraBackupData($dir);
        }
    }

}


sub remoteFileSelectionArguments
{
    my ($self) = @_;

    my $model = $self->model('RemoteExcludes');
    my $args = '';
    # Include configuration backup
    $args .= ' --include=' . $self->extraDataDir . ' ';

    $args .= $self->_autoExcludesArguments();

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

    # exclude backup directory if we are using 'filesystem' mode
    my $settings = $self->model('RemoteSettings');
    my $row = $settings->row();
    if ($row->valueByName('method') ne 'file') {
        return '';
    }

    my $dir = $row->valueByName('target');
    return  "--exclude=$dir ";
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
    my ($self, $type) = @_;

    my $model = $self->model('RemoteSettings');
    my $removeArgs = $model->removeArguments();

    return DUPLICITY_WRAPPER . " $removeArgs --force " . $self->_remoteUrl();
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
    my ($self, $type) = @_;

    my $model = $self->model('RemoteSettings');

    return DUPLICITY_WRAPPER . " list-current-files " . $self->_remoteUrl();
}

#  Method: remoteGenerateListFile
#
#  Warning: it will raise exception if there isnt at least one backup yet
sub remoteGenerateListFile
{
    my ($self) = @_;
    my $collection = $self->remoteListFileArguments();
    my $tmpFile = $self->tmpFileList();
    EBox::Sudo::root("$collection > $tmpFile");
    EBox::Sudo::root("chown ebox:ebox $tmpFile");
}


# Method: remoteStatus
#
#  Return the status of the remote backup.
#  Cached for 1000 seconds.
#
# Returns:
#
#  Array ref of hash refs containing:
#
#  type - full or incremental backup
#  date - backup date
sub remoteStatus
{
    my ($self) = @_;

    my @status;
    if (-f tmpCurrentStatus()) {
        my @lines = File::Slurp::read_file(tmpCurrentStatus());
        for my $line (@lines) {
            # We are trying to match this:
            #  Full Wed Sep 23 13:30:56 2009 95
            #  Incr Fri Sep 23 13:30:56 2009 95
            my $regexp = '^\s+(\w+)\s+(\w+\s+\w+\s+\d\d? '
                    . '\d\d:\d\d:\d\d \d{4})\s+\d+';
            if ($line =~ /$regexp/ ) {
                push (@status, {
                        type => $1,
                        date => $2 }
                     );
            }
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
#   from a crontab script
#
sub remoteGenerateStatusCache
{
    my ($self) = @_;

    my $file = tmpCurrentStatus();
    my $remoteUrl = $self->_remoteUrl();
    my $cmd = DUPLICITY_WRAPPER . " collection-status $remoteUrl";
    my $status = undef;
    try {
        $status =  EBox::Sudo::root($cmd);

    } otherwise {};

    if (defined $status) {
        File::Slurp::write_file($file, $status);
    } else {
        ( -e $file) and
            unlink $file;
    }
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

# Method: setRemoteBackupCrontab
#
#   configure crontab according to user configuration
#   to call our backup script
#
sub setRemoteBackupCrontab
{
    my ($self) = @_;

    my @lines;
    my $strings = $self->model('RemoteSettings')->crontabStrings();

    my $script = EBox::Config::share() . 'ebox-ebackup/ebox-remote-ebackup';
    foreach my $full (@{ $strings->{full} }) {
        push (@lines, "$full $script --full");
    }


    my $incrList = $strings->{incremental};
    if ($incrList) {
        foreach my $incr (@{ $incrList }) {
            push (@lines, "$incr $script --incremental");
        }
    }
    
    my $tmpFile = EBox::Config::tmp() . 'crontab';
    open(my $tmp, '>' .  EBox::Config::tmp() . 'crontab');
    if ($self->isEnabled()) {
        for my $line (@lines) {
            print $tmp "$line\n";
        }
    }
    close($tmp);
    EBox::Sudo::command("crontab $tmpFile");
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
    # Store password
    my $model = $self->model('RemoteSettings');
    my $pass = $model->row()->valueByName('password');
    $pass = '' unless (defined($pass));
    my $symPass = $model->row->valueByName('encryption');
    $symPass = '' unless (defined($symPass));
    EBox::Module::Base::writeFile(
            DUPLICITY_PASSWORD,
            $pass, { uid => 'ebox', gid => 'ebox', mode => '0600'}
    );
    EBox::Module::Base::writeFile(
            DUPLICITY_SYMMETRIC_PASSWORD,
            $symPass, { uid => 'ebox', gid => 'ebox', mode => '0600'}
    );
    $self->setRemoteBackupCrontab();

    $self->_syncRemoteCaches();

}


sub _syncRemoteCaches
{
    my ($self) = @_;

    my @oldRemoteStatus = @{ $self->remoteStatus() };
    $self->remoteGenerateStatusCache();
    my @newRemoteStatus = @{ $self->remoteStatus() };
    
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

sub _remoteUrl
{
    my ($self) = @_;

    my $user;

    my $model = $self->model('RemoteSettings');
    my $method = $model->row()->valueByName('method');
    my $origMethod = $method;
    my $target = $model->row()->valueByName('target');
    if ($method =~ /^ebox/) {
        if (defined($target)) {
            $target = "$servers{$method}/$target";
        } else {
            $target = "$servers{$method}";
        }
        $method = 'scp';
    }
    my $url = "$method://";
    if ($method ne 'file') {
        $user = $model->row()->valueByName('user');
        if ($user) {
            $url .= "$user@";
        }
    }

    $url .= $target if defined($target);

    if ($method eq 'scp') {
        $url .= ' --ssh-askpass';
    }

    if ($origMethod =~ /^ebox/) {
        $url .= ' --ssh-options="-oUserKnownHostsFile='
            . EBACKUP_EBOX_FINGERPRINT_FILE . '"';
    }

    my $encryption = $model->row()->elementByName('encryption');
    my $encValue = $encryption->value();
    my $encSelected = $encryption->selectedType();
    if ($encValue eq 'disabled') {
        $url .= ' --no-encryption';
    } else {
        if ($encSelected eq 'asymmetric') {
            $url .= " --encrypt-key $encValue";
        }
    }

    return $url;
}

sub _volSize
{

    my $volSize = EBox::Config::configkeyFromFile('volume_size',
                                                  EBACKUP_CONF_FILE);
    if (not $volSize) {
        $volSize = 600;
    }
    return $volSize;
}


1;
