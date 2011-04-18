# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::Backup;

use strict;
use warnings;

use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::FileSystem;
use EBox::ProgressIndicator;
use EBox::ProgressIndicator::Dummy;

use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use File::Slurp qw(read_file write_file);
use File::Basename;

use Error qw(:try);
use Digest::MD5;
use EBox::Sudo qw(:all);
use POSIX qw(strftime);
use DirHandle;
use Perl6::Junction qw(any all);

use Params::Validate qw(validate_with validate_pos ARRAYREF);
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
sub _makeBackup # (description, bug?)
{
    my ($self, %options) = @_;

    my $description = delete $options{description};
    my $time        = delete $options{time};

    my $bug         = $options{bug};
    my $progress   = $options{progress};

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
        $self->_createEBoxEtcFilesArchive($archiveContentsDir);
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
    }
    finally {
        system "rm -rf '$tempdir'";
        if ($? != 0) {
            EBox::error("$auxDir cannot be deleted: $!. Please do it manually");
        }
    };

    return $backupArchive;
}


sub _dumpModulesBackupData
{
    my ($self, $auxDir, %options) = @_;

    my $progress   = $options{progress};

    my @modules = @{ $self->_modInstancesForBackup() };
    foreach my $mod (@modules) {
        my $modName = $mod->name();

        if ($progress) {
            # update progress object
            $progress->notifyTick();
            $progress->setMessage(__x('Dumping configuration of module {m}',
                        m => $modName));
        }

        try {
            EBox::debug("Dumping $modName backup data");
            $mod->makeBackup($auxDir, %options);
        }
        catch EBox::Exceptions::Base with {
            my $ex = shift;
            throw EBox::Exceptions::Internal($ex->text);
        };
    }

}

sub _modInstancesForBackup
{
    my ($self) = @_;

    my @mods = @{ $self->_configuredModInstances };

    return \@mods;
}


sub _configuredModInstances
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();

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
# leave aside not configured modules
#   @modules = grep {
# #    (not $_->isa('EBox::Module::Service') or
# #    ($_->configured()))
#     $_->configured()
#   } @modules;

    return \@configuredModules;
}


sub  _createFilesArchive
{
    my ($self, $auxDir, $filesArchive) = @_;

    if (`umask 0077; tar czf '$filesArchive' -C '$auxDir' .`) {
        throw EBox::Exceptions::Internal("Could not create archive.");
    }
    system "rm -rf '$auxDir'";
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

    my $partitionsOutput = EBox::Sudo::root('fdisk -l');
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
    my $cmd;
    my @output;

    $cmd = "umask 0077; tar cf $backupArchive -C $tempdir $archiveContentsDirRelative  --exclude $filesArchive 2>&1";
    @output = `$cmd`;
    if ($? != 0) {
        EBox::error("Failed command: $cmd. Output: @output");
        throw EBox::Exceptions::External(__('Could not create backup archive'));
    }

    $cmd = "tar --append -f '$backupArchive'  -C '$tempdir' '$filesArchive' 2>&1";
    @output = `$cmd`;
    if ($? != 0) {
        EBox::error("Failed command: $cmd. Output: @output");
        throw EBox::Exceptions::External(__('Could not append data to backup archive'));
    }
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


sub _createEBoxEtcFilesArchive
{
    my ($self, $backupDir) = @_;

    my $archive = "$backupDir/etcFiles.tgz";
    my $dir = "$backupDir/etcFiles";
    mkdir $dir;
    my $etcDir = EBox::Config::etc();
    system "cp $etcDir/*.conf '$dir' 2>&1 > /dev/null ";
    system "cp $etcDir/ppa.gpg '$dir'  2>&1 > /dev/null";
    system "cp -a $etcDir/hooks '$dir'  2>&1 > /dev/null";
    system "cp -a $etcDir/post-save '$dir'  2>&1 > /dev/null";
    system "cp -a $etcDir/pre-save '$dir'  2>&1 > /dev/null ";
    $self->_createFilesArchive($dir, $archive);
}

sub _bug # (dir)
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
        root("/sbin/iptables -nvL > $dir/iptables-filter");
    } catch EBox::Exceptions::Base with {};

    try {
        root("/sbin/iptables -t nat -nvL > $dir/iptables-nat");
    } catch EBox::Exceptions::Base with {};


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
    validate_pos(@_, 1, ,1);

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
    validate_pos(@_, 1, 1);

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
        $backupDetails->{$detail} = $value;

        close $FH;
    }

    $backupDetails->{file} = $archive;
    $backupDetails->{size} = $self->_printableSize($archive);

    system "rm -rf '$tempDir'";
    return $backupDetails;
}


