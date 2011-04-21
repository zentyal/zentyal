# Copyright (C) 2010 eBox Technologies S.L.
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
use EBox::Sudo;
use Error qw(:try);
use Date::Parse;

sub restoreEBoxLogs
{
    my ($date, $urlParams) = @_;
    defined $urlParams or
        $urlParams = {};

    my $ebackup = EBox::Global->modInstance('ebackup');
    my $dumpDir = backupDir();
    my $dumpDirTmp = EBox::Config::tmp() . 'eboxlogs.restore';
    EBox::Sudo::root("rm -rf $dumpDirTmp");
    mkdir ($dumpDirTmp) or
        throw EBox::Exceptions::Internal("Cannot create dir $dumpDirTmp");

    try {
        $ebackup->restoreFile($dumpDir, $date, $dumpDirTmp, $urlParams);
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

    restoreEBoxLogsFromDir($dumpDirTmp, $date);
    EBox::Sudo::root("rm -rf $dumpDirTmp");
}


sub restoreEBoxLogsFromDir
{
    my ($dir, $date) = @_;
    # convert date to timestamp, needed for sliced restore
    my $dateEpoch = str2time($date);

    my $dbengine = EBox::DBEngineFactory::DBEngine();
    my $basename = dumpBasename();
    $dbengine->restoreDB($dir, $basename, toDate => $dateEpoch);
}


sub backupDir
{
    return  EBox::EBackup::extraDataDir() .  "/logs";
}

sub dumpBasename
{
    return 'eboxlogs';
}

1;
