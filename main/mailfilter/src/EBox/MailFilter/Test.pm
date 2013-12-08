# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::MailFilter::Test;
# package:
use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More;

use lib '../..';


sub setUpConfiguration : Test(setup)
{
    my ($self) = @_;

    EBox::Global::TestStub::setEBoxModule('mailfilter' => 'EBox::MailFilter');
}


sub clearConfiguration : Test(teardown)
{
    EBox::GConfModule::TestStub::setConfig();
}

sub _moduleInstantiationTest : Test
{
    EBox::Test::checkModuleInstantiation('mailfilter', 'EBox::MailFilter');
}






1;
