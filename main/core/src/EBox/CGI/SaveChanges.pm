# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::CGI::SaveChanges;

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use TryCatch;

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
        # installer gives false positive there
        if (not $self->param('firstTime')) {
            throw EBox::Exceptions::External("No changes to be saved or revoked");
        }
    }
    if (defined($self->param('save'))) {
        $self->saveAllModulesAction();
    } elsif (defined($self->param('cancel'))) {
        $self->revokeAllModulesAction();
    } else {
        throw EBox::Exceptions::External("No save or cancel parameter");
    }
}

my @commonProgressParams = (
        reloadInterval  => 2,

);

my $jsCloseDialogAndReload = 'Zentyal.Dialog.close(); Zentyal.pageReload(); return false';

my @popupProgressParams = (
        raw => 1,
        inModalbox => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlFailureOnclick => $jsCloseDialogAndReload,
);

sub saveAllModulesAction
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareSaveAllModules();

    my @params = (
        progressIndicator  => $progressIndicator,
        text               => __('Saving changes in modules'),
        currentItemCaption => __("Current operation"),
        itemsLeftMessage   => __('operations performed'),
        endNote            => __('Changes saved'),
        errorNote          => __x('Some modules reported error when saving changes '
                                  . '. More information on the logs in {dir}',
                                  dir => EBox::Config->log()),
        @commonProgressParams
       );
    if ($self->param('noPopup')) {
        push @params, (title => __('Saving changes'));
        if ($self->param('firstTime')) {
            push @params, (firstTime => 1);
            push @params, (nextStepUrl => '/Wizard/SoftwareSetupFinish?firstTime=1');
            push @params, (showNotesOnFinish => 'no');
            push @params, (nextStepTimeout => 5);

        }
    } else {
        push @params, @popupProgressParams;
        push @params, nextStepUrlOnclick => $jsCloseDialogAndReload;
    }

    $self->showProgress(@params);
}

sub revokeAllModulesAction
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareRevokeAllModules();

    my @params = (
        progressIndicator => $progressIndicator,
        text     => __('Revoking changes in modules'),
        currentItemCaption  =>  __("Current module"),
        itemsLeftMessage  => __('modules revoked'),
        endNote  =>  __('Changes revoked'),
        errorNote => __x('Some modules reported error when discarding changes '
                           . '. More information on the logs in {dir}',
                         dir => EBox::Config->log()),
        @commonProgressParams
       );

    if ($self->param('noPopup')) {
        push @params, (title => __('Revoking changes'));
    } else {
        push @params, @popupProgressParams;
        push @params, nextStepUrlOnclick => $jsCloseDialogAndReload;
    }

    $self->showProgress(@params);
}

# to avoid the <div id=content>
sub _print
{
    my ($self) = @_;

    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
    } elsif ($self->param('noPopup')) {
        $self->SUPER::_print();
    } else {
        $self->_printPopup();
    }
}

1;
