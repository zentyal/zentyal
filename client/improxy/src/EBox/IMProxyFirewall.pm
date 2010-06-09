# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::IMProxyFirewall;
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Gettext;

sub new
{
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);
        bless($self, $class);
        return $self;
}

sub prerouting
{
	my ($self) = @_;
	my @rules = ();

    my @ports;
    push(@ports, 1863); #msn
    push(@ports, 5222); #jabber
    push(@ports, 5223); #jabber-ssl
    push(@ports, 5190); #icq/aim
    push(@ports, 5050); #yahoo
    push(@ports, 6667); #irc
    push(@ports, 8074); #gadu-gadu

    foreach my $port (@ports) {
		my $r = "-p tcp --dport $port -j REDIRECT --to-ports 16667";
		push(@rules, $r);
    }
	return \@rules;
}

1;
