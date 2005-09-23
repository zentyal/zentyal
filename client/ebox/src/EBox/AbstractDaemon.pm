# Copyright (C) 2005 Warp Netwoks S.L.

# Class: EBox::AbstractDaemon
#
#	This class is intended to be used by those classes which need to
#	be executed as a standalone daemon.
#
package EBox::AbstractDaemon;

use EBox;
use POSIX;

use Error qw(:try);

use strict;
use warnings;

use constant PIDPATH => EBox::Config::tmp . '/pids/';

sub new 
{
        my $class = shift;
	my %opts = @_;
	my $name = delete $opts{'name'};
        my $self = {'name' => $name};
        bless($self, $class);
        return $self;
}


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
    	open(STDOUT, "+>/tmp/stdout");
   	open(STDERR, "+>/tmp/stderr");

	
	unless (-d PIDPATH) {
		mkdir PIDPATH;
	}
	unless (open(FD ,  '>' . PIDPATH . $self->{'name'} . '.pid')) {
		EBox::debug ('Cannot save pid');
		exit 1;
	}
	
	print FD "$$";
	close FD;
}

1;
