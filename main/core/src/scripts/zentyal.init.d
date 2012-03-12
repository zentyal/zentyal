#!/usr/bin/perl
### BEGIN INIT INFO
# Provides:          zentyal
# Required-Start:    $network
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Zentyal (Small Business Server)
### END INIT INFO

use strict;
use warnings;

use EBox;
use EBox::Util::Init;

EBox::init();

EBox::Util::Init::cleanTmpOnBoot();

$SIG{PIPE} = 'IGNORE';

sub usage {
	print "Usage: $0 start|stop|restart\n";
	print "       $0 <module> start|stop|status|enabled|restart\n";
	exit 1;
}

sub main
{
    if (@ARGV == 1) {
        if ($ARGV[0] eq 'start') {
            EBox::Util::Init::start();
        }
        elsif ($ARGV[0] eq 'restart') {
            EBox::Util::Init::stop();
            EBox::Util::Init::start();
        }
        elsif ($ARGV[0] eq 'force-reload') {
            EBox::Util::Init::stop();
            EBox::Util::Init::start();
        }
        elsif ($ARGV[0] eq 'stop') {
            EBox::Util::Init::stop();
        } else {
            usage();
        }
    }
    elsif (@ARGV == 2) {
        # action upon one module mode
        my ($modName, $action) = @ARGV;

        if (($action eq 'restart') or ($action eq 'start')) {
            EBox::Util::Init::moduleRestart($modName);
        }
        elsif ($action eq 'stop') {
            EBox::Util::Init::moduleStop($modName);
        } elsif ($action eq 'status' or $action eq 'enabled') {
            # FIXME: Separate enabled and status actions
            EBox::Util::Init::status($modName);
        } else {
            usage();
        }
    } else {
        usage();
    }
}

main();

1;
