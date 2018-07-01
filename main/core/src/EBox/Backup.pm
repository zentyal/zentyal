# Copyright (C) 2004-2007 Warp Networks S.L.
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

package EBox::Backup;

use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::FileSystem;
use EBox::ProgressIndicator;
use EBox::Util::FileSize;

use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use File::Slurp qw(read_file write_file);
use File::Basename;
use File::MMagic;

use TryCatch;
use Digest::MD5;
use EBox::Sudo;
use POSIX qw(strftime);
use DirHandle;
use Perl6::Junction qw(any all);


use Filesys::Df;

use Readonly;
Readonly::Scalar our $FULL_BACKUP_ID  => 'full backup';
Readonly::Scalar our $CONFIGURATION_BACKUP_ID  =>'configuration backup';
Readonly::Scalar our $BUGREPORT_BACKUP_ID  =>'bugreport configuration dump';
my $RECURSIVE_DEPENDENCY_THRESHOLD = 20;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# returns:
#       string: path to the backup file.
sub _makeBackup
{
    my ($self, %options) = @_;

    my $description = delete $options{description};
    my $time        = delete $options{time};

    my $bug         = $options{bug};
    my $progress   = $options{progress};
    my $changesSaved = $options{changesSaved};

    my $date = strftime("%F %T", localtime($time));

    my $confdir = EBox::Config::conf;
    my $tempdir = tempdir("$confdir/backup.XXXXXX") or
        throw EBox::Exceptions::Internal("Could not create tempdir.");
    EBox::Sudo::command("chmod 0700 $tempdir");

    my $auxDir = "$tempdir/aux";
    my $archiveContentsDirRelative = "eboxbackup";
    my $archiveContentsDir = "$tempdir/$archiveContentsDirRelative";
    my $backupArchive = "$confdir/eboxbackup.tar";

    try {
        mkdir($auxDir, 0700) or
            throw EBox::Exceptions::Internal("Could not create auxiliar tempdir.");
        mkdir($archiveContentsDir, 0700) or
            throw EBox::Exceptions::Internal("Could not create archive tempdir.");

        $self->_dumpModulesBackupData($auxDir, %options);

        if ($bug) {
            $self->_bug($auxDir);
        }

        if ($progress) {
            $progress->setMessage(__('Creating backup archive'));
            $progress->notifyTick();
        }

        my $filesArchive  = "$archiveContentsDir/files.tgz";
        $self->_createFilesArchive($auxDir, $filesArchive);
        $self->_createZentyalConfFilesArchive($archiveContentsDir);
        $self->_createMd5DigestForArchive($filesArchive, $archiveContentsDir);
        $self->_createDescriptionFile($archiveContentsDir, $description);
        $self->_createDateFile($archiveContentsDir, $date);
        $self->_createTypeFile($archiveContentsDir, $bug);
        $self->_createModulesListFile($archiveContentsDir);
        system "dpkg -l > $archiveContentsDir/debpackages";
        $self->_createPartitionsFile($archiveContentsDir);
        copy ('/etc/fstab', "$archiveContentsDir/fstab");

        $self->_createSizeFile($archiveContentsDir);

        $self->_createBackupArchive($backupArchive, $tempdir, $archiveContentsDirRelative);
    } catch ($e) {
        EBox::Sudo::silentRoot("rm -rf '$tempdir'");
        $e->throw();
    }
    EBox::Sudo::silentRoot("rm -rf '$tempdir'");

    return $backupArchive;
}

sub _dumpModulesBackupData
{
    my ($self, $auxDir, %options) = @_;

    my $progress   = $options{progress};
    my $changesSaved = $options{changesSaved};

    my @modules = @{ $self->_modInstancesForBackup($changesSaved) };
    foreach my $mod (@modules) {
        my $modName = $mod->name();

        if ($progress) {
            # update progress object
            $progress->notifyTick();
            $progress->setMessage(__x('Dumping configuration of module {m}', m => $modName));
        }

        try {
            EBox::debug("Dumping $modName backup data");
            $mod->makeBackup($auxDir, %options);
        } catch (EBox::Exceptions::Base $e) {
            throw EBox::Exceptions::Internal($e->text);
        }
    }

}

sub _modInstancesForBackup
{
    my ($self, $changesSaved) = @_;

    my $readOnly = $changesSaved ? 0 : 1;
    my @mods = @{ $self->_configuredModInstances($changesSaved) };

    return \@mods;
}

sub _configuredModInstances
{
    my ($self, $readOnly) = @_;
    defined $readOnly or
        $readOnly = 0;

    my $global = EBox::Global->getInstance($readOnly);

    my @modules =  @{ $global->modInstances() };

    my @configuredModules;
    foreach my $mod (@modules) {
        if ($mod->can('configured')) {
            if ($mod->configured()) {
                push @configuredModules, $mod;
            }
        }
        else {
            push @configuredModules, $mod;
        }
    }

    return \@configuredModules;
}

sub  _createFilesArchive
{
    my ($self, $auxDir, $filesArchive, $removeDir) = @_;
    defined $removeDir or
        $removeDir =  1;

    EBox::Sudo::root("tar czf  '$filesArchive' --preserve-permissions -C '$auxDir' .");
    EBox::Sudo::root("chmod 0660 '$filesArchive'");
    EBox::Sudo::root("chown ebox.ebox '$filesArchive'");
    if ($removeDir) {
        EBox::Sudo::silentRoot("rm -rf '$auxDir'");
    }
}

sub  _createDateFile
{
    my ($self, $archiveContentsDir, $time) = @_;

    my $DATE;
    unless (open($DATE, "> $archiveContentsDir/date")) {
        throw EBox::Exceptions::Internal ("Could not create date file.");
    }
    print $DATE  $time ;
    close($DATE);
}

sub  _createDescriptionFile
{
    my ($self, $archiveContentsDir, $description) = @_;

    my $DESC;
    unless (open($DESC, "> $archiveContentsDir/description")) {
        throw EBox::Exceptions::Internal ("Could not create description file.");
    }
    print $DESC $description;
    close($DESC);
}

