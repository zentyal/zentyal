# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::MailFilter::FirewallHelper;

use base 'EBox::FirewallHelper';

use EBox::Exceptions::MissingArgument;
use EBox::Global;

sub new
{
    my ($class, %params) = @_;
    my $self = $class->SUPER::new(%params);

    my @paramNames = qw(smtpFilter  port externalMTAs fwport);
    foreach my $p (@paramNames) {
        exists $params{$p} or
            throw EBox::Exceptions::MissingArgument("$p");
        $self->{$p} = $params{$p};
    }

    bless($self, $class);
    return $self;
}

sub input
{
    my ($self) = @_;
    my @rules;

    if (not $self->{smtpFilter}) {
        return [];
    }

    my @externalMTAs = @{ $self->{externalMTAs} };
    if (@externalMTAs ) {
        my $port = $self->{port};
        push (@rules,
                "--protocol tcp --dport $port -j iaccept");

    }

    return \@rules;
}

sub output
{
    my ($self) = @_;
    my @rules;

    if ($self->{smtpFilter}) {
        my @externalMTAs = @{ $self->{externalMTAs} };
        if (@externalMTAs) {
            my $fwport = $self->{fwport};
            push (@rules, "--protocol tcp --dport $fwport -j oaccept");
        }
    }

    return \@rules;
}

1;
