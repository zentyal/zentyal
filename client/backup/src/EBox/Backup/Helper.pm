package EBox::Backup::Helper;
# Description: Helper class used for modules that need special backup treatment
use strict;
use warnings;



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
