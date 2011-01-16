# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::FastPerl;

use warnings;
use strict;

use IO::Socket::UNIX;
use Socket::PassAccessRights;
use File::Basename;
use Perl6::Junction qw(any);
use FindBin qw($Bin $Script);
use Error qw(:try);

# Method: init
#
#       Tries to connect to the zentyal.fastperl server in order
#       to execute the current script on a single Perl interpreter
#
# Returns:
#
#       boolean - true if executed in single interpreter, 0 otherwise
#
sub init
{
    return 1 if $ENV{SINGLE_INTERP};

    # FIXME: Replace all /tmp paths with EBox::Config::tmp()
    my $SOCKET_FILE = '/tmp/singleperl.sock';

    my $filename = "$Bin/$Script";
    my @quotedArgs = map { "\"$_\"" } @ARGV;
    # FIXME: This could be problematic if args contain ':'
    my $args = join (':', @quotedArgs);

    STDOUT->autoflush(1);
    STDERR->autoflush(1);

    my $failed = 0;

    local $SIG{PIPE} = sub {
        $failed = 1;
        #DEBUG: print "$0 ($$): SIGPIPE received\n";
    };

    my $sock = new IO::Socket::UNIX(Peer => $SOCKET_FILE,
                                    Timeout => 0, # FIXME: change this?
                                    Type => SOCK_STREAM) or return 0;

    # TODO: Handle this better
    Socket::PassAccessRights::sendfd(fileno($sock), fileno(STDOUT))
        or die "sendfd(STDOUT) failed: $!";
    Socket::PassAccessRights::sendfd(fileno($sock), fileno(STDERR))
        or die "sendfd(STDERR) failed: $!";

    try {
        print $sock "$filename:$args\n";
        #DEBUG: print "$0 ($$): sent: $filename:$args\n";
    } otherwise {
        # TODO: log this
        #DEBUG: print "$0 ($$): write to socket failed\n";
        $failed = 1;
    };

    if ($failed) {
        close $sock;
        # Run it in the classical way
        return 0;
    }

    my $buf = scalar <$sock>;
    unless (defined $buf) {
        close $sock;
        return 0;
    }
    chomp $buf;
    # DEBUG: print "$0 ($$): received: $buf\n";
    my $exitValue = $buf;

    close $sock;

    exit $exitValue;
}

1;
