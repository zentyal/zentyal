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

use lib '../../src';

#use Test::More qw(no_plan);
use Test::More skip_all => 'FIXME';

use EBox::Test::Mason;

my @cases = (
             [
              users => {},
             ],
             [
              users => {
                        macaco => 1,
                        bee    => 2,
                        mandrill => 1,
                       }
             ],
);

my $template = '../filtergroupslist.mas';
foreach my $case (@cases) {
    EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $case);
}

1;