sub _createPartitionsFile
{
    my ($self, $archiveContentsDir) = @_;
    my $path = "$archiveContentsDir/partitions";
    my $PARTS;

    unless (open($PARTS, "> $path")) {
        throw EBox::Exceptions::Internal ("Could not create partitions info file.");
    }

    my $partitionsOutput;
    try {
        $partitionsOutput = EBox::Sudo::root('fdisk -l');
    } catch ($e) {
        my $errMsg = "Zentyal could not create a partition info file because this error: $e";
        EBox::error($errMsg);
        $partitionsOutput = [$errMsg];
    };

    foreach my $line (@{$partitionsOutput}) {
        print $PARTS $line;
    }

    close $PARTS or
        throw EBox::Exceptions::Internal ("Error writing partitions info file.");
}

sub  _createTypeFile
{
    my ($self, $archiveContentsDir, $bug) = @_;

    my $type = $bug ? $BUGREPORT_BACKUP_ID :
                      $CONFIGURATION_BACKUP_ID;

    my $TYPE_F;
    unless (open($TYPE_F, "> $archiveContentsDir/type")) {
        throw EBox::Exceptions::Internal ("Could not create type file.");
    }
    print $TYPE_F $type;
    close($TYPE_F);
}

sub _createMd5DigestForArchive
{
    my ($self, $filesArchive, $archiveContentsDir) = @_;

    my $ARCHIVE;
    unless (open($ARCHIVE, $filesArchive)) {
        throw EBox::Exceptions::Internal("Could not open files archive.");
    }
    my $md5 = Digest::MD5->new;
    $md5->addfile($ARCHIVE);
    my $digest = $md5->hexdigest;
    close($ARCHIVE);

    my $MD5;
    unless (open($MD5, "> $archiveContentsDir/md5sum")) {
        throw EBox::Exceptions::Internal("Could not open md5 file.");
    }
    print $MD5 $digest;
    close($MD5);
}

sub  _createModulesListFile
{
    my ($self, $archiveContentsDir) = @_;

    my @mods     = @{ $self->_modInstancesForBackup() };
    my @modNames = map { $_->name  } @mods;

    my $file = "$archiveContentsDir/modules";
    write_file($file, "@modNames");
}

sub  _createBackupArchive
{
    my ($self, $backupArchive, $tempdir, $archiveContentsDirRelative) = @_;

    if ( -f $backupArchive) {
        if (`rm -f $backupArchive`) {
            throw EBox::Exceptions::Internal  ("Could not delete old file.");
        }
    }

    my $filesArchive = "$archiveContentsDirRelative/files.tgz";
    EBox::Sudo::root("tar cf $backupArchive -C $tempdir $archiveContentsDirRelative --preserve-permissions  --exclude $filesArchive 2>&1");

    # append filesArchive
    EBox::Sudo::root("tar --append -f '$backupArchive'  -C '$tempdir' '$filesArchive' 2>&1");

    # adjust permissions and ownership given to ebox
    EBox::Sudo::root("chmod 0660 '$backupArchive'");
    EBox::Sudo::root("chown ebox.ebox '$backupArchive'");
}

sub _createSizeFile
{
    my ($self,  $archiveContentsDir) = @_;
    my $size;

    my $duCommand = "du -b -s -c --block-size=1024 $archiveContentsDir";
    my $output    = EBox::Sudo::command($duCommand);
    my ($totalLine) = grep { m/total/  } @{ $output  };
    ($size) = split '\s', $totalLine;

    my $sizeFile = "$archiveContentsDir/size";
    write_file($sizeFile, $size)
}

sub _createZentyalConfFilesArchive
{
    my ($self, $backupDir) = @_;

    my $archive = "$backupDir/etcFiles.tgz";
    my $etcDir = EBox::Config::etc();
    $self->_createFilesArchive($etcDir, $archive, 0);
}

sub _bug
{
    my ($self, $dir) = @_;

    system "/bin/ps aux > $dir/processes";
    system "/bin/df -k > $dir/disks";
    system "ip link show  > $dir/links";
    system "ip route list table all  > $dir/routes";

    my $sockets = EBox::Sudo::root("/bin/netstat -n -a --inet -p" );
    File::Slurp::write_file("$dir/sockets", $sockets);

    system "/sbin/ifconfig -a > $dir/interfaces";
    system "cp /etc/resolv.conf  $dir/resolv.conf";

    try {
        EBox::Sudo::root("/sbin/iptables -nvL > $dir/iptables-filter",
                         "/sbin/iptables -t nat -nvL > $dir/iptables-nat");
    } catch (EBox::Exceptions::Base $e) {
    }

    my $eboxLogDir = EBox::Config::log();
    # copy files from ebox logs directories...
    my @dirs = `find $eboxLogDir -maxdepth 1 -type d`;
    foreach my $subdir (@dirs) {
        chomp $subdir;

        my $newSubDir = $dir .'/' . basename($subdir) . '.log.d';
        (-d $newSubDir) or
            mkdir $newSubDir;

        system "cp -r $subdir/*.log $newSubDir";
    }

    copy("/var/log/syslog", "$dir/syslog");
    copy("/var/log/messages", "$dir/messages");
    copy("/var/log/daemon.log", "$dir/daemon.log");
    copy("/var/log/auth.log", "$dir/auth.log");
    copy("/var/log/mail.log", "$dir/mail.log");

    copy("/etc/apt/sources.list", "$dir/sources.list");
}

# Method: backupDetails
#
#       Gathers the information for a given backup
#
# Parameters:
#
#       id - backup's identifier
#
# Returns:
#
#       A hash reference with the details. This hash consists of:
#
#       file - the filename of the archive
#       id - backup's identifier
#       date - when it was backed up
#       type - the type of backup
#       description - backup's description
#
sub backupDetails # (id)
{
    my ($self, $id) = @_;
    defined $id or
        throw EBox::Exceptions::MissingArgument('id');
    defined $self or
        throw EBox::Exceptions::MissingArgument('self');

    $self->_checkId($id);

    my $file = $self->_backupFileById($id);
    my $details = $self->backupDetailsFromArchive($file);
    $details->{id} = $id;

    return $details;
}

