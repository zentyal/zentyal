# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::MailFilter::Test;

use base 'Test::Class';

# package:

use EBox::Global::TestStub;
use EBox::Module::Config::TestStub;

use Test::Exception;
use Test::More;

sub setUpConfiguration : Test(startup)
{
    my ($self) = @_;

    EBox::Global::TestStub::fake();
}

sub clearConfiguration : Test(teardown)
{
    EBox::Module::Config::TestStub::setConfig();
}

sub mailfilter_use_ok: Test
{
     use_ok('EBox::MailFilter') or die;
}

1;
