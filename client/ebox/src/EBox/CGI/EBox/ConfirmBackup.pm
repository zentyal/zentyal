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

package EBox::CGI::EBox::ConfirmBackup;

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
				      'template' => '/confirm-backup.mas',
				      @_);
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;
	my $backup = new EBox::Backup;
	$self->{errorchain} = "EBox/Backup";

	my @array = ();

	if (defined($self->param('download'))) {
		$self->{chain} = 'EBox/Backup';
		return;

	} elsif (defined($self->param('delete'))) {
		push(@array, action=>'delete');
		push(@array, actiontext=>__('Delete'));
		$self->{msg} = __('Please confirm that you want to delete '.
				'the following backup file:');

	} elsif (defined($self->param('restore'))) {
		push(@array, action=>'restoreId');
		push(@array, actiontext=>__('Restore'));
		$self->{msg} = __('Please confirm that you want to restore '.
				'the configuration from this backup file:');
	} 
	elsif (defined($self->param('burn'))) {
		push(@array, action=>'writeBackupToDisc');
		push(@array, actiontext=>__('Write to disc'));
		$self->{msg} = __('Please confirm that you want to write'.
				'this backup file to a CD or DVD disc:');

	} else {
		$self->{redirect} = "EBox/Backup";
		return;
	}

	$self->_requireParam('id', __('identifier'));

	my $id = $self->param('id');
	if ($id =~ m{[./]}) {
		throw EBox::Exceptions::External(
			__("The input contains invalid characters"));
	}

	push(@array, backup=>$backup->backupDetails($id));

	$self->{params} = \@array;
}

1;
