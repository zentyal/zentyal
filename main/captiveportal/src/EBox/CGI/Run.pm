# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::CGI::CaptivePortal::Run;

use strict;
use warnings;

use base 'EBox::CGI::Run';

use Error qw(:try);
use EBox;

use EBox::CaptivePortal::CGI::Login;


# this is the same version of EBox::CGI::Run::run() but without redis transactions
sub run # (url, namespace)
{
    my ($self, $url, $namespace) = @_;

    my $classname =  EBox::CGI::Run::classFromUrl($url, $namespace);

    my $cgi;
    eval "use $classname";
    if ($@) {
        try{
            $cgi = EBox::CGI::Run::_lookupViewController($classname, $namespace);
        }  catch EBox::Exceptions::DataNotFound with {
            # path not valid
            $cgi = undef;
        };

        if (not $cgi) {
            my $log = EBox::logger;
            $log->error("Unable to import cgi: "
                            . "$classname Eval error: $@");

#            my $error_cgi = 'EBox::CGI::PageNotFound';

#            my $error_cgi = 'EBox::CaptivePortal::CGI::Login';
#            eval "use $error_cgi";
#            $cgi = $error_cgi->new('namespace' => $namespace);
             $cgi = EBox::CaptivePortal::CGI::Login->new(namespace => $namespace);
        }
    } else {
        $cgi = new $classname();
    }

    $cgi->run();
}


1;
