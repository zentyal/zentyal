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

package EBox::Sudo;

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use File::stat qw();
use Error qw(:try);

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw();
	%EXPORT_TAGS  = (all => [qw{ root command stat rootCommandForStat} ],
			);
	@EXPORT_OK = qw();
	Exporter::export_ok_tags('all');
	$VERSION = EBox::Config::version;
}

#
# Method: command 
#
#	Executes a command as ebox user 
#
# Parameters:
#
#       command - string with the command to execute
#
#
# Exceptions:
#
#       Internal  - If command fails
#
sub command # (command) 
{
	my $cmd = shift;
	unless (system($cmd) == 0) {
		throw EBox::Exceptions::Internal(
			__x("Command '{cmd}' failed", cmd => $cmd));
	}
}

#
# Method: root 
#
#	Executes a command through sudo. Use this to execute privileged
#	commands. 
#
# Parameters:
#
#       command - string with the command to execute
#
#
# Exceptions:
#
#       Internal  - If command fails
#
# Returns:
# 	array ref - Returns the output of the command in an array
sub root # (command) 
{
	my $cmd = shift;
	my $sudocmd = "/usr/bin/sudo " . $cmd;

	my @output = `$sudocmd`;
	unless($? == 0) {
		throw EBox::Exceptions::Internal(
			__x("Root command '{cmd}' failed", cmd => $cmd));
	}
	return \@output;
}

#
# Method: sudo 
#
#	Executes a command through sudo as a given user. 
#
# Parameters:
#
#       command - string with the command to execute
#	user - user to run the command as
#
#
# Exceptions:
#
#       Internal  - If command fails
#
sub sudo # (command, user) 
{
	my ($cmd, $user) = @_;
	unless (system("/usr/bin/sudo -u " . $user . " " . $cmd) == 0) {
		throw EBox::Exceptions::Internal(
			__x("Running command '{cmd}' as {user} failed", 
				cmd => $cmd, user => $user));
	}
}


# return the same than perl's stat with the exception of:
#       6 rdev     the device identifier (special files only)   %T <--- UNDEF because is not emulated yet

sub stat
{
  my ($file) = @_;
  
    my $statCmd = rootCommandForStat($file);
  my $statOutput;
  
  try {
    $statOutput = root($statCmd);
  }
  catch EBox::Exceptions::Internal with {
    return undef; # inexistent file
  };

  return undef if !exists $statOutput->[0];

  my @statElements = split '[I\n]', $statOutput->[0];

  # convert file mode from hexadecimal...
  $statElements[2]  = hex ('0x' . $statElements[2]); 

  # XXX: add the correct value for  '6 rdev     the device identifier (special files only) '
  # meanwhile we make it undef...
  $statElements[6] = undef;

  my $statObject = File::stat::populate( @statElements );
  return $statObject;
}


sub rootCommandForStat
{
    my ($file) = @_;
    return "/usr/bin/stat -c%dI%iI%fI%hI%uI%gItodoI%sI%XI%YI%ZI%oI%b $file";
}

1;
