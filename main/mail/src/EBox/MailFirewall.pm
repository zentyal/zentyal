# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::MailFirewall;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Config;
use EBox::Mail;
use EBox::Gettext;
use EBox::Validate qw( :all );

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub output
{
    my $self = shift;
    my @rules = ();

    my $net = EBox::Global->modInstance('network');
    my $mail = EBox::Global->modInstance('mail');

    my @ifaces = @{$net->InternalIfaces()};
    my @exifaces = @{$net->ExternalIfaces()};
    my $port = $mail->portfilter();
    my $ipfilter = $mail->ipfilter();
    my @conf = ();
    my $r;

    if (($mail->service()) and ($mail->service('filter'))) {
        foreach my $ifc (@ifaces) {
            @conf = @{$net->ifaceAddresses($ifc)};
            my $output = $self->_outputIface($ifc);

            foreach my $c (@conf) {
                if(isIPInNetwork($$c{'address'},
                            $$c{'netmask'},
                            $mail->ipfilter())) {

                    $r = "-d $ipfilter -m state --state NEW $output ".
                        "-p tcp --dport $port -j oaccept";

                    push(@rules, $r);
                }
            }
        }
    }
    if ($mail->service()) {
        $r = "-m state --state NEW -p tcp --dport 25 -j oaccept";
        push(@rules, $r);
    }

    return \@rules;
}

1;
