# Copyright (C) 2005 Warp Netwoks S.L.

package EBox::DBEngineFactory;

use strict;
use warnings;

use EBox;
use EBox::PgDBEngine;

sub DBEngine 
{
	return new EBox::PgDBEngine;
}

1;
