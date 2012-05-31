#!/usr/bin/perl
# Copyright (C) 2012 eBox Technologies S.L.
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

use EBox::Gettext;
use Error qw(:try);
use POSIX qw(:signal_h);
use Devel::StackTrace;
use Data::Dumper;
use HTTP::Response;

try {
    use EBox::CGI::Run;
    use EBox;

    # Workaround to clear Apache2's process mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    EBox::init();
    EBox::CGI::Run->run('DesktopServices::Index', 'EBox');
} catch EBox::Exceptions::External with {
    my $ex = shift;
    my $trace = Devel::StackTrace->new;
    print STDERR $trace->as_string;
    print STDERR Dumper($ex);

    my $error;
    if ( $ex->can('text') ) {
        $error = $ex->text();
    } elsif ( $ex->can('as_text') ) {
        $error = $ex->as_text();
    }
    $error =~ s/"/'/g;

    print "Status: 400 Bad Request\n";
    print "Content-type: text/html\n\n";
    print '<html>';
    print '<head><title>400 Bad Request</title></head>';
    print '<body>';
    print '<h1>Error</h1>';
    print "<p>$error</p>";
    print '</body></html>';
} otherwise  {
    my $ex = shift;
    my $trace = Devel::StackTrace->new;
    print STDERR $trace->as_string;
    print STDERR Dumper($ex);

    print "Status: 500 Internal Server Error\n";
    print "Content-type: text/html\n\n";
    print '<html>';
    print '<head><title>500 Internal Server Error</title></head>';
    print '<body>';
    print '<h1>Internal Server Error</h1>';
    print '</body></html>';
};
