# Copyright (C) 2010-2011 eBox Technologies S.L.
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

package EBox::Util::Nmap;


use EBox::Sudo;
use EBox::Gettext;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidData;

use Nmap::Parser;

# Function: singlePortScan
#
#     Check if the given host and port status
#
# Named parameters:
#
#     host - String the hostname
#     proto - protocol
#     port - Int the port number
#     interface - interface to use (default value: auto)
#     priviliged - use priviliged mode (default value: no)
#
# Returns:
#
#     String - the status of the port in the given host. Possible
#     values are the following:
#
#         'hostdown'      - if the host is not reachable
#         'open'          - if the port is open in that host
#         'open/filtered' - if the port is open or filtered in that host
#         Other values
#
sub singlePortScan
{
    my %args = @_;
    my $host = $args{host};
    defined $host or
        throw EBox::Exceptions::MissingArgument('host');
    my $proto = lc $args{protocol};
    if (($proto ne 'tcp') and ($proto ne 'udp')) {
        throw EBox::Exceptions::InvalidData(
                data => __('protocol'),
                value => $proto,
                advice => __(q{Only 'tcp' and 'udp' are supported}));
    }
    defined $proto or
        $proto = 'tcp';
    my $port = $args{port};
    defined $port or
        throw EBox::Exceptions::MissingArgument('port');        
    my $interface = $args{interface};
    my $privileged = $args{privileged};

    my @nmapArgs;
    if ($proto eq 'udp') {
        if (not $privileged) {
            throw EBox::Exceptions::Internal('UDP scan needs priviliged mode');
        }
        push @nmapArgs, '-sU';
    } else {
        push @nmapArgs, '-sT'; # connect scan
    }


    push @nmapArgs, "-p$port";

    if ($interface) {
        push @nmapArgs, "-e$interface";
    }
    if ($privileged) {
        push @nmapArgs, '--privileged';
    } else {
        push @nmapArgs, '--unprivileged';        
    }

    push @nmapArgs, $host;


    my $np = _nmap(@nmapArgs);

    my @hosts = $np->all_hosts(); # using all_hosts instead of get_host
                                         # to allow use hostname as argument
                                         # instead of IP, however this only
                                         # works if we have one host

    if (not @hosts) {
        throw EBox::Exceptions::External(
            __('No hosts scanned, maybe you cannot resolve DNS names?')
                                        );
    }

    if (@hosts > 1) {
        throw EBox::Exceptions::Internal('More than one host scanned');
    }

    my $hostResult = shift @hosts;

    if ($hostResult->status() ne 'up') {
        return 'hostDown';
    }

    if ($proto eq 'tcp') {
        return $hostResult->tcp_port_state($port);
    } elsif ($proto eq 'udp') {
        return $hostResult->udp_port_state($port);
    }
}


sub _nmap
{
    my @nmapArgs = @_;

    my $cmd = qq{nmap -oX - @nmapArgs};
    my $output;
    if ( grep { $_ eq '-sU' } @nmapArgs ) {
        $output = EBox::Sudo::root($cmd);
    } else {
        $output = EBox::Sudo::command($cmd);
    }

    my $nmapXml = join '', @{ $output };

    my $np = new Nmap::Parser;
    $np->parse($nmapXml);
    return $np;
}

1;
