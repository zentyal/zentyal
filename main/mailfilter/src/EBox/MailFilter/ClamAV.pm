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

package EBox::MailFilter::ClamAV;

# package:

use Perl6::Junction qw(any all);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Gettext;
use EBox::Global;

use EBox::MailFilter::VDomainsLdap;

sub new
{
    my $class = shift @_;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub _mailfilterModule
{
    return EBox::Global->modInstance('mailfilter');
}

sub setVDomainService
{
    my ($self, $vdomain, $service) = @_;

    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
    $vdomainsLdap->checkVDomainExists($vdomain);
    $vdomainsLdap->setAntivirus($vdomain, $service);
}

sub vdomainService
{
    my ($self, $vdomain) = @_;

    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
    $vdomainsLdap->checkVDomainExists($vdomain);
    $vdomainsLdap->antivirus($vdomain);
}

1;
