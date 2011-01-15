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
use Linux::Inotify2;
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
    try {
        print $sock "$$:$filename:$args\n";
        #DEBUG: print "$0 ($$): sent: $$:$filename\n";
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

    my $outfile = "/tmp/fastperl-$$.out";
    my $errfile = "/tmp/fastperl-$$.err";
    my ($out, $err);

    # FIXME: Replace all calls to die with EBox::error() and return 0
    my $inotify = new Linux::Inotify2() or
        die "Cannot create inotify object: $!";

    my $dir = dirname($outfile);
    $inotify->watch($dir, IN_CREATE) or
        die "$dir watch creation failed";

    my $readout = 1;
    my $readerr = 1;
    while ($readout and $readerr) {
        my @events = $inotify->read();
        foreach my $e (@events) {
            my $file = $e->fullname();
            if ($e->IN_CREATE) {
                if ($file eq any($outfile, $errfile)) {
                    #DEBUG: print "WATCHING $file\n";
                    $inotify->watch($file, IN_MODIFY | IN_CLOSE) or
                        die "$file watch creation failed";

                    if ($file eq $outfile) {
                        open ($out, '<', $outfile) or
                            die "open $outfile failed";
                    } else {
                        open ($err, '<', $errfile) or
                            die "open $errfile failed";
                    }
                }
            } elsif ($e->IN_MODIFY) {
                if ($file eq $outfile) {
                    my @lines = <$out>;
                    print @lines;
                } elsif ($file eq $errfile) {
                    my @lines = <$err>;
                    print STDERR @lines;
                }
            } else {
                #DEBUG: print "$file CLOSED\n";
                if ($file eq $outfile) {
                    close ($out);
                    unlink ($outfile);
                    $readout = 0;
                } elsif ($file eq $errfile) {
                    close ($err);
                    unlink ($errfile);
                    $readerr = 0;
                }
            }
        }
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
