package EBox::Backup::TarArchive;
# Module to handle an already-created backup in tar.gz format
use strict;
use warnings;

use Cwd;
use Error qw(:try);
use EBox::Gettext;

sub restore
{
  my %params = @_;

  my $archiveFile = $params{archiveFile};
  (-e $archiveFile) or throw EBox::Exceptions::External(__x('Archive file {file} not found ', file => $archiveFile));
  my $fromDir     = exists $params{fromDir} ? $params{fromDir} : '/';

  my $cwd = cwd();
  try {
    my $tarCommand =  "/bin/tar -x -z -C $fromDir  -f$archiveFile";
    my @output = `$tarCommand`;
    if ($? != 0) {
      throw EBox::Exceptions::External(__x('Extraction of archive file {file} failed. Output: {output}', file => $archiveFile, output => "@output"))
    }
  }
  finally {
    chdir $cwd;
  };
}

sub selectArchiveFromDir
{
  my ($dir) = @_;
  (-d $dir) or throw EBox::Exceptions::External(__x("Incorrect directory {dir}", dir => $dir));
  

  my $lsCommand = "/bin/ls -1 $dir/*-ebox-backup-*.tar.gz";
  my @candidates = `$lsCommand`;
  ($? == 0)         or throw EBox::Exceptions::Internal("Command $lsCommand failed. Output: @candidates");
  (@candidates > 0) or throw EBox::Exceptions::External(__("None archive file found"));

  @candidates = sort @candidates; # due to embedded date in file name this sort ascending by date
  my $archiveFile = pop @candidates;
  defined $archiveFile or throw EBox::Exceptions::Internal('Undefined archive file variable');
  chomp $archiveFile;

  return $archiveFile;
}
 
sub restoreFromDir
{
  my %params = @_;
  my $dir = delete $params{dir};
  my $archiveFile = selectArchiveFromDir($dir);
  return restore(archiveFile => $archiveFile);
}

1;
