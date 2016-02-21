# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Software::CGI::InstallPkgs;
use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;

use TryCatch;

## arguments:
##  title [required]
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Installation'),
                                  'template' => 'software/del.mas',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $action;
    my $doit = 'no';

    if (defined($self->param('go'))) {
        $doit = 'yes';
    }

    if (defined($self->param('cancel'))) {
        $self->{chain} = 'Software/EBox';
        return;
    }

    if (defined($self->param('upgrade'))) {
        $action = 'install';
        $doit = 'yes';
        $self->{chain} = 'Software/Updates';
    } elsif (defined($self->param('install'))) {
        $action = 'install';
    } elsif (defined($self->param('remove'))) {
        $action = 'remove';
    } else {
        throw EBox::Exceptions::MissingArgument("action");
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

# overriden to not print title in the page. We dont want it neither on the popup
# or a regular page, but we need the title parameter for the browser tab
sub _title
{
}


sub _print
{
    my ($self) = @_;
    if ($self->param('popup')) {
        $self->_printPopup();
    } else {
        $self->SUPER::_print();
    }
}

sub _menu
{
    my $self = shift;

    if (EBox::Global->first() and EBox::Global->modExists('software')) {
        my $software = EBox::Global->modInstance('software');
        return $software->firstTimeMenu(1);
    } else {
        return $self->SUPER::_menu(@_);
    }
}

sub _top
{
    my ($self) = @_;
    return $self->_topNoAction();
}

sub _packages
{
    my ($self, $allPackages) = @_;
    defined $allPackages or $allPackages = 0;

    my @pkgs;
    if (not $allPackages) {
        @pkgs = grep(s/^pkg-//, @{$self->params()});
        (@pkgs == 0) and throw EBox::Exceptions::External(__('There were no packages to update'));
    } else {
        # Take the name from upgradable package list excluding Zentyal pkgs
        my $software = EBox::Global->modInstance('software');
        foreach my $pkg (@{$software->listUpgradablePkgs(0, 1)}) {
            push (@pkgs, $pkg->{name});
        }
    }

    return \@pkgs;
}

sub _goAhead
{
    my ($self, $action, $packages_r) = @_;
    my $software = EBox::Global->modInstance('software');

    $self->{chain} = "Software/EBox";
    $self->{errorchain} = "Software/EBox";

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

    $self->{errorchain} = 'Software/EBox';

    my $actpackages;
    my $descactpackages;
    my $error;

    try {
        if ($action eq 'install') {
            $actpackages = $software->listPackageInstallDepends($packages_r);
            $descactpackages = $software->listPackageDescription($actpackages);
        } elsif ($action eq 'remove') {
            $actpackages = $software->listPackageRemoveDepends($packages_r);
            $descactpackages = $software->listPackageDescription($actpackages);
        }  else {
            throw EBox::Exceptions::Internal("Bad action: $action");
        }
    } catch ($e) {
        $error = "$e";
    }

    if ($error) {
        $self->{template} = '/ajax/simpleModalDialog.mas';
        $self->{params} = [
            text  => $error,
            textClass => 'error',
           ];
        return;
    }

    my @actPkgInfo;
    my $i = 0;
    for my $name (@{$actpackages}) {
        my $desc = $descactpackages->[$i++];
        $desc =~ s/^Zentyal - //;
        push (@actPkgInfo, { name => $name, description => $desc });
    }

    $self->{'template'} = 'software/del.mas',

    my @array;
    push(@array, 'action' => $action);
    push(@array, 'packages' => $packages_r);
    push(@array, 'actpkginfo' => \@actPkgInfo);
    $self->{params} = \@array;
}

my @popupProgressParams = (
        raw => 1,
        inModalbox => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => "Zentyal.Dialog.close(); window.location.reload(); return false",
);

sub showInstallProgress
{
    my ($self, $progressIndicator) = @_;

    my @params= (
        progressIndicator => $progressIndicator,
        currentItemCaption =>  __('Current operation'),
        itemsLeftMessage  => __('actions done'),
        errorNote => __x('The packages installation has not finished correctly '
            . '. More information on the logs in {dir}',
                         dir => EBox::Config->log()
                        ),
        reloadInterval  => 2,
        nextStepTimeout => 5
       );
    if ($self->param('popup')) {
        push @params, @popupProgressParams;
        push @params, endNote  =>  __('The packages installation has finished successfully. '
            . 'The administration interface may become unresponsive '
            . 'for a few seconds. Please wait patiently until '
            . 'the system has been fully configured.'),
    } else {
        my $wizardUrl = '/Wizard';
        push @params, (
            showNotesOnFinish => 'no',
            title    => __('Installing'),
            text  => __('Installing packages'),
            nextStepUrl => $wizardUrl,
            nextStepText => __('Click here if the redirection fails'),
            endNote  =>  __('The packages installation has finished successfully. '
            . 'The administration interface may become unresponsive '
            . 'for a few seconds. Please wait patiently until '
            . 'the system has been fully configured. You will be automatically '
            . 'redirected to the next step'),
           );
    }

    $self->showProgress(@params);
}

sub showRemoveProgress
{
    my ($self, $progressIndicator) = @_;

    my @params =(
        progressIndicator => $progressIndicator,
        currentItemCaption =>  __('Current operation'),
        itemsLeftMessage  => __('packages left to remove'),
        endNote  =>  __('The packages removal has finished successfully. '
            . 'The administration interface may become unresponsive '
            . 'for a few seconds. Please wait patiently until '
            . 'the system has been fully restarted'),
        errorNote => __x('The packages removal has not finished correctly '
            . '. More information on the logs in {dir}',
                         dir => EBox::Config->log()),
        reloadInterval  => 2,
        nextStepTimeout => 5
    );

    if ($self->param('popup')) {
        push @params, @popupProgressParams;
        push @params, nextStepUrlOnclick => "Zentyal.Dialog.close(); window.location.reload(); return false";
    } else {
        push @params, title    => __('Removing packages'),
        push @params, text => __('Removing the selected package and its dependent packages');
    }

    $self->showProgress(@params);
}

1;
