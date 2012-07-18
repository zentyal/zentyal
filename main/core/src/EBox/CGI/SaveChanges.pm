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
#            'template' => '/finish.mas',
#            'template' => '/savechanges.mas',
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


my @commonProgressParams = (
        reloadInterval  => 2,
        raw => 1,
        nextStepText => __('Go back'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => 'Modalbox.hide(); return false',
);
sub saveAllModulesAction
{
    my ($self) = @_;

 #   $self->{redirect} = "/Dashboard/Index";

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareSaveAllModules();

    $self->showProgress(
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
}


sub revokeAllModulesAction
{
    my ($self) = @_;

#    $self->{redirect} = "/Dashboard/Index";

    my $global = EBox::Global->getInstance();
    my $progressIndicator = $global->prepareRevokeAllModules();

    $self->showProgress(
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
}


# sub _header
# {
# 	my $self = shift;
# 	print <<END;
# <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
# 		      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
# <html xmlns="http://www.w3.org/1999/xhtml">
# <head>
# <title>TITLE_TO_CHANGE</title>
# <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
# <link href="/dynamic-data/css/public.css" rel="stylesheet" type="text/css" />
# <link rel="shortcut icon" href="FAV_ICON" />
# <script type="text/javascript" src="/data/js/progress.js">//</script>
# <script type="text/javascript" src="/data/js/common.js">//</script>
# <script type="text/javascript" src="/data/js/prototype.js">//</script>
# <script type="text/javascript" src="/data/js/scriptaculous/scriptaculous.js">//</script>
# <script type="text/javascript" src="/data/js/modalbox.js">//</script>

# </head>
# <body>
# END

#     }

1;
