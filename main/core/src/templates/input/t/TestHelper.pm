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

package TestHelper;

use strict;
use warnings;

use EBox::Test::Mason;
use File::Basename;
use Cwd;
use Test::More;

sub testComponent
{
  my ($component, $cases_r, $printOutput) = @_;
  defined $printOutput or $printOutput = 0;

  my ($componentWoExt) = split '\.', (basename $component);
  my $outputFile  = "/tmp/$componentWoExt.html";
  system "rm -rf $outputFile";

  my $compRoot =   dirname dirname getcwd(); # XXX this is templates/input directory specific
  my $template =   (dirname getcwd()) . "/$component";

  diag "\nComponent root $compRoot\n\n";

  foreach my $params (@{ $cases_r }) {
    EBox::Test::Mason::checkTemplateExecution(template => $template, templateParams => $params, compRoot => [$compRoot], printOutput => $printOutput, outputFile => $outputFile);
  }


}

1;