sub _printableSize
{
    my ($self, $archive) = @_;

    my $size = (-s $archive);

    my @units = qw(KB MB GB);
    foreach my $unit (@units) {
        $size = sprintf ("%.2f", $size / 1024);
        if ($size < 1024) {
            return "$size $unit";
        }
    }

    return $size . ' ' . (pop @units);
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
        my $tarCommand = "/bin/tar xf '$archive' -C '$tempDir' $filesWithPath";
        if (system $tarCommand) {
            if (@files > 0) {
                throw EBox::Exceptions::External( __x("Could not extract the requested backup files: {files}", files => "@files"));
            }
            else {
                throw EBox::Exceptions::External( __("Could not unpack the backup"));
            }
        }
    }
    otherwise {
        my $ex = shift;

        system("rm -rf '$tempDir'");
        ($? == 0) or EBox::warning("Unable to remove $tempDir. Please do it manually");

        $ex->throw();
    };

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
sub deleteBackup # (id)
{
    my ($self, $id) = @_;
    validate_pos(@_, 1, 1);

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
#       type        - type of backup (full or configuration only)
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
        } catch EBox::Exceptions::Base with {};
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

    $scriptParams .= ' --config-backup';

    if ($options{bug}) {
        $scriptParams .= ' --bug-report';
    }

    my $makeBackupScript = EBox::Config::pkgdata() . 'ebox-make-backup';
    $makeBackupScript    .=  $scriptParams;

    my $global     = EBox::Global->getInstance();
    my $totalTicks = scalar @{ $global->modNames() } + 2; # there are one task for
    # each module plus two
    # tasks for writing the
    # archive  file

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
#       Backups the current configuration
#
# Parameters:
#
#                   progress    - progress indicator
#                                 associated with this operation (optional)
#                   description - backup's description (default: 'Backup')
#                   bug         - whether this backup is intended for a bug report
#                                 (one consequence of this is that we must clear
#                                  private data)
#
#  Returns:
#         - path to the new backup archive
#
# Exceptions:
#
#       Internal - If backup fails
#       External - If modules have unsaved changes
sub makeBackup # (options)
{
    my ($self, %options) = @_;
    validate_with(
            params => [%options],
            spec   => {
                progress     => {
                    optional => 1,
                    isa => 'EBox::ProgressIndicator'
                },
                description => { default =>  __('Backup') },
                bug         => { default => 0},
                destination => { optional => 1 },
            });

    my $progress = $options{progress};
    if (not $progress) {
        $progress = EBox::ProgressIndicator::Dummy->create();
        $options{progress} = $progress;
    }

    EBox::debug("make backup id: " . $progress->id());
    $progress->started or
        throw EBox::Exceptions::Internal("ProgressIndicator's executable has not been run");

    my $backupdir = backupDir();
    my $time = time();
    $options{time} = $time;

    my $filename;
    try {
        $self->_modulesReady();

        _ensureBackupdirExistence();

        $filename = $self->_makeBackup(%options);
    }
    otherwise {
        my $ex = shift @_;
        $progress->setAsFinished(1, $ex->text);
        $ex->throw();
    };

    my $backupFinalPath;
    try {
        $progress->notifyTick();
        $progress->setMessage(__('Writing backup file to hard disk'));

        my $dest = $options{destination};
        if (not defined $dest) {
            $dest = $self->_destinationFromTime($time);
        }

        $backupFinalPath = $self->_moveToArchives($filename, $backupdir, $dest);

        $progress->setAsFinished();
    }
    otherwise {
        my $ex = shift @_;
        $progress->setAsFinished(1, $ex->text);
        $ex->throw();
    };

    return $backupFinalPath;
}


