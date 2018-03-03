# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::CGI::Progress;

use base 'EBox::CGI::ClientBase';

#  This class is to used to show the progress of a long operation
#
#  This CGI is not intended to be caled directly, any CGI whom wants to switch
#   to a progress view must inherit from ProgressClient and call to the method showProgress

use EBox::Global;
use EBox::GlobalImpl;
use EBox::Config;
use EBox::Gettext;
use EBox::Html;
use Encode;
use File::Slurp;
use JSON::XS;
use EBox::ProgressIndicator;
use EBox::Exceptions::Internal;
use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/progress.mas',
                                  @_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my @params = ();
    push @params, (progressId => $self->_progressId);

    my $title = $self->unsafeParam('title');
    my @paramsNames = qw( text currentItemCaption itemsLeftMessage
            showNotesOnFinish
            endNote errorNote reloadInterval currentItemUrl
            inModalbox
            nextStepType
            nextStepUrl nextStepText nextStepTimeout
            nextStepUrlOnclick nextStepUrlFailureOnclick
            );
    foreach my $name (@paramsNames) {
        # We use unsafeParam because these paramaters can be i18'ed.
        # Also, these parameters are only used to generate html, no command
        # or so is run.
        my $value = $self->unsafeParam($name);
        $value or
            next;

        push @params, ($name => $value);
    }

    if (EBox::Global->first()) {
        my $software = EBox::Global->modInstance('software');
        # FIXME: workaround to show ads only during installation
        unless ( $self->{title} and
               ( __('Saving changes') eq $self->{title} )) {
                  if (EBox::Global->modExists('software')) {
                      push @params, (slides => _loadSlides());
                  }
        }
    }

    $self->{params} = \@params;
}

sub _progressId
{
    my ($self) = @_;
    my $pId = $self->param('progress');
    if (not $pId) {
        EBox::warn("Progress indicator parameter lost, trying to get last one as fallback");
        $pId = EBox::ProgressIndicator->_lastId();
        if (not $pId) {
            EBox::warn("Using progress indicator 1 as fallback");
            $pId = 1;
        }
    }

    $pId or throw EBox::Exceptions::Internal('No progress indicator id supplied');
    return $pId;
}

# to avoid the <div id=content> in raw mode
sub _print
{
    my ($self) = @_;
    if (not $self->param('raw')) {
        $self->SUPER::_print();
    } else {
        $self->_printPopup();
    }
}

sub _menu
{
    my ($self) = @_;
    if ($self->param('raw')) {
        return;
    }

    if (EBox::Global->first() and EBox::Global->modExists('software')) {
        my $software = EBox::Global->modInstance('software');
        my $titleFromParam = $self->unsafeParam('title');
        if ($titleFromParam and (__('Saving changes') eq $titleFromParam)) {
            return $software->firstTimeMenu(4);
        } else {
            return $software->firstTimeMenu(2);
        }
    } else {
        return $self->SUPER::_menu(@_);
    }
}

sub _top
{
    my ($self) = @_;
    if ($self->param('raw')) {
        return;
    }

    my $global = EBox::Global->getInstance();
    my $img = $global->theme()->{'image_title'};
    return "<div id='top'></div><div id='header'><img src='$img'/></div>";
}

sub _footer
{
    my ($self) = @_;
    if ($self->param('raw')) {
        return;
    }

    return $self->SUPER::_footer();
}

sub _slidesFilePath
{
    my ($prefix) = @_;

    my $path = EBox::Config::share() . "zentyal-software/ads";
    my $file = "$path/$prefix" . EBox::locale();
    unless (-f $file) {
        $file =  "$path/$prefix" . substr (EBox::locale(), 0, 2);
        unless (-f $file) {
            $file = "$path/${prefix}en";
        }
    }
    if (-f "$file.custom") {
        $file = "$file.custom";
    }

    return $file;
}

sub _loadSlides
{
    my $text_prefix = 'ads_';
    my $slide_prefix = 'slide';
    unless (EBox::Global->communityEdition()) {
        $text_prefix = 'com_ads_';
        $slide_prefix = 'com_slide';
    }

    my $file = _slidesFilePath($text_prefix);
    EBox::debug("Loading ads from: $file");
    my $json;
    try {
        $json = read_file($file);
   } catch {
       $json = undef;
   }
   if (not $json) {
       EBox::error("Error loading ads. Ingnoring them");
       return [];
   }

    my $slides = decode_json($json);
    my @html;
    my $num = 1;
    foreach my $slide (@{$slides}) {
        $slide->{num} = $num++;
        $slide->{prefix} = $slide_prefix;
        push (@html, EBox::Html::makeHtml('slide.mas', %{$slide}));
    }

    return \@html;
}

1;
