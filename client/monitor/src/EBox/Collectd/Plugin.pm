# Copyright 2008 (C) eBox Technologies S.L.
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

# Class: EBox::Collectd::Plugin
#
#    Add the eBox own plugin to collectd.
#
#    Documentation is available on:
#
#     http://collectd.org/documentation/manpages/collectd-perl.5.shtml
#

package EBox::Collectd::Plugin;

use strict;
use warnings;

# Core
#use Errno;
#use Fcntl;

# External uses
use File::Temp;
use Collectd qw(:all);
use Data::Dumper;

# Constants
# Set it fixed not to include eBox packages
use constant EVENTS_INCOMING_DIR       => '/var/run/ebox/events/incoming/';
use constant EVENTS_INCOMING_READY_DIR => EVENTS_INCOMING_DIR . 'ready/';
use constant EVENTS_FIFO               => '/var/lib/ebox/tmp/events-fifo';
use constant EBOX_USER                 => 'ebox';

plugin_register(TYPE_NOTIF, 'plugin', 'ebox_notify');

# Procedure: ebox_notify
#
#     Dispatch a notification to the eBox system using FIFO, if
#     possible, if not, using a directory
#
# Parameters:
#
#     notification - hash ref with the following elements:
#         severity => NOTIF_FAILURE || NOTIF_WARNING || NOTIF_OKAY,
#         time     => time (),
#         message  => 'status message',
#         host     => $hostname_g,
#         plugin   => 'myplugin',
#         type     => 'mytype',
#         plugin_instance => '',
#         type_instance   => ''
#
sub ebox_notify
{
    my ($not) = @_;

    my $src = 'monitor-' . $not->{plugin};
    $src .= '-' . $not->{plugin_instance} if ($not->{plugin_instance} ne '');
    $src .= '-' . $not->{type};
    $src .= '-' . $not->{type_instance} if ($not->{type_instance} ne '');

    my $level = 'fatal';
    if ( $not->{severity} == NOTIF_FAILURE ) {
        $level = 'error';
    } elsif ( $not->{severity} == NOTIF_WARNING ) {
        $level = 'warn';
    } else {
        $level = 'info';
    }

    my $evt = {
        message => $not->{message},
        source  => $src,
        level   => $level,
        timestamp => $not->{time}
       };

    # Dumpered event without newline chars
    my $strEvt = Dumper($evt);
    $strEvt =~ s:\n::g;
    $strEvt .= "\n";
    # Unbuffered I/0 (Not used for now)
#     my $rv = sysopen(my $fifo, EVENTS_FIFO, O_NONBLOCK|O_WRONLY);
#     if (not defined($rv)) {
#         _notifyUsingFS($strEvt);
#         return 1;
#     }
#     $rv = syswrite($fifo, $strEvt, length($strEvt));
#     if ( (! defined($rv) and $!{EAGAIN}) or ($rv != length($strEvt))) {
#         # The syscall would block
#         _notifyUsingFS($strEvt);
#     }
#     close($fifo);

    _notifyUsingFS($strEvt);

    return 1;

}

# Group: Private procedures
sub _notifyUsingFS
{
    my ($strEvt) = @_;

    my $fileTemp = new File::Temp(TEMPLATE => 'evt_XXXXX',
                                  DIR      => EVENTS_INCOMING_DIR,
                                  UNLINK   => 0);
    print $fileTemp $strEvt;
    # Make files readable by eBox
#    my ($login, $pass, $uid, $gid) = getpwnam(EBox::Config::user());
    my ($login, $pass, $uid, $gid) = getpwnam(EBOX_USER);
    chown($uid, $gid , $fileTemp->filename());
    my ($basename) = ($fileTemp->filename() =~ m:.*/(.*)$:g);
    symlink($fileTemp->filename(), EVENTS_INCOMING_READY_DIR . $basename);

}

1;
