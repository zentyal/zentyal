# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::CGI::RemoteServices::Backup::DownloadRemoteBackup;
use base qw(EBox::CGI::ClientBase);

use strict;
use warnings;

use EBox::RemoteServices::Backup;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;


sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new( @_);
	$self->{errorchain} = "RemoteServices/Backup/Index";
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
	print($self->cgi()->header(
				   -type=>'application/octet-stream',
				   -attachment=>$self->{downfilename}
				  ));
	while (<BACKUP>) {
		print $_;
	}
	close BACKUP;
}

sub requiredParameters
{
  return [qw(name)];
}

sub actuate
{
  my ($self) = @_;

  my $backup =  new EBox::RemoteServices::Backup;
  my $name   = $self->param('name');

  my $file = $backup->downloadRemoteBackup($name);
  $self->{downfile} = $file;
  $self->{downfilename} = "$name.tar";
}

1;
