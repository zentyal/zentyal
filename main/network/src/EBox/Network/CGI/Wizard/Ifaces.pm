# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Network::CGI::Wizard::Ifaces;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use EBox::Exceptions::External;
use TryCatch;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'network/wizard/interfaces.mas',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _masonParameters
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');

    my @params = ();
    push (@params, 'ifaces' => $net->ifaces());
    return \@params;
}

sub _process
{
    my $self = shift;
    $self->{params} = $self->_masonParameters();

    my $net = EBox::Global->modInstance('network');

    my $iface = $self->param('iface');
    if ($iface) {
        if ($net->externalConnectionWarning($iface, $self->request())) {
            $self->{json} = { success => 0, error =>__x('You are connecting to Zentyal through the {i} interface. If you set it as external the firewall will lock you out during the installation.', i => $iface) };
        } else {
            $self->{json} = { success => 1 };
        }
        return;
    }

    my $request = $self->request();
    if ($request->method() eq 'POST') {
        $self->_processWizard();
    }
}

sub _processWizard
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');

    my $interfaces = $net->get_hash('interfaces');
    foreach my $iface ( @{$net->ifaces()} ) {
        my $scope = $self->param($iface . '_scope');

        if ($net->ifaceExists($iface)) {
            my $isExternal = 0;
            if ($scope eq 'external') {
                $isExternal = 1;
            }
            $interfaces->{$iface}->{external} = $isExternal;
        }
    }
    $net->set('interfaces', $interfaces);
}

1;
