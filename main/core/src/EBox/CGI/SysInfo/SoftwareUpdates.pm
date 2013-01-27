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

package EBox::CGI::SysInfo::SoftwareUpdates;

use strict;
use warnings;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;

use Error qw(:try);

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

    my $qaUpdates = 0;
    my $ignore = EBox::Config::boolean('widget_ignore_updates');

    my $url = 'http://update.zentyal.org/updates';
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $qaUpdates = $rs->subscriptionLevel() > 0;
    }

    my $updatesStr  = __('No updates');
    my $updatesType = 'good';
    if ($qaUpdates) {
        my $msg = $self->_secureMsg();
        $updatesStr = qq{<a title="$msg">$updatesStr</a>};
    } else {
        my $onlyComp = 0;
        # [ updates, sec_updates]
        my $updates = EBox::Util::Software::upgradablePkgsNum();
        if ( $updates->[1] > 0 ) {
            $updatesType = 'error';
            $updatesStr = __x('{n} security updates', n => $updates->[1]);
        } elsif ( $updates->[0] > 0 ) {
            $updatesType = 'warning';
            $updatesStr = __x('{n} system updates', n => $updates->[0]);
            my $pkgsToUpgrade = EBox::Util::Software::upgradablePkgs();
            my $nonCompNum = grep { $_ !~ /^zentyal-/ } @{$pkgsToUpgrade};
            if ( $nonCompNum == 0 ) {
                # Only components, then show components
                $updatesStr = __x('{n} component updates', n => $updates->[0]);
                $onlyComp = 1;
            }
        }
        my $href = $url;
        if (EBox::Global->modExists('software')) {
            if ($onlyComp) {
                $href = '/Software/EBox#update';
            } else {
                $href = '/Software/Updates';
            }
        }
        unless ($ignore) {
            my $msg = $self->_commercialMsg();
            $updatesStr = qq{<a href="$href" title="$msg">$updatesStr</a>};
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
    return __s('Warning: These are untested community updates that might harm your system. In production environments we recommend using the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch}: commercial Zentyal server editions fully supported by Zentyal S.L. and Canonical/Ubuntu.');
}

sub _secureMsg
{
    return __s('Your commercial server edition guarantees that these are quality assured software updates and will be automatically applied to your system.');
}

1;