sub _modulesReady
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    foreach my $modName (@{ $global->modNames() }) {
        if ($global->modIsChanged($modName)) {
            throw EBox::Exceptions::External(
                    __x('Module {mod} has not saved changes. Before doing the backup you must'
                        . ' save or discard them', mod => $modName ) );
        }
    }
}


sub _destinationFromTime
{
    my ($self, $time) = @_;
    my $str =  strftime("%Y-%m-%d-%H%M%S", localtime($time));
    return  $str . '.tar';
}

sub  _moveToArchives
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
sub _unpackAndVerify # (file, fullRestore)
{
    my ($self, $archive, $fullRestore) = @_;
    ($archive) or throw EBox::Exceptions::External('No backup file provided.');
    my $tempdir;

    try {
#     unless (copy($file, "$tempdir/eboxbackup.tar")) {
#       throw EBox::Exceptions::Internal("Could not copy backup into ".
#                                        "the tempdir.");
#     }

        $tempdir = $self->_unpackArchive($archive);

        unless (-f "$tempdir/eboxbackup/files.tgz" &&
                -f "$tempdir/eboxbackup/md5sum") {
            throw EBox::Exceptions::External( __('Incorrect or corrupt backup file'));
        }

        $self->_checkArchiveMd5Sum($tempdir);
        $self->_checkArchiveType($tempdir, $fullRestore);
    }
    otherwise {
        my $ex = shift;

        if (defined $tempdir) {
            system("rm -rf '$tempdir'");
            ($? == 0) or EBox::warning("Unable to remove $tempdir. Please do it manually");
        }

        $ex->throw();
    };

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
    my ($self, $tempdir, $fullRestore) = @_;

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

    if ($fullRestore) {
        if ($type ne $FULL_BACKUP_ID) {
            throw EBox::Exceptions::External(__('The archive does not contain a full backup, that made a full restore impossibe. A configuration recovery  may be possible'));
        }
    }
}


sub  _checkSize
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
    }
    finally {
        if (defined $tempDir) {
            system("rm -rf '$tempDir'");
            ($? == 0) or EBox::warning("Unable to remove $tempDir. Please do it manually");
        }
    };

    my $backupDir = $self->backupDir();
    $freeSpace = df($backupDir, 1024)->{bfree};

    if ($freeSpace < ($size*$safetyFactor)) {
        throw EBox::Exceptions::External(__x("There in not enough space left in the hard disk to complete the restore proccess. {size} Kb required. Free sufficient space and retry", size => $size));
    }
}