# Method: backupDetailsFromArchive
#
#      Gathers the details of the backup stored in a given file
#
#
# Parameters:
#       archive - the path to the archive file
#
#
# Returns:
#
#       A hash reference with the details. This hash consists of:
#
#       file - the filename of the archive
#       date - when it was backed up
#       description - backup's description
#       type        - the type of backup contained by the archive
sub backupDetailsFromArchive
{
    my ($self, $archive) = @_;
    defined $archive or
        throw EBox::Exceptions::MissingArgument('archive');
    defined $self or
        throw EBox::Exceptions::MissingArgument('self');

    $self->_checkBackupFile($archive);

    my $backupDetails = {};

    my @details = qw(date description type);
    my $tempDir = $self->_unpackArchive($archive, @details);

    foreach my $detail (@details) {
        my $FH;
        unless (open($FH, "$tempDir/eboxbackup/$detail")) {
            $backupDetails->{$detail} = __('Unknown');
            next;
        }

        my $value = <$FH>;
        utf8::decode($value);
        $backupDetails->{$detail} = $value;

        close $FH;
    }

    $backupDetails->{file} = $archive;
    $backupDetails->{size} = $self->_printableSize($archive);

    EBox::Sudo::silentRoot("rm -rf '$tempDir'");
    return $backupDetails;
}

sub _printableSize
{
    my ($self, $archive) = @_;

    return EBox::Util::FileSize::printableSize(scalar(-s $archive));
}

# if not specific files are specified all the fiels are  extracted
sub _unpackArchive
{
    my ($self, $archive, @files) = @_;
    ($archive) or throw EBox::Exceptions::External('No backup archive provided.');

    my $tempDir = tempdir(EBox::Config::tmp . "/backup.XXXXXX") or
        throw EBox::Exceptions::Internal("Could not create tempdir.");
    EBox::Sudo::command("chmod 0700 $tempDir");

    my $filesWithPath =  @files > 0 ?
        join ' ', map { q{'eboxbackup/} . $_  . q{'} } @files : '';

    try {
        my $tarCommand = "/bin/tar xf '$archive' --same-owner --same-permissions -C '$tempDir' $filesWithPath";
        EBox::Sudo::root($tarCommand);
    } catch ($ex) {
        EBox::Sudo::silentRoot("rm -rf '$tempDir'");
        if (@files > 0) {
            throw EBox::Exceptions::External( __x("Could not extract the requested backup files: {files}", files => "@files"));
        }
        else {
            throw EBox::Exceptions::External( __("Could not unpack the backup"));
        }
    }

    return $tempDir;
}

# Method: deleteBackup
#
#       Romoves a stored backup
#
# Parameters:
#
#       id - backup's identifier
#
# Exceptions:
#
#       External -  If it can't be found or deleted.
sub deleteBackup
{
    my ($self, $id) = @_;
    defined $id or
        throw EBox::Exceptions::MissingArgument('id');
    defined $self or
        throw EBox::Exceptions::MissingArgument('self');

    $self->_checkId($id);

    my $file = $self->_backupFileById($id);

    unless (unlink($file)) {
        throw EBox::Exceptions::External("Could not delete the backup");
    }
}

# Method: listBackups
#
#       Returns a list with the availible backups stored in the system.
#
# Parameters:
#
#       id - backup's identifier
#
# Returns:
#
#       A a ref to an array of hashes. Each  hash reference consists of:
#
#       id - backup's identifier
#       date - when it was backed up
#       description - backup's description
#       type        - type of backup (now only one type: configuration)
#
sub listBackups
{
    my ($self) = @_;

    my $backupdir = backupDir();
    my $bh = new DirHandle($backupdir);
    my @backups = ();
    my $backup;
    ($bh) or return \@backups;
    while (defined($backup = $bh->read)) {
        (-f "$backupdir/$backup") or next;
        my $isTar = $backup =~ s/\.tar$//;

        $isTar or
            next;

        my $entry = undef;
        try {
            $entry = $self->backupDetails($backup);
        } catch (EBox::Exceptions::Base $e) {
        }
        unless ($entry) {
            EBox::info("File $backupdir.$backup.tar is in backup directorty and is not a backup file");
            next;
        }
        push(@backups, $entry);
    }
    undef $bh;
    my @ret = sort {$a->{date} lt $b->{date}} @backups;
    return \@ret;
}

#
# Procedure: backupDir
#
# Returns:
#       the directory used by ebox to store the backup archives
#
#
sub backupDir
{
    my $backupdir = EBox::Config::conf . '/backups';
    return $backupdir;
}

sub _ensureBackupdirExistence
{
    my $backupdir = backupDir();

    unless (-d $backupdir) {
        mkdir($backupdir, 0700) or throw EBox::Exceptions::Internal
            ("Could not create backupdir.");
    }
}

# Method: prepareMakeBackup
#
#       Prepares a backup restauration
#
# Parameters:
#
#                   description - backup's description (default: 'Backup')
#                   bug         - whether this backup is intended for a bug report
#                                 (one consequence of this is that we must clear
#                                  private data)
#
#                   remoteBackup -- whether this a backup intended to be a remote backup
#
# Returns:
#     progress indicator object of the operation
#
# Exceptions:
#
#       External - If it can't unpack de backup
#
sub prepareMakeBackup
{
    my ($self, %options) = @_;

    my $scriptParams = '';

    if ( $options{remoteBackup} ) {
        $scriptParams .= ' --remote-backup ';
        # Make sure remote backup name is scaped
        $scriptParams .= q{'} . $options{remoteBackup} . q{'};
    }

    if (exists $options{description}) {
        $scriptParams .= ' --description ';
        # make sure description is scaped
        $scriptParams .= q{'} . $options{description} . q{'};
    }

    if (exists $options{fallbackToRO} and $options{fallbackToRO}) {
        $scriptParams .= ' --fallback-to-ro';
    }

    $scriptParams .= ' --config-backup';

    if ($options{bug}) {
        $scriptParams .= ' --bug-report';
    }

    my $makeBackupScript = EBox::Config::scripts() . 'make-backup';
    $makeBackupScript    .=  $scriptParams;

    my $global     = EBox::Global->getInstance();
    # there are one task for each configured module plus two tasks for writing
    # the archive file. A possible aditional task if we have a remote backup
    my $totalTicks =  2;
    if ($options{remoteBackup}) {
        $totalTicks += 1;
    }
    $totalTicks += @{ $self->_configuredModInstances() };

    my @progressIndicatorParams = (executable => $makeBackupScript,
                                   totalTicks => $totalTicks);

    my $progressIndicator =  EBox::ProgressIndicator->create(
                @progressIndicatorParams
            );

    $progressIndicator->runExecutable();

    return $progressIndicator;
}

