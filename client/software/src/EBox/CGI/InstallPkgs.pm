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

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

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

	my $action;
	my $doit = 'no';

	if (defined($self->param('go'))) {
		$doit = 'yes';
	}

	if (defined($self->param('cancel'))) {
		$self->{chain} = "Software/EBox";
		return;
	}

	if (defined($self->param('upgrade'))) {
		$action = 'install';
		$doit = 'yes';
	} elsif (defined($self->param('ebox-install'))) {
		$action = 'install';	
	} elsif (defined($self->param('ebox-remove'))) {
		$action = 'remove';
	} else {
	    throw EBox::Exceptions::Internal("Missing action parameter");
	}

	# Take the packages
	my $packages_r = $self->_packages( $self->param('allbox') );

	if ($doit eq 'yes') {
	    $self->_goAhead($action, $packages_r);
	}
	else {
	    $self->showConfirmationPage($action, $packages_r);
	}
}


sub _packages
{
    my ($self, $allPackages) = @_;
    defined $allPackages or $allPackages = 0;

    my @pkgs;
    if (not  $allPackages) {
	@pkgs = grep(s/^pkg-//, @{$self->params()});
	(@pkgs == 0) and throw EBox::Exceptions::External(__('There were no packages to update'));
	} else {
	    # Take the name from upgradable package list
	    my $software = EBox::Global->modInstance('software');
	    foreach my $pkg (@{$software->listUpgradablePkgs()}) {
		push (@pkgs, $pkg->{name} );
	    }
	}

    return \@pkgs;
}

sub _goAhead
{
    my ($self, $action, $packages_r) = @_;
    my $software = EBox::Global->modInstance('software');

    $self->{chain} = "Software/EBox";

    if ($action eq 'install') {
	my $progress = $software->installPkgs(@{ $packages_r });
	$self->showInstallProgress($progress);
	
    } elsif ($action eq 'remove') {
	my $progress = $software->removePkgs(@{  $packages_r  });
	$self->showRemoveProgress($progress);
    } else {
	throw EBox::Exceptions::Internal("Bad action: $action");
    }
}


sub showConfirmationPage
{
    my ($self, $action, $packages_r) = @_;
    my $software = EBox::Global->modInstance('software');

    my $actpackages;
    if($action eq 'install') {
	$actpackages = $software->listPackageInstallDepends($packages_r);
    } elsif ($action eq 'remove') {
	$actpackages = $software->listPackageRemoveDepends($packages_r);
    }  else {
	throw EBox::Exceptions::Internal("Bad action: $action");
    }
    
    $self->{'template'} = 'software/del.mas',

    my @array;
    push(@array, 'action' => $action);
    push(@array, 'packages' => $packages_r);
    push(@array, 'actpackages' => $actpackages);
    $self->{params} = \@array;
}

sub showInstallProgress
{
  my ($self, $progressIndicator) = @_;
  $self->showProgress(
		      progressIndicator => $progressIndicator,

		      title    => __('Upgrading'),
		      text     => __('Upgrading packages'),
		      currentItemCaption  =>  __("Current package"),
		      itemsLeftMessage  => __('packages left to install'),
		      endNote  =>  __('The packages installation has finished successfully. '
                                      . 'The administration interface may become unresponsive '
                                      . 'for a few seconds. Please wait patiently until '
                                      . 'the system has been fully restarted'),
                      errorNote => __('The packages installation has not finished correctly '
                                      . '. More information on the logs'),
		      reloadInterval  => 2,
		     );
}

sub showRemoveProgress
{
  my ($self, $progressIndicator) = @_;
  $self->showProgress(
		      progressIndicator => $progressIndicator,

		      title    => __('Removing package'),
		      text     => __('Removing the selected package and its dependent packages'),
		      currentItemCaption  =>  __("Current package"),
		      itemsLeftMessage  => __('packages left to remove'),
		      endNote  =>  __('The packages removal has finished successfully. '
                                      . 'The administration interface may become unresponsive '
                                      . 'for a few seconds. Please wait patiently until '
                                      . 'the system has been fully restarted'),
                      errorNote => __('The packages removal has not finished correctly '
                                      . '. More information on the logs'),
		      reloadInterval  => 2,
		     );
}

1;
