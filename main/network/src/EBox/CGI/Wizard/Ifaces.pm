# Copyright (C) 2010-2012 Zentyal S.L.
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

package EBox::CGI::Network::Wizard::Ifaces;

use strict;
use warnings;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use Error qw(:try);

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


sub _processWizard
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');

    my $interfaces = $net->get_hash('interfaces');
    foreach my $iface ( @{$net->ifaces()} ) {
        my $scope = $self->param($iface . '_scope');

        if ( $net->ifaceExists($iface) ) {
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