# Method: makeBackup
#
#      Back up the current configuration
#
# Parameters:
#
#      progress    - progress indicator
#                    associated with this operation (optional)
#      description - backup's description (default: 'Backup')
#      bug         - whether this backup is intended for a bug report
#                    (one consequence of this is that we must clear
#                     private data)
#      fallbackToRO - fallback to read-only configuration when
#                     they are not saved changes
#      noFinishProgress - don't mark progress indicator as finished (default:false)
#
#  Returns:
#         - path to the new backup archive
#
# Exceptions:
#
#       <EBox::Exceptions::Internal>    - If backup fails
#       <EBox::Exceptions::External>    - If modules have unsaved changes
#       <EBox::Exceptions::InvalidData> - If the created backup is corrupted
#
sub makeBackup
{
    my ($self, %options) = @_;
    exists $options{bug} or
        $options{bug} = 0;
    exists $options{fallbackToRO} or
        $options{fallbackToRO} = 0;
    $options{description} or
        $options{description} = __('Backup');
    my $finishProgress;
    my $progress = $options{progress};
    if ($progress) {
        $finishProgress = not $options{noFinishProgress};
    }

    EBox::info('Backing up configuration');
    if ($progress and not $progress->started()) {
        throw EBox::Exceptions::Internal("ProgressIndicator's executable has not been run");
    }

    my $backupdir = backupDir();
    my $time = time();
    $options{time} = $time;

    my $filename;
    try {
        my $changesSaved = $self->_changesSaved($options{fallbackToRO});

        _ensureBackupdirExistence();

        $filename = $self->_makeBackup(%options,
                                       changesSaved => $changesSaved);

        # Check the backup is correct, if not raise EBox::Exceptions::External exception
        $self->_checkBackup($filename);
    } catch ($ex) {
        $progress->setAsFinished(1, $ex->text) if $progress;
        $ex->throw();
    }

    my $backupFinalPath;
    try {
        if ($progress) {
            $progress->notifyTick();
            $progress->setMessage(__('Writing backup file to hard disk'));
        }

        my $dest = $options{destination};
        if (not defined $dest) {
            $dest = $self->_destinationFromTime($time);
        }

        $backupFinalPath = $self->_moveToArchives($filename, $backupdir, $dest);

        if ($finishProgress) {
            $progress->setAsFinished();
        }
    } catch ($ex) {
        if ($progress) {
            $progress->setAsFinished(1, $ex->text);
        }
        $ex->throw();
    }

    return $backupFinalPath;
}

sub _changesSaved
{
    my ($self, $fallbackToRO) = @_;

    my @changedMods;
    my $global = EBox::Global->getInstance();
    foreach my $modName (@{ $global->modNames() }) {
        if ($global->modIsChanged($modName)) {
            push @changedMods, $modName;

        }
    }

    if (@changedMods) {
        if ($fallbackToRO) {
            EBox::warn("The following modules have unsaved changes: @changedMods. A backup of the last saved configuration will be made instead");
            return 0;
        } else {
            throw EBox::Exceptions::External(
                    __x('The following modules have unsaved changes: {mods}. Before doing the backup you must save or discard them',
                        mods => join (', ', @changedMods))
            );
        }
    }

    return 1;
}

sub _destinationFromTime
{
    my ($self, $time) = @_;
    my $str =  strftime("%Y-%m-%d-%H%M%S", localtime($time));
    return  $str . '.tar';
}

sub _moveToArchives
{
    my ($self, $filename, $backupdir, $dest) = @_;

    move($filename, "$backupdir/$dest") or
        throw EBox::Exceptions::Internal("Could not save the backup.");

    return "$backupdir/$dest";
}

# Method: makeBugReport
#
#       Makes a bug report
#
sub makeBugReport
{
    my ($self) = @_;
    return $self->_makeBackup(description => 'Bug report', 'bug' => 1);
}

# unpacks a backup file into a temporary directory and verifies the md5sum
# arguments:
#       string: backup file
# returns:
#       string: path to the temporary directory
sub _unpackAndVerify
{
    my ($self, $archive, %options) = @_;
    ($archive) or throw EBox::Exceptions::External('No backup file provided.');
    my $tempdir;

    try {
        $tempdir = $self->_unpackArchive($archive);

        unless (-f "$tempdir/eboxbackup/files.tgz" &&
                -f "$tempdir/eboxbackup/md5sum") {
            throw EBox::Exceptions::External( __('Incorrect or corrupt backup file'));
        }

        $self->_checkArchiveMd5Sum($tempdir);
        $self->_checkArchiveType($tempdir);
        $self->_unpackModulesRestoreData($tempdir);
        unless ($options{forceZentyalVersion}) {
            $self->_checkZentyalVersion($tempdir);
        }
    } catch ($ex) {
        if (defined $tempdir) {
            EBox::Sudo::silentRoot("rm -rf '$tempdir'");
        }

        $ex->throw();
    }

    return $tempdir;
}

sub  _checkArchiveMd5Sum
{
    my ($self, $tempdir) = @_;

    my $archiveFile = "$tempdir/eboxbackup/files.tgz";
    my $ARCHIVE;
    unless (open($ARCHIVE, $archiveFile)) {
        EBox::error("Cannot open archive file $archiveFile");
        throw EBox::Exceptions::External(__("The backup file is corrupt: could not open archive"));
    }
    my $md5 = Digest::MD5->new;
    $md5->addfile($ARCHIVE);
    my $digest = $md5->hexdigest;
    close($ARCHIVE);

    my $md5File = "$tempdir/eboxbackup/md5sum";
    my $MD5;
    unless (open($MD5, $md5File)) {
        EBox::error("Could not open the md5sum $md5File");
        throw EBox::Exceptions::External(__("The backup file is corrupt: could not open backup checksum"));
    }
    my $olddigest = <$MD5>;
    close($MD5);

    if ($digest ne $olddigest) {
        throw EBox::Exceptions::External(
                __('The backup file is corrupt.'));
    }
}

