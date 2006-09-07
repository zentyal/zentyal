package EBox::Backup::Helper;
# Helper class used for modules that have special backup needs
use strict;
use warnings;

# Default backup helper constructor, override if need special parameters
sub new
{
  my ($class) = @_;
  my $self  = {};
  bless $self, $class;
  return $self;
}


sub version
{
  throw EBox::Exceptions::NotImplemented ('The EBox::Backup::Helper::version sub must be overriden to return a version identifier');
}


sub dumpConf
{
  throw EBox::Exceptions::NotImplemented ('The EBox::Backup::Helper::dump sub must be overriden');
}

sub restoreConf
{
  throw EBox::Exceptions::NotImplemented ('The EBox::Backup::Helper::rstore sub must be overriden');
}






1;
