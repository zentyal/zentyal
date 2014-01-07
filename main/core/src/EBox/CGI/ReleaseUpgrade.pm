# Copyright (C) 2013 Zentyal S.L.
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

package EBox::CGI::ReleaseUpgrade;
use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use Error qw(:try);

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(
            'title' => __('Upgrade to Zentyal 3.3'),
            'template' => '/upgrade.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    if ($self->param('upgrade')) {
        EBox::Sudo::root('sudo sed -ri "s/zentyal(.)3.2/zentyal\13.3/g" /etc/apt/sources.list');
        EBox::Sudo::root('sudo sed -ri "/ppa.launchpad.net\/zentyal\/3.2/d" /etc/apt/sources.list');
        EBox::Sudo::root("apt-get update");
    } elsif ($self->param('install')) {
        $self->{redirect} = 'Software/InstallPkgs?install=1&pkg-zentyal-core=yes';
    }
}

sub _print
{
    my ($self) = @_;
    $self->_printPopup();
}

sub _top
{
}

sub _menu
{
}

sub _footer
{
}

1;