sub _checkArchiveType
{
    my ($self, $tempdir) = @_;

    my $typeFile = "$tempdir/eboxbackup/type";
    my $TYPE_F;
    unless (open($TYPE_F, $typeFile )) {
        EBox::error("Cannot open type file: $typeFile");
        throw EBox::Exceptions::External("The backup file is corrupt. Backup type information not found");
    }
    my $type = <$TYPE_F>;
    close($TYPE_F);

    if ($type ne all($FULL_BACKUP_ID, $CONFIGURATION_BACKUP_ID, $BUGREPORT_BACKUP_ID)) {
        throw EBox::Exceptions::External(__("The backup archive has a invalid type. Maybe the file is corrupt or you are using a incompatible Zentyal version"));
    }
}

sub _checkBackupFile
{
    my ($self, $path) = @_;

    my $mm = new File::MMagic();
    my $mimeType = $mm->checktype_filename($path);
    if ($mimeType ne 'application/x-gtar') {
        throw EBox::Exceptions::External(__('The file is not a correct backup archive'));
    }
}

sub _checkSize
{
    my ($self, $archive) = @_;

    my $size;
    my $freeSpace;
    my $safetyFactor = 2; # to be sure we have space left we multiply the backup
                          # size by this number. The value was guessed, so change
                          # it if you have better judgment

    my $tempDir;
    try {
        $tempDir = $self->_unpackArchive($archive, 'size');
        $size = read_file("$tempDir/eboxbackup/size"); # unit -> 1K
    } catch ($ex) {
        EBox::Sudo::silentRoot("rm -rf '$tempDir'") if (defined $tempDir);
        $ex->throw();
    }
    EBox::Sudo::silentRoot("rm -rf '$tempDir'") if (defined $tempDir);

    if (not $size) {
        EBox::warn("Size file not found in the backup. Can not check if there is enough space to complete the restore");
        return;
    }

    my $backupDir = $self->backupDir();
    $freeSpace = df($backupDir, 1024)->{bfree};

    if ($freeSpace < ($size*$safetyFactor)) {
        throw EBox::Exceptions::External(__x("There in not enough space left in the hard disk to complete the restore proccess. {size} Kb required. Free sufficient space and retry", size => $size));
    }
}

sub _checkZentyalVersion
{
    my ($self, $tempDir) = @_;
    my $file = "$tempDir/eboxbackup/debpackages" ;

    if (not -r $file) {
        throw EBox::Exceptions::External(__(
   'No debian packages list file found; probably the backup was done in a incompatible Zentyal version. Only backups done in the actual Zentyal version can be restored',
                                            )
                                        );
    }

    my $zentyalVersion;
    open my $FH, '<', $file or
        throw EBox::Exceptions::Internal("Opening $file: $!");
    while (my $line = <$FH>) {
        if ($line =~ m/ii\s+zentyal-core\s+(.*?)\s/) {
            $zentyalVersion = $1;
            last;
        }
    }
    close $FH or
        throw EBox::Exceptions::Internal("Opening $file: $!");

    if (not $zentyalVersion) {
        throw EBox::Exceptions::External(__(
'No zentyal-core found in the debian packages list form the backup; probably the backup was done in a incompatible Zentyal version. Only backups done in the actual Zentyal version can be restored'
                                           )
                                        );
    }

    my ($major, $minor) = split('[\.~]', $zentyalVersion, 4);

    my ($wantedMajor, $wantedMinor);
    my @dpkgOutput = `dpkg -l zentyal-core`;
    my @actualParts = split('\s+', $dpkgOutput[-1], 4);
    my $actualVersion = $actualParts[2];
    if  ($actualVersion) {
        ($wantedMajor, $wantedMinor) = split('[\.~]', $actualVersion, 3);
    } else {
        throw EBox::Exceptions::Internal("Cannot retrieve actual version from dpkg output: '@dpkgOutput'");
    }

    if (($major != $wantedMajor) && ($minor != $wantedMinor)) {
        if ($major == 4) {
            $self->_migrateFromOldVersion($tempDir);
        } elsif (($major == 3) and (-x EBox::Config::configkey('custom_oldbackup_restore_script'))) {
            system(EBox::Config::configkey('custom_oldbackup_restore_script') . ' ' . $tempDir);
        } else {
            throw EBox::Exceptions::External(__x(
    'Could not restore the backup because a mismatch between its Zentyal version and the current system version. Backup was done in Zentyal version {bv} and this system could only restore backups from Zentyal version {wv}',
                    bv => $zentyalVersion,
                    wv => "$wantedMajor.$wantedMinor")
            );
        }
    }
}

sub _migrateFromOldVersion
{
    my ($self, $tempDir) = @_;

    my $path = "$tempDir/eboxbackup";

    foreach my $mod (qw(services objects)) {
        my $file = "$path/$mod.bak/$mod.bak";
        system("sed -i 's/^$mod/network/g' $file");
        system("cat $file >> $path/network.bak/network.bak");
    }

    # FIXME: check if we need to migrate something here,
    #        for example: enabled openchange -> enabled sogo
    my $global = "$path/global.bak/global.bak";
    foreach my $mod (qw(services objects remoteservices openchange printers antivirus mailfilter)) {
        system("rm -rf $path/$mod.bak");
        system("sed -i 's/ $mod//' $path/modules");
        system("sed -i '/$mod/d' $global");
    }
    system("cat -s $global > $path/global.tmp");
    system("mv $path/global.tmp $global");
}

