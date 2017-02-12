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

package EBox::AntiVirus::LogHelper;

use base 'EBox::LogHelper';

use EBox;
use Time::Piece;

use constant FRESHCLAM_STATE_FILE => '/var/log/clamav/freshclam.state';

# Method: logFiles
#
# Overrides:
#
#       <EBox::LogHelper::logFiles>
#
# Returns:
#
#       array ref - containing the whole paths
#
sub logFiles
{
    return [FRESHCLAM_STATE_FILE];
}

# Method: processLine
#
# Overrides:
#
#       <EBox::LogHelper::processLine>
#
# Parameters:
#
#       file - file name
#       line - string containing the log line
#       dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    # The file format is written by <EBox::AntiVirus::notifyFreshclamEvent
    # date,$date,update,$update,error,$error,outdated,$lastVersion

    my @fields = split(',', $line);
    my $tp     = localtime($fields[1]);
    my $event;
    $event = 'success' if ($fields[3]);
    $event = 'failure' if ($fields[5]);
    if (not $event) {
        return;
    }

    my $timestamp = $tp->strftime('%Y-%m-%d %H:%M:%S');
    my $data = {
        'timestamp' => $timestamp,
        'source'    => 'freshclam',
        'event'     => $event,
    };
    $dbengine->insert('av_db_updates', $data);
}

1;
