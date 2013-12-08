# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::Reporter::EBackupSettings;

# Class: EBox::Reporter::EBackupSettings
#
#      Perform the ebackup settings (backup domains and settings)
#      consolidation
#

use warnings;
use strict;

use base 'EBox::Reporter::Base';

use EBox::Global;
use POSIX;

# Method: enabled
#
#      Overrided to return values only if configuration is completed
#
# Overrides:
#
#      <EBox::Reporter::Base::enabled>
#
sub enabled
{
    my ($self) = @_;

    my $enabled = $self->SUPER::enabled();
    if ( $enabled ) {
        my $ebackup = EBox::Global->getInstance(1)->modInstance('ebackup');
        $enabled = ($ebackup->configurationIsComplete());
    }
    return $enabled;
}

# Method: module
#
# Overrides:
#
#      <EBox::Reporter::Base::module>
#
sub module
{
    return 'ebackup';
}

# Method: name
#
# Overrides:
#
#      <EBox::Reporter::Base::name>
#
sub name
{
    return 'ebackup_settings';
}

# Group: Protected methods

# Method: _consolidate
#
# Overrides:
#
#     <EBox::Exceptions::Reporter::Base::_consolidate>
#
sub _consolidate
{
    my ($self, $begin, $end) = @_;

    my $ebackup = EBox::Global->getInstance(1)->modInstance('ebackup');

    my $res = {};
    $res->{backup_domains} = $ebackup->model('BackupDomains')->report();
    my $settings = $ebackup->model('RemoteSettings')->report();
    foreach my $k (keys(%{$settings})) {
        $res->{$k} = $settings->{$k};
    }
    $res->{hour} = POSIX::strftime("%Y-%m-%d %H:00:00", localtime(time()));
    return [ $res ];
}

1;
