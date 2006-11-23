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

package EBox::CGI::Software::InstallPkgs;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => '',
				      'template' => 'software/del.mas',
				      @_);
	$self->{domain} = 'ebox-software';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $software = EBox::Global->modInstance('software');
	my $action;
	my $doit = 'no';

	if (defined($self->param('go'))) {
		$doit = 'yes';
	}
	if (defined($self->param('cancel'))) {
		$self->{chain} = "Software/EBox";
		delete $self->{'template'};
		return;
	}
	if (defined($self->param('upgrade'))) {
		$self->{chain} = "Software/EBox";
		delete $self->{'template'};
		$action = 'install';
		$doit = 'yes';
	} elsif (defined($self->param('ebox-install'))) {
		if($doit eq 'yes') {
			$self->{chain} = "Software/EBox";
		}
		$action = 'install';	
	} elsif (defined($self->param('ebox-remove'))) {
		if($doit eq 'yes') {
			$self->{chain} = "Software/EBox";
		}
		$action = 'remove';
	} else {
		$self->{redirect} = "Summary/Index";
		return;
	}

	# Take the packages
	my @pkgs;
	if (not $self->param('allbox') ) {
	  @pkgs = grep(s/^pkg-//, @{$self->params()});
	  (@pkgs == 0) and throw EBox::Exceptions::External(__('There were no packages to update'));
	} else {
	  @pkgs = @{$software->listUpgradablePkgs()};
	}

	if ($doit eq 'yes') {
		if ($action eq 'install') {
			$software->installPkgs(@pkgs);
			$self->{msg} = 
				__('The packages are being installed, please refrain from using the application until the update is done');
			$self->{chain} = "Software/Upgrading";
		} else {
			$software->removePkgs(@pkgs);
			$self->{msg} = 
				__('The packages were removed successfully');
		}
		#regen the cache
		$software->listUpgradablePkgs(1);
		$software->listEBoxPkgs(1);
		delete $self->{'template'};
		return;
	}
	my @array;
	push(@array, 'action' => $action);
	push(@array, 'packages' => \@pkgs);
	my $actpackages;
	if($action eq 'install') {
		$actpackages = $software->listPackageInstallDepends(\@pkgs);
	} else {
		$actpackages = $software->listPackageRemoveDepends(\@pkgs);
	}
	push(@array, 'actpackages' => $actpackages);
	$self->{params} = \@array;
}

1;