# Method: prepareRestoreBackup
#
#       Prepares a backup restauration
#
# Parameters:
#
#       file - backup's file (as positional parameter)
#       forceDependencies - wether ignore dependency errors between modules
#       deleteBackup      - deletes the backup after resroting it or if the process is aborted
#       revokeAllOnModuleFail - whether to revoke all restored configuration
#                              when a module restoration fails
#       continueOnModuleFail - wether continue when a module fails to restore
#                              (default: false)
#       dr          - restore in disaster recovery mode, installing needed packages
#
#  Returns:
#    the progress indicator object which represents the progress of the restauration
#
# Exceptions:
#
#       External - If it can't unpack the backup archive
#
sub prepareRestoreBackup
{
    my ($self, $file, %options) = @_;

    my $restoreBackupScript = EBox::Config::scripts() . 'restore-backup';

    my $execOptions = '';

    if (exists $options{forceDependencies}) {
        if ($options{forceDependencies}) {
            $execOptions .= '--force-dependencies ';
        }
    }

    if (exists $options{deleteBackup}) {
        if ($options{deleteBackup}) {
            $execOptions .= '--delete-backup ';
        }
    }

    if (exists $options{modsToRestore}) {
        foreach my $m (@{ $options{modsToRestore} }) {
            $execOptions .= "--module $m ";
        }
    }

    if (exists $options{revokeAllOnModuleFail}) {
        if ($options{revokeAllOnModuleFail}) {
            $execOptions .= '--revoke-all-on-module-fail ';
        } else {
            $execOptions .= '--no-revoke-all-on-module-fail ';
        }
    }

    if (exists $options{continueOnModuleFail}) {
        if ($options{continueOnModuleFail}) {
            $execOptions .= '--continue-on-module-fail ';
        } else {
            $execOptions .= '--no-continue-on-module-fail ';
        }
    }

    my $totalTicks = scalar @{ $self->_modInstancesForRestore($file) };

    if (exists $options{dr}) {
        if ($options{dr}) {
            $execOptions .= '--install-missing ';
            # FIXME: increase at least one tick per module to install
            $totalTicks++;
        }
    }

    $restoreBackupScript .= " $execOptions $file";

    my $progressIndicator =  EBox::ProgressIndicator->create(
            executable => $restoreBackupScript,
            totalTicks => $totalTicks,
            );

    $progressIndicator->runExecutable();

    return $progressIndicator;
}

# Method: restoreBackup
#
#       Restores a backup from file
#
# Parameters:
#
#       file - backup's file (as positional parameter)
#       progressIndicator - Progress indicator associated
#                       with this operation (optional )
#       forceDependencies - wether ignore dependency errors between modules
#       forceZentyalVersion - ignore zentyal version check
#       deleteBackup      - deletes the backup after resroting it or if the process is aborted
#       revokeAllOnModuleFail - whether to revoke all restored configuration
#                              when a module restoration fail
#       continueOnModuleFail - wether continue when a module fails to restore
#                              (default: false)
#       modsToRestore      - names of modules to restore (default: all)
#       modsToExclude      - name of modules to exclude fro the restore (default:none)
#
# Exceptions:
#
#       External - If it can't unpack de backup
#
sub restoreBackup
{
    my ($self, $file, %options) = @_;
    defined $file or
        throw EBox::Exceptions::MissingArgument('Backup file');
    exists $options{revokeAllOnModuleFail}
        or $options{revokeAllOnModuleFail} = 1;
    exists $options{modsToExclude} or
        $options{modsToExclude} = [];
    my $progress = $options{progress};

    # EBox::debug("restore backup id: " . $progress->id);
    if ($progress and not $progress->started()) {
        throw EBox::Exceptions::Internal("ProgressIndicator's executable has not been run");
    }

    my $tempdir;
    try {
        _ensureBackupdirExistence();

        $self->_checkBackupFile($file);
        $self->_checkSize($file);

        $tempdir = $self->_unpackAndVerify($file, %options);

        if ($options{installMissing}) {
            $progress->setMessage(__('Installing Zentyal packages in backup...')) if ($progress);
            $self->_installMissingModules($file);
            $progress->notifyTick() if ($progress);
        }

        $self->_restoreZentyalConfFiles($tempdir);

        $self->_preRestoreActions($tempdir, %options);

        my @modules  = @{ $self->_modInstancesForRestore($file, %options) };
        my @restored = ();
        my @failed   = ();
        # run pre-checks
        foreach my $mod (@modules) {
            $self->_restoreModulePreCheck($mod, $tempdir, \%options);
        }

        try {
            foreach my $mod (@modules) {
                my $restoreOk;
                try {
                    $restoreOk = $self->_restoreModule($mod, $tempdir, \%options);
                } catch ($ex) {
                    if ($options{continueOnModuleFail}) {
                        my $warn = 'Error when restoring ' . $mod->name() .
                             ': ' . $ex->text() .
                                 '. The restore process will continue anyway';
                        EBox::error($warn);
                    } else {
                        $ex->throw();
                    }
                };
                if ($restoreOk) {
                    push @restored, $mod->name();
                } else {
                    push @failed, $mod->name();
                }

            }
        } catch ($ex) {
            my $errorMsg = 'Error while restoring: ' . $ex->text();
            EBox::error($errorMsg);
            $progress->setAsFinished(1, $errorMsg) if $progress;

            if ($options{revokeAllOnModuleFail}) {
                $self->_revokeRestore(\@restored);
            }

            $ex->throw();
        }

        # We need to set them as changed to be sure that they are restarted
        # in the save all after restoring, if they have run any migration
        # during restore they have been set as restarted.
        # We only do this with correctly restored modules
        foreach my $modName (@restored) {
            my $mod = EBox::Global->modInstance($modName);
            $mod->setAsChanged();
        }

        if (@restored == @modules) {
            EBox::info('Restore successful');
        } else {
            @restored = sort @restored;
            @failed = sort @failed;
            EBox::info("Restore finished. The following modules have been successfuly restored: @restored. But the following ones have failed: @failed.");
        }

        $progress->setAsFinished() if $progress;
    } catch ($e) {
        EBox::Sudo::silentRoot("rm -rf '$tempdir'") if ($tempdir);
        unlink $file if ($options{deleteBackup});
        $e->throw();
    }
    EBox::Sudo::silentRoot("rm -rf '$tempdir'") if ($tempdir);
    unlink $file if ($options{deleteBackup});
}

sub _unpackModulesRestoreData
{
    my ($self, $tempdir) = @_;

    my $unpackCmd = "tar xzf  '$tempdir/eboxbackup/files.tgz' --same-owner --same-permissions  -C '$tempdir/eboxbackup'";
    try {
        EBox::Sudo::root($unpackCmd);
    } catch {
        EBox::Sudo::silentRoot("rm -rf '$tempdir'");
        throw EBox::Exceptions::External(
                __('Could not unpack the backup')
                );

    };
}

