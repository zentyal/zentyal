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

package EBox::CGI::EBox::Backup;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Config;
use File::Temp qw(tempfile);
use EBox::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Configuration backups'),
				      'template' => '/backup.mas',
				      @_);
	$self->{errorchain} = "EBox/Backup";
	bless($self, $class);
	return $self;
}

sub _print
{
	my $self = shift;
	if ($self->{error} || not defined($self->{downfile})) {
		$self->SUPER::_print;
		return;
	}
	open(BACKUP,$self->{downfile}) or
		throw EBox::Exceptions::Internal('Could not open backup file.');
	print($self->cgi()->header(-type=>'application/octet-stream',
				   -attachment=>$self->{downfilename}));
	while (<BACKUP>) {
		print $_;
	}
	close BACKUP;
}

sub _process
{
	my $self = shift;
	my $backup = new EBox::Backup;

	# the 'backups' parameter is set here _and_ after processing.
	# 	here -> in case an exception is raised during processing.
	#	afterwards -> in case the list changes during processing.
	my @array = ();
	push(@array, backups=>$backup->listBackups);
	$self->{params} = \@array;

	if (defined($self->param('backup'))) {
		$self->_requireParam('description', __('description'));
		$backup->makeBackup($self->param('description'));

	} elsif (defined($self->param('bugreport'))) {
		$self->{errorchain} = "EBox/Bug";
		$self->{downfile} = $backup->makeBugReport();
		$self->{downfilename} = 'eboxbugreport.tar';

	} elsif (defined($self->param('delete'))) {
		$self->_requireParam('id', __('identifier'));
		my $id = $self->param('id');
		if ($id =~ m{[./]}) {
			throw EBox::Exceptions::External(
				__("The input contains invalid characters"));
		}
		$backup->deleteBackup($id);

	} elsif (defined($self->param('download'))) {
		$self->_requireParam('id', __('identifier'));
		my $id = $self->param('id');
		if ($id =~ m{[./]}) {
			throw EBox::Exceptions::External(
				__("The input contains invalid characters"));
		}
		$self->{downfile} = EBox::Config::conf . "/backups/$id.tar";
		$self->{downfilename} = 'eboxbackup.tar';

	} elsif (defined($self->param('restoreId'))) {
		$self->_requireParam('id', __('identifier'));
		my $id = $self->param('id');
		if ($id =~ m{[./]}) {
			throw EBox::Exceptions::External(
				__("The input contains invalid characters"));
		}
		$backup->restoreBackup(EBox::Config::conf ."/backups/$id.tar");

	} elsif (defined($self->param('restore'))) {
		my $dir = EBox::Config::tmp;
		my ($fh, $filename) = tempfile("backupXXXXXX", DIR=>$dir);

		my $upfile = $self->cgi->upload('backupfile');
		unless ($upfile) {
			close $fh;
			`rm -f $filename`;
			throw EBox::Exceptions::External(
						__('Invalid backup file.'));
		}
		while (<$upfile>) {
			print $fh $_;
		}

		close $fh;
		close $upfile;

		my $backup = new EBox::Backup;
		$backup->restoreBackup($filename);
		`rm -f $filename`;
		$self->{msg} = __('Configuration restored succesfully, '.
			'you should now review it and save it if you want '.
			'to keep it.');
	}

	@array = ();
	push(@array, backups=>$backup->listBackups);
	$self->{params} = \@array;

}

1;
