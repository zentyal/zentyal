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

package EBox::CGI::Finish;

use strict;
use warnings;

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Global;
use EBox::Gettext;
use EBox::LogAdmin qw(:all);
use EBox::ServiceModule::Manager;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Save configuration'),
				      'template' => '/finish.mas',
				      @_);
	bless($self, $class);
	return $self;
}

sub _process
{
	my $self = shift;

	my $global = EBox::Global->getInstance();


	if (defined($self->param('save'))) {
	    $self->saveAllModulesAction();
	} elsif (defined($self->param('cancel'))) {
	    $self->revokeAllModulesAction();
	} else {
		if ($global->unsaved) {
            my $manager = new EBox::ServiceModule::Manager();
            my $askPermission = defined @{$manager->checkFiles()};
			my @array = ();
			push(@array, 'unsaved' => 'yes');
            push(@array, 'askPermission' => $askPermission);
			#FIXME: uncomment to enable logadmin stuff
			#push(@array, 'actions' => pendingActions());
			$self->{params} = \@array;
		}
	}
}


sub saveAllModulesAction
{
    my ($self) = @_;

    $self->{redirect} = "/Summary/Index";

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareSaveAllModules();

    $self->showProgress(
			progressIndicator => $progressIndicator,

		      title    => __('Saving changes'),
		      text     => __('Saving changes in modules'),
		      currentItemCaption  =>  __("Current module"),
		      itemsLeftMessage  => __('modules saved'),
		      endNote  =>  __('Changes saved'),
                      errorNote => __('Some modules reported error when saving changes '
                                      . '. More information on the logs'),
		      reloadInterval  => 2,
		     );
}


sub revokeAllModulesAction
{
    my ($self) = @_;

    $self->{redirect} = "/Summary/Index";

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareRevokeAllModules();

    $self->showProgress(
			progressIndicator => $progressIndicator,

		      title    => __('Revoking changes'),
		      text     => __('Revoking changes in modules'),
		      currentItemCaption  =>  __("Current module"),
		      itemsLeftMessage  => __('modules revoked'),
		      endNote  =>  __('Changes revoked'),
                      errorNote => __('Some modules reported error when discarding changes '
                                      . '. More information on the logs'),
		      reloadInterval  => 2,
		     );
}


1;