sub _restoreZentyalConfFiles
{
    my ($self, $tempdir) = @_;

    my $etc = EBox::Config::etc();
    my $archive = "$tempdir/eboxbackup/etcFiles.tgz";
    if (not -f $archive) {
        EBox::warn("$etc files archive not found; not restoring them" );
        return;
    }

    my $tmpEtc = "$tempdir/etc";
    mkdir $tmpEtc;

    my $unpackCmd = "tar xzf '$archive' -C '$tmpEtc'";
    system $unpackCmd;

    if ($? != 0) {
        system "rm -rf '$tmpEtc'";
        EBox::error("Could not unpack the Zentyal configuration files archive backup");
        EBox::info("Zentyal configuration files in $etc are not restored, but the restore process will continue");
        return;
    }

    # create backup directory for files/directories to be replaced
    my $dateSuffix =  strftime("%Y-%m-%d-%H%M%S", localtime());
    my $currentEtcBackupDirBase = "/var/backups/etc-zentyal-$dateSuffix";
    my $currentEtcBackupDir = $currentEtcBackupDirBase;
    my $cnt = 0;
    while (EBox::Sudo::fileTest('-e', $currentEtcBackupDir)) {
        $cnt++;
        $currentEtcBackupDir = "$currentEtcBackupDirBase-$cnt";
    }
    EBox::Sudo::root("cp -a $etc $currentEtcBackupDir");

    try {
        # put restored directory in place
        EBox::Sudo::root("cp -af $tmpEtc/* $etc");
    } catch (EBox::Exceptions::Sudo::Command $e) {
        # continue with the restore anyway
        EBox::error("Cannot restore $etc files: $!.");
        EBox::info("We cannot restore Zentyal configuration files in $etc, but the restore process will continue.");
    } catch ($ex) {
        EBox::Config::refreshConfFiles();
        $ex->throw();
    }
    EBox::Config::refreshConfFiles();
}

sub _restoreModulePreCheck
{
    my ($self, $mod, $tempdir, $options_r) = @_;

    $mod->callRestoreBackupPreCheck("$tempdir/eboxbackup", $options_r);
}

sub _restoreModule
{
    my ($self, $mod, $tempdir, $options_r) = @_;
    my $modname = $mod->name();

    # update progress indicator
    my $progress = $options_r->{progress};

    if ($progress) {
        $progress->notifyTick();
        $progress->setMessage($modname);
    }

    if (not -e "$tempdir/eboxbackup/$modname.bak") {
        EBox::error("Restore data not found for module $modname. Skipping $modname restore");
        return 0;
    }

    EBox::debug("Restoring $modname from backup data");
    $mod->setAsChanged(); # we set as changed first because it is not
        # guaranteed that a failed backup will not
        # change state
        $mod->restoreBackup("$tempdir/eboxbackup",
                            %{ $options_r }
                );

    $mod->migrate();

    return 1;
}

sub _revokeRestore
{
    my ($self, $restored_r) = @_;

    EBox::debug('revoking restore for all modules');
    foreach my $restname (@{ $restored_r }) {
        my $restmod = EBox::Global->modInstance($restname);
        try {
            $restmod->revokeConfig();
            # XXX remember non-redis changes are not revoked!
            EBox::debug("Revoked changes in $restname module");
        } catch {
            EBox::debug("$restname has not changes to be revoked" );
        }
    }
}

sub _preRestoreActions
{
    my ($self, $tempdir, %options) = @_;

    my $global = EBox::Global->getInstance();
    my @inBackup = @{ $self->_modulesInBackup($tempdir) };

    my @missing;
    foreach my $modName (@inBackup) {
        # Skip cloud-prof to check in restore since it is possible not
        # to be installed until the first restore process is done (DR)
        next if ($modName eq 'cloud-prof');
        unless ($global->modExists($modName)) {
            push (@missing, $modName);
        }
    }
    if (@missing and not $options{forceDependencies} and not $options{installMissing}) {
        throw EBox::Exceptions::External(
                __x('The following modules present in the backup are not installed: {mods}. You need to install them before restoring.',
                    'mods' => join (' ', @missing))
                );
    }

    my $mgr = EBox::ServiceManager->new();
    my @mods = @{$mgr->_dependencyTree()};

    # TODO: Integrate with progressIndicator
    foreach my $name (@mods) {
        my $mod = $global->modInstance($name);

        if ($name eq any(@inBackup)) {
            next unless $mod->can('configured');
            # The module is present in the backup but has
            # never been configured, so we must enable it
            unless ($mod->configured()) {
                try {
                    EBox::info("Configuring previously unconfigured module $name present in the backup to restore");
                    $mod->{restoringBackup} = 1;
                    $mod->configureModule();
                } catch ($e) {
                    delete $mod->{restoringBackup};

                    my $err = $e->text();
                    throw EBox::Exceptions::Internal(__x('Cannot restore backup, error enabling module {m}: {err}',
                                                         'm' => $name, 'err' => $err));
                }
                delete $mod->{restoringBackup};
            }
        } else {
            next unless $mod->can('isEnabled');
            # Module is enabled but not present in the backup
            # we are going to restore, so we must disable it
            if ($mod->isEnabled()) {
                EBox::info("Disabling module $name not present in the backup to restore");
                $mod->enableService(0);
            }
        }
    }
}

