# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::RemoteServices::Job::Helper;

# Class: EBox::RemoteServices::Job::Helper
#
#     Helper for job scripts
#

use strict;
use warnings;

use EBox::Config;
use EBox::Global;
use Fcntl qw(:flock);

# Constants
use constant JOB_USER => '__job__';

# Procedure: startScriptSession
#
#     Start a session in Zentyal for a job.
#
#     Basically, set the script session id in a file and set the job
#     user in Audit module
#
# Parameters:
#
#     time - Int the UNIX timestamp for starting the session
#            If 0, then finish the script session
#
sub startScriptSession
{
    my ($time) = @_;

    my $sessionFile;
    my $openMode = '>';
    if ( -f EBox::Config->scriptSession() ) {
        $openMode = '+<';
    }
    open ($sessionFile, $openMode, EBox::Config->scriptSession() )
      or die 'Could not open ' . EBox::Config->scriptSession() . ": $!";

    # Lock the file in exclusive mode
    flock($sessionFile, LOCK_EX)
      or die 'Could not get the lock for ' . EBox::Config->scriptSession() . ": $!";

    # Truncate the file before writing
    truncate( $sessionFile, 0);
    print $sessionFile "$time$/";

    # Release the lock and close the file
    flock($sessionFile, LOCK_UN);
    close($sessionFile);

    if ( $time > 0 ) {
        # Starting new session
        my $audit = EBox::Global->getInstance()->modInstance('audit');
        $audit->setUsername(JOB_USER);
    }

}

1;
