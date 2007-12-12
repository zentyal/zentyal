# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

# Class: EBox::AbstractDaemon
#
#	This class is intended to be used by those classes which need to
#	be executed as a standalone daemon.
#
package EBox::AbstractDaemon;

use EBox;
use EBox::Config;
use POSIX;

use Error qw(:try);

use strict;
use warnings;

use constant PIDPATH => EBox::Config::tmp . '/pids/';

# Constructor: new
#
#        Create a new <EBox::AbstractDaemon> to work with
#
# Parameters:
#
#        name - String daemon's name (it should unique)
#
#        - Named parameters
#
# Returns:
#
#        <EBox::AbstractDaemon> - the newly created object instance
#
sub new 
{
        my $class = shift;
	my %opts = @_;
	my $name = delete $opts{'name'};
        my $self = {
		    'name' => $name
		    
		   };
        bless($self, $class);
        return $self;
}

# Method: init
#
#      Spawn the daemon. Clossing the first 64 file descriptors apart
#      from standard input/output/error and writes the pid on a file
#      under <EBox::Config::tmp> pids subdirectory.
#
sub init {
	my $self =  shift;
	my ($pid);
	
	if ($pid = fork()) {
		exit 0;
	}

	unless (POSIX::setsid) {
		EBox::debug ('Cannot start new session for ', $self->{'name'});
		exit 1;
	}

	foreach my $fd (0 .. 64) { POSIX::close($fd); }


	open(STDIN,  "+</tmp/stdin");
	if (EBox::Config::configkey('debug') eq 'yes') {
	  open(STDOUT, "+>/tmp/stdout");
	  open(STDERR, "+>/tmp/stderr");
	}


	unless (-d PIDPATH) {
		mkdir PIDPATH;
	}

        my $FD;
	unless (open($FD ,  '>' . PIDPATH . $self->{'name'} . '.pid')) {
		EBox::debug ('Cannot save pid');
		exit 1;
	}

	print $FD "$$";
	close $FD;
}

1;
