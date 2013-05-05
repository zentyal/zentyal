# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::CaptivePortal::CGI::Run;

use base 'EBox::CGI::Run';

use Error qw(:try);
use EBox;

use EBox::CaptivePortal::CGI::Login;

# this is the same version of EBox::CGI::Run::run() but without redis transactions
sub run
{
    my ($self, $url) = @_;

    my $cgi;
    my $classname = _cgiFromUrl($url);
    eval "use $classname";
    if ($@) {
        if (not $cgi) {
            my $log = EBox::logger;
            $log->error("Unable to import cgi: $classname Eval error: $@");
            $cgi = EBox::CaptivePortal::CGI::Login->new();
        }
    } else {
        $cgi = new $classname();
    }

    $cgi->run();
}

1;