sub _modInstancesForRestore
{
    my ($self, $archive, %options) = @_;
    my $forceDependencies = $options{forceDependencies};

    my $anyModuleInBackup = any( @{ $self->_modulesInBackup($archive) } );

    my @modules = @{ $self->_configuredModInstances };

    my $anyToExclude = any(@{ $options{modsToExclude}});

    # if we have a module list we check it and only keep those modules
    if (exists $options{modsToRestore}) {
        my @modsToRestore =  @{ $options{modsToRestore} };
        foreach my $m (@modsToRestore) {
            if (not( $m eq $anyModuleInBackup)) {
                throw EBox::Exceptions::External(
                        __x(
                            'No module {m} found in backup',
                            'm' => $m
                           )
                        );
            }
            if ($m eq $anyToExclude) {
                throw EBox::Exceptions::External(
                        __x(
                            'Module {m} is in both exclude and include lists',
                            'm' => $m
                           )
                        );
            }
        }

        # we use the module list instead of the full list of backup's module
        $anyModuleInBackup = any @modsToRestore;
    }

    # we restore the intersection between the installed modules AND the modules in
    # the backup archive. We remove the excluded modules
    @modules = grep {
        my $name = $_->name();
        ($name eq $anyModuleInBackup) and not ($name eq $anyToExclude)
    } @modules;

    # we remove global module because it will not  be restored
    @modules   =  grep { $_->name ne 'global' } @modules;

    if (not @modules) {
        throw EBox::Exceptions::External(
                __('No modules to restore')
                );
    }

    # check modules dependencies
    if (not $forceDependencies) {
        foreach my $mod (@modules) {
            $self->_checkModDeps($mod->name);
        }
    }

    my $sortedModules = EBox::Global->sortModulesByDependencies(
            \@modules,
            'restoreDependencies',
            );
    return $sortedModules;
}

sub _modulesInBackup
{
    my ($self, $archive) = @_;

    my $tempDir = $archive;
    unless (-d $archive) {
        $tempDir = $self->_unpackArchive($archive, 'modules');
    }

    my $modulesString = read_file("$tempDir/eboxbackup/modules");

    my @modules = split '\s', $modulesString;

    return \@modules;
}

sub _checkModDeps
{
    my ($self, $modName, $level, $topModule) = @_;
    defined $level or $level = 0;

    if ($level == 0) {
        $topModule = $modName;
    }

    if ($level >= $RECURSIVE_DEPENDENCY_THRESHOLD) {
        throw EBox::Exceptions::Internal("Recursive restore dependency found in module $modName");
    }

    my $global = EBox::Global->getInstance();
    my $mod = $global->modInstance($modName);

    if (not defined $mod) {
        if ($level == 0) {
            throw EBox::Exceptions::Internal ("$topModule cannot be created again");
        }
        else {
            throw EBox::Exceptions::External __x('Unresolved restore dependency for module {topModule}: {modName} is not installed', topModule => $topModule, modName => $modName  );
        }
    }

    my @dependencies = @{$mod->restoreDependencies};
    foreach my $dep (@dependencies) {
        if ($dep eq $modName) {
            throw EBox::Exceptions::Internal ("$modName depends on it self. Maybe something is wrong in _modInstancesForRestore method?. $modName will not be restored");
        }

        $self->_checkModDeps($dep, $level +1, $topModule);
    }
}

sub _installMissingModules
{
    my ($self, $configBackup) = @_;

    my %modulesInBackup = map { $_ => 1 } @{ $self->_modulesInBackup($configBackup) };
    my %modulesToConfigure  = %modulesInBackup;

    foreach my $modName (@{EBox::Global->modNames()}) {
        delete $modulesInBackup{$modName};
        my $mod = EBox::Global->modInstance($modName);
        if ((not $mod->isa('EBox::Module::Service')) or
             $mod->configured()) {
            delete $modulesToConfigure{$modName};
        }
    }

    $self->_installMissingPackages(keys %modulesInBackup);

    my @unconfModules = keys %modulesToConfigure;
    if (@unconfModules) {
        EBox::info("Modules to configure: @unconfModules");
        $self->_configureModules(@unconfModules);
    }
}

sub _installMissingPackages
{
    my ($self, @modules) = @_;

    my @packages = map { "zentyal-$_" } grep { not EBox::Global->modExists($_) } @modules;

    if (@packages) {
        EBox::Sudo::root('apt-get update -q');
        EBox::info("Missing packages to recover the configuration: @packages");
        $self->_aptInstall(\@packages);
    }
}

sub _aptInstall
{
    my ($self, $packages_r) = @_;

    my @packages = @{ $packages_r };

    my $software = EBox::Global->modInstance('software');
    my $progressIndicator = $software->installPkgs(@packages);
    my $retValue = $progressIndicator->retValue();
    if ($retValue != 0) {
        my $errorMsg = $progressIndicator->errorMsg();
        my $msg;

        if ($errorMsg) {
            EBox::error("Error installing packages:\n$errorMsg\nThe backup will continue but it would not able to recover any configuration  which depends on the missing packages");
        } else {
            EBox::error("Progress indicator for _aptInstall does not specify any error but has returned the following value: $retValue.");
        }
    }
}

sub _configureModules
{
    my ($self, @modulesToConfigure) = @_;

    unless (@modulesToConfigure) {
        return;
    }

    my %toConfigure = map { $_ => 1 } @modulesToConfigure;

    my $mgr = EBox::ServiceManager->new();
    my @orderedMods = @{$mgr->_dependencyTree()};

    my $i = 0;
    my $percent;
    foreach my $name (@orderedMods) {
        $i += 1;
        next unless (exists $toConfigure{$name});

        EBox::info("Configuring module: $name");

        my $module = EBox::Global->modInstance($name);
        try {
            $module->configureModule();
        } catch ($ex) {
            my $err = $ex->text();
            EBox::error("Failed to enable module $name: $err");
        }
    }
}

sub _checkId
{
    my ($self, $id) = @_;
    if ($id =~ m{[./]}) {
        throw EBox::Exceptions::External(
                __("The input contains invalid characters"));
    }
}

sub _backupFileById
{
    my ($self, $id) = @_;

    my $backupdir = EBox::Config::conf . '/backups';
    my $file = "$backupdir/$id.tar";
    unless (-f $file) {
        throw EBox::Exceptions::External("Could not find the backup.");
    }

    return $file;
}

# Check the backup contents a non-corrupted data
sub _checkBackup
{
    my ($self, $filename) = @_;

    try {
        EBox::Sudo::command("tar --list --file '$filename'");
        EBox::Sudo::command("tar --test-label --file '$filename'");
    } catch (EBox::Exceptions::Command $e) {
        throw EBox::Exceptions::InvalidData(
            data   => 'backup',
            value  => $e->stringify(),
            advice => __('Try to back up again as the created backup is corrupted')
           );
    };
}

1;
