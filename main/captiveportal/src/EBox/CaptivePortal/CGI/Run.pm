# Copyright (C) 2012-2014 Zentyal S.L.
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

use EBox;
use EBox::CaptivePortal::CGI::Login;

use TryCatch::Lite;

# Method: run
#
#    Run the given URL and returns the HTML output. This is the Zentyal
#    Web UI core indeed. This version removes the redis transactions from the parent class.
#
# Parameters:
#
#    request    - Plack::Request object.
#    htmlblocks - *optional* Custom HtmlBlocks package
#
sub run
{
    my ($self, $request, $htmlblocks) = @_;

    unless (defined $request) {
        throw EBox::Exceptions::InvalidArgument('request');
    }

    my $url = $self->urlFromRequest($request);

    try {
        my $handler;
        my @extraParams = (request => $request);
        if ($htmlblocks) {
            push (@extraParams, htmlblocks => $htmlblocks);
        }
        my $classname = $self->urlToClass($url);
        eval "use $classname";
        if ($@) {
            my $log = EBox::logger();
            $log->error("Unable to load CGI: URL=$url CLASS=$classname ERROR: $@");

            $handler = new EBox::CaptivePortal::CGI::Login(@extraParams);
        } else {
            $handler = new $classname(@extraParams);
        }

        $handler->run();
        return $handler->response()->finalize();
    } catch ($ex) {
        # Base exceptions are already logged, log the rest
        unless (ref ($ex) and $ex->isa('EBox::Exceptions::Base')) {
            EBox::error("Exception trying to access $url: $ex");
        }
        $ex->throw();
    }
}

# Method: urlToClass
#
#  Returns CGI class for the given URL
#
# Overrides: <EBox::CGI::Run::urlToClass>
#
sub urlToClass
{
    my ($self, $url) = @_;

    unless ($url) {
        return 'EBox::CaptivePortal::CGI::Dashboard::Index';
    }

    my @parts = split('/', $url);
    # filter '' and undef
    @parts = grep { $_ } @parts;

    return 'EBox::CaptivePortal::CGI::' . join('::', @parts);
}

1;