# Method: prepareRestoreBackup
#
#       Prepares a backup restauration
#
# Parameters:
#
#       file - backup's file (as positional parameter)
#       fullRestore - wether do a full restore or restore only configuration (default: false)
#       dataRestore - wether do a data-only restore
#       forceDependencies - wether ignore dependency errors between modules
#       deleteBackup      - deletes the backup after resroting it or if the process is aborted
#       revokeAllOnModuleFail - whether to revoke all restored configuration
#                              when a module restoration fails
#       continueOnModuleFail - wether continue when a module fails to restore
#                              (default: false)
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

    my $restoreBackupScript = EBox::Config::pkgdata() . 'ebox-restore-backup';

    my $execOptions = '';

    if (exists $options{fullRestore}) {
        if ($options{fullRestore}) {
            $execOptions .= '--full-restore ';
        }
    }

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

    $restoreBackupScript    .= " $execOptions $file";

    my $totalTicks = scalar @{ $self->_modInstancesForRestore($file) };

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
#                       with htis operation (optional )
# fullRestore - wether do a full restore or restore only configuration (default: false)
#       dataRestore - wether do a data-only restore
#       forceDependencies - wether ignore dependency errors between modules
#        deleteBackup      - deletes the backup after resroting it or if the process is aborted
#       revokeAllOnModuleFail - whether to revoke all restored configuration
#                              when a module restoration fail
#       continueOnModuleFail - wether continue when a module fails to restore
#                              (default: false)
#
# Exceptions:
#
#       External - If it can't unpack de backup
#
sub restoreBackup # (file, %options)
{
    my ($self, $file, %options) = @_;
    defined $file or throw EBox::Exceptions::MissingArgument('Backup file');

    validate_with ( params => [%options],
            spec => {
                progress    => {
                    optional => 1,
                    isa => 'EBox::ProgressIndicator',
                },
                modsToRestore => {
                    type => ARRAYREF,
                    optional => 1,
                },
                fullRestore => { default => 0 },
                dataRestore    => {
                    default => 0 ,
                    # incompatible with fullRestore ..
                    callbacks => {
                        incompatibleRestores =>
                            sub {
                                (not $_[0]) or (not $_[1]->{fullRestore})
                            },
                    },
                },
                forceDependencies => {default => 0 },
                deleteBackup      => { default => 0},
                revokeAllOnModuleFail =>  { default => 1},
                continueOnModuleFail =>  { default => 0},
            }
    );

    my $progress = $options{progress};
    if (not $progress) {
        $progress = EBox::ProgressIndicator::Dummy->create;
        $options{progress} = $progress;
    }

    # EBox::debug("restore backup id: " . $progress->id);
    $progress->started or
        throw EBox::Exceptions::Internal("ProgressIndicator's executable has not been run");

    my $tempdir;
    try {
        _ensureBackupdirExistence();

        $self->_checkSize($file);

        $tempdir = $self->_unpackAndVerify($file, $options{fullRestore});

        $self->_unpackModulesRestoreData($tempdir);

        $self->_restoreEBoxEtcFiles($tempdir);

        # TODO: Make sure we don't open the file more than necessary
        $self->_preRestoreActions($file);

        my @modules  = @{ $self->_modInstancesForRestore($file, %options) };
        my @restored = ();

        # run pre-checks
        foreach my $mod (@modules) {
            $self->_restoreModulePreCheck($mod, $tempdir, \%options);
        }

        try {
            foreach my $mod (@modules) {
                my $restoreOk;
                try {
                    $restoreOk = $self->_restoreModule($mod, $tempdir, \%options);
                } otherwise {
                    my ($ex) = @_;

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
                }

            }
        }
        otherwise {
            my $ex = shift;

            my $errorMsg = 'Error while restoring: ' . $ex->text();
            EBox::error($errorMsg);
            $progress->setAsFinished(1, $errorMsg);

            if ($options{revokeAllOnModuleFail}) {
                $self->_revokeRestore(\@restored);
            }

            throw $ex;
        };

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
            EBox::info("Restore finished. Not all modules have been successfuly restored. Modules which were restored without errors: @restored");
        }

        $progress->setAsFinished();
    }
    finally {
        if ($tempdir) {
            system "rm -rf '$tempdir'";
        }
        if ($options{deleteBackup}) {
            unlink $file;
        }
    };
}


sub _unpackModulesRestoreData
{
    my ($self, $tempdir) = @_;

    my $unpackCmd = "tar xzf '$tempdir/eboxbackup/files.tgz' -C '$tempdir/eboxbackup'";

    system $unpackCmd;

    if ($? != 0) {
        system "rm -rf '$tempdir'";
        throw EBox::Exceptions::External(
                __('Could not unpack the backup')
                );
    }
}

sub _restoreEBoxEtcFiles
{
    my ($self, $tempdir) = @_;
    my $archive = "$tempdir/eboxbackup/etcFiles.tgz";
    if (not -f $archive) {
        EBox::warn("eBox's /etc files archive not found; not restoring them" );
        return;
    }

    my $tmpEtc = "$tempdir/etc";
    mkdir $tmpEtc;

    my $unpackCmd = "tar xzf '$archive' -C '$tmpEtc'";
    system $unpackCmd;

    if ($? != 0) {
        system "rm -rf '$tmpEtc'";
        throw EBox::Exceptions::External(
                __('Could not unpack the etc files archive backup')
                );
    }

    my $etc   = EBox::Config::etc();

    # create backup for files/directories to be replaced
    my @filesToBackup = glob("$etc*.conf");
    push @filesToBackup, (
            "${etc}hooks",
            "${etc}post-save",
            "${etc}pre-save",
            );

    foreach my $file (@filesToBackup) {
        my $backupFile = _backupName($file);
        try {
            EBox::Sudo::root("mv --force '$file' '$backupFile'");
        } catch EBox::Exceptions::Sudo::Command with {
            # no backup is a non-fatal error
            EBox::error("Could not create backup of file $file as $backupFile: $!");
        };
    }

    # put restored files in place
    try {
        # It is mandatory to overwrite the changes
        # We must use install instead of mv -f
        # Install cmds
        my @cmds;
        push(@cmds, "install -m 0644 -t $etc $tmpEtc/*.conf");
        push(@cmds, "mv -f $tmpEtc/hooks $tmpEtc/post-save $tmpEtc/pre-save $etc");
        EBox::Sudo::root(@cmds);
    }  catch EBox::Exceptions::Sudo::Command with {
        # continue with the restore anyway
        EBox::error("Cannot restore $etc files: $!");
    };
}

