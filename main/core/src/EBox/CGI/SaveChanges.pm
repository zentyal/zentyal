# Copyright (C) 2008-2012 eBox Technologies S.L.
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

package EBox::CGI::SaveChanges;

use strict;
use warnings;

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Save configuration'),
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    my $global = EBox::Global->getInstance();
    if (not $global->unsaved) {
        throw EBox::Exceptions::External("No changes to be saved or revoked");
    }
    if (defined($self->param('save'))) {
        $self->saveAllModulesAction();
    } elsif (defined($self->param('cancel'))) {
        $self->revokeAllModulesAction();
    } else {
        throw EBox::Exceptions::External("No save or cancel parameter");
    }
}


sub saveAllModulesAction
{
    my ($self) = @_;

 #   $self->{redirect} = "/Dashboard/Index";

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareSaveAllModules();

    $self->showProgress(
        progressIndicator  => $progressIndicator,
        title              => __('Saving changes'),
        text               => __('Saving changes in modules'),
        currentItemCaption => __("Current operation"),
        itemsLeftMessage   => __('operations performed'),
        endNote            => __('Changes saved'),
        errorNote          => __x('Some modules reported error when saving changes '
                                  . '. More information on the logs in {dir}',
                                  dir => EBox::Config->log()),
        reloadInterval  => 2,
        raw => 1
       );
}


sub revokeAllModulesAction
{
    my ($self) = @_;

#    $self->{redirect} = "/Dashboard/Index";

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareRevokeAllModules();

    $self->showProgress(
        progressIndicator => $progressIndicator,
        title    => __('Revoking changes'),
        text     => __('Revoking changes in modules'),
        currentItemCaption  =>  __("Current module"),
        itemsLeftMessage  => __('modules revoked'),
        endNote  =>  __('Changes revoked'),
        errorNote => __x('Some modules reported error when discarding changes '
                           . '. More information on the logs in {dir}',
                         dir => EBox::Config->log()),
        reloadInterval  => 2,
        raw => 1,
       );
}


1;
