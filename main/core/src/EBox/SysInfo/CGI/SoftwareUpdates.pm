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

package EBox::SysInfo::CGI::SoftwareUpdates;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::SysInfo;
use EBox::Sudo;

use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => 'none',
                                  'template' => 'none',
                                  @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    if (EBox::Util::Software::errorOnPkgs()) {
        $self->{json} = {
            value => __('You have broken packages installed, fix them before upgrading'),
            type => 'error',
        };
        return;
    }

    my $qaUpdates = (-f '/etc/apt/sources.list.d/zentyal-qa.list');
    my $ignore = EBox::Config::boolean('widget_ignore_updates');

    my $updatesStr = __('No updates');
    my $updatesType = 'good';
    my $reboot = '/var/run/reboot-required';
    if (-e $reboot) {
        $updatesStr.= ' ' . __('Nevertheless some packages require a reboot to be applied');
        $updatesType = 'warning';
    }
    if ($qaUpdates) {
        my $msg = $self->_secureMsg();
        $updatesStr = qq{<a title="$msg">$updatesStr</a>};
    } elsif (not $ignore) {
        my $msg = $self->_commercialMsg();

        # This fixes wrong information of apt-check
        EBox::Sudo::silentRoot('dpkg --clear-avail');

        my ($nUpdates, $nSecurity) = @{EBox::Util::Software::upgradablePkgsNum()};
        my $softwareInstalled = EBox::Global->modExists('software');
        my $defaultURL = EBox::SysInfo->UPDATES_URL();

        if ($nUpdates) {
            $updatesStr = '';
            $updatesType = 'warning';
            my $nSystem = $nUpdates;

            my $pkgsToUpgrade = EBox::Util::Software::upgradablePkgs();
            my $nZentyal = grep { $_ =~ /^zentyal-/ } @{$pkgsToUpgrade};
            if ($nZentyal) {
                $nSystem -= $nZentyal;
                my $href = $softwareInstalled ? '/Software/EBox#update' : $defaultURL;
                $updatesStr .= qq{<a href="$href" title="$msg">} . __x('{n} component updates', n => $nZentyal) . '</a>';
                if ($nSystem) {
                    $updatesStr .= ', ';
                }
            }

            if ($nSystem) {
                my $href = $softwareInstalled ? '/Software/Updates' : $defaultURL;
                $updatesStr .= qq{<a href="$href" title="$msg">} . __x('{n} system updates', n => $nSystem);
                if ($nSecurity) {
                    $updatesType = 'error';
                    $updatesStr .= ' ' . __x('({n} security)', n => $nSecurity);
                }
                $updatesStr .= '</a>';
            }
            if (-e $reboot) {
                $updatesStr.= ' ' . __('Moreover, some upgraded packages require a reboot to take effect');
            }
        }
    }

    $self->{json} = {
        value => $updatesStr,
        type => $updatesType,
    };
}

# Return commercial message for QA updates
sub _commercialMsg
{
    return __s('Warning: These are untested community updates that might harm your system. In production environments we recommend using the Commercial Zentyal Server Edition.');
}

sub _secureMsg
{
    return __s('Your commercial server edition guarantees that these are quality assured software updates and will be automatically applied to your system.');
}

1;
