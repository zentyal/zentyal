package EBox::Backup::TarArchive;
# Class to handle an already-created backup in tar.gz format
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




1;
