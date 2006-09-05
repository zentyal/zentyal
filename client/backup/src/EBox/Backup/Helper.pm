package EBox::Backup::Helper;
# Description: Helper class used for modules that have special backup needs
use strict;
use warnings;


sub version
{
  throw EBox::Exceptions::Internal ('The EBox::Backup::Helper::version sub must be overriden to return a version identifier');
}


sub dumpConf
{
  throw EBox::Exceptions::Internal ('The EBox::Backup::Helper::dump sub must be overriden');
}

sub restoreConf
{
  throw EBox::Exceptions::Internal ('The EBox::Backup::Helper::rstore sub must be overriden');
}


sub files
{
  throw EBox::Exceptions::Internal ('The EBox::Backup::Helper::files sub must be overriden');
}





1;