# Select a backup file name for a given path
sub _backupName
{
    my ($path) = @_;

    my $backupPath;
    my $count = 0;
    my $maxBackupCopies = 100;
    while ($count < $maxBackupCopies) {
        $backupPath = $path . ".old";
        if ($count > 0) {
            $backupPath .= ".$count";
        }
        unless (-e $backupPath) {
            return $backupPath;
        }

        $count +=1;
    }

    return $backupPath;
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
    $progress->notifyTick();
    $progress->setMessage($modname);

    if (not -e "$tempdir/eboxbackup/$modname.bak") {
        EBox::error("Restore data not found for module $modname. Skipping $modname restore");
        return 0;
    }

    EBox::debug("Restoring $modname from backup data");
    $mod->setAsChanged(); # we set as changed first because it is not
        # guaranteed that a failed backup will not
        # change state
        $mod->restoreBackup("$tempdir/eboxbackup",
                fullRestore => $options_r->{fullRestore},
                dataRestore => $options_r->{dataRestore},
                );

    $self->_migratePackage($mod->package());

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
            # XXX remember no-gconf changes are not revoked!
            EBox::debug("Revoked changes in $restname module");
        }
        otherwise {
            EBox::debug("$restname has not changes to be revoked" );
        };
    }
}

sub _migratePackage
{
    my ($self, $package) = @_;
    my $migrationdir = EBox::Config::share() . "/$package/migration";

    if (-d $migrationdir) {
        my $migration = EBox::Config::pkgdata() . '/ebox-migrate';
        try {
            EBox::Sudo::command("$migration $migrationdir");
        } catch EBox::Exceptions::Internal with {
            EBox::debug("Failed to migrate $package");
        };
    }
}

sub _preRestoreActions
{
    my ($self, $archive) = @_;

    my $global = EBox::Global->getInstance();
    my @inBackup = @{ $self->_modulesInBackup($archive) };

    my @missing;
    foreach my $modName (@inBackup) {
        # Skip cloud-prof to check in restore since it is possible not
        # to be installed until the first restore process is done (DR)
        next if ($modName eq 'cloud-prof');
        unless ($global->modExists($modName)) {
            push (@missing, $modName);
        }
    }
    if (@missing) {
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
                $mod->setConfigured(1);
                $mod->enableService(1);
                try {
                    EBox::info("Configuring previously unconfigured module $name present in the backup to restore");
                    $mod->enableActions();
                } otherwise {
                    my ($ex) = @_;
                    my $err = $ex->text();
                    $mod->setConfigured(0);
                    $mod->enableService(0);
                    throw EBox::Exceptions::Internal(
                        __x('Cannot restore backup, error enabling module {m}: {err}',
                            'm' => $name, 'err' => $err)
                    );
                };
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
        }

        # we use the module list instead of the full list of backup's module
        $anyModuleInBackup = any @modsToRestore;
    }

    # we restore the intersection between the installed modules AND the modules in
    # the backup archive
    @modules = grep {
        $_->name eq $anyModuleInBackup
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

    my $tempDir = $self->_unpackArchive($archive, 'modules');
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

#  Function: _facilitiesForDiskUsage
#  Overrides: EBox::Report::DiskUsageProvider::_faciltiesForDiskUsage
sub _facilitiesForDiskUsage
{
    return { __(q{Backup archives}) => [ backupDir() ] }
}

1;
