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


# package EBox::CGI::Progress
#
#  This class is to used to show the progress of a long operation
#
#  This CGI is not intended to be caled directly, any CGI whom wants to switch
#   to a progress view must inherit from ProgressClient and call to the method showProgress
package EBox::CGI::Progress;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Html;
use Encode;
use File::Slurp;
use JSON::XS;

## arguments:
##  title [required]
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

    my $title = ($self->param('title'));
    if ($title) {
        $self->{title} = encode (utf8 => $title);
    }

    my @paramsNames = qw( text currentItemCaption itemsLeftMessage
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
        use Encode;
        my $value = encode (utf8 => $self->unsafeParam($name));
        $value or
            next;

        push @params, ($name => $value);
    }

    if (EBox::Global->first()) {
        my $software = EBox::Global->modInstance('software');
        # FIXME: workaround to show ads only during installation
        unless ( $self->{title} and
                encode(utf8 => __('Saving changes')) eq $self->{title} ) {
            push @params, (adsJson => loadAds());
        }
    }

    $self->{params} = \@params;
}


sub _progressId
{
    my ($self) = @_;
    my $pId = $self->param('progress');

    $pId or throw EBox::Exceptions::Internal('No progress indicator id supplied');
    return $pId;
}


# to avoid the <div id=content> in raw mode
sub _print
{
    my ($self) = @_;
    if (not $self->param('raw')) {
        return $self->SUPER::_print();
    }

    return $self->_printPopup();
}

sub _menu
{
    my ($self) = @_;
    if ($self->param('raw')) {
        return;
    }

    if (EBox::Global->first() and EBox::Global->modExists('software')) {
        my $software = EBox::Global->modInstance('software');
        # FIXME: workaround to show distinct menu for saving changes and installation proccess
        if ( $self->{title} and
             encode(utf8 => __('Saving changes')) eq $self->{title} ) {
            $software->firstTimeMenu(4);
        } else {
            $software->firstTimeMenu(2);
        }
    } else {
        $self->SUPER::_menu(@_);
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
    print "<div id='top'></div><div id='header'><img src='$img'/></div>";
    return;
}

sub _footer
{
    my ($self) = @_;
    if ($self->param('raw')) {
        return;
    }

    return $self->SUPER::_footer();
}

sub loadAds
{
    my $path = EBox::Config::share() . 'zentyal-software/ads';
    my $file = "$path/ads_" + EBox::locale();
    unless (-f $file) {
        $file =  "$path/ads_" . substr (EBox::locale(), 0, 2);
        unless (-f $file) {
            $file = "$path/ads_en";
        }
    }
    if (-f "$file.custom") {
        $file = "$file.custom";
    }
    EBox::debug("Loading ads from: $file");
    my $json = read_file($file) or throw EBox::Exceptions::Internal("Error loading ads: $!");
    my $slides = decode_json($json);

    my @html;
    foreach my $slide (@{$slides}) {
        push (@html, EBox::Html::makeHtml('slide.mas', %{$slide}));
    }

    return encode_json(\@html);
}

1;
