# Copyright (C) 2010 EBox Technologies S.L.
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


package EBox::EBackup::DBRestore;

use EBox::DBEngineFactory;
use EBox::EBackup;
use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use Error qw(:try);
use Date::Parse;

sub restoreEBoxLogs
{
    my ($date) = @_;

    # convert date to timespamp, needed for sliced restore
    my $dateEpoch = str2time($date);

    my $ebackup = EBox::Global->modInstance('ebackup');

    my $dbengine = EBox::DBEngineFactory::DBEngine();
    my $dumpDir =  EBox::EBackup::extraDataDir() .  "/logs";
    my $dumpDirTmp = EBox::Config::tmp() . 'eboxlogs.restore';
    my $basename = 'eboxlogs';

    try {
        $ebackup->restoreFile($dumpDir, $date, $dumpDirTmp);
    } catch EBox::Exceptions::External with {
        my $ex = shift;
        my $text = $ex->stringify();
        if ($text =~ m/not found in backup/) {
            throw EBox::Exceptions::External(__x(
'Logs backup data not found in backup for {d}. Maybe you could try another date?',
                                                 d => $date
                                                ));
        }

        $ex->throw();
    };

    $dbengine->restoreDB($dumpDirTmp, $basename, toDate => $dateEpoch);
    system "rm -rf $dumpDirTmp";
}

1;
