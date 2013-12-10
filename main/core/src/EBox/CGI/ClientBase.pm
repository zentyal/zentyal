# Copyright (C) 2004-2007 Warp Networks S.L.
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

package EBox::CGI::ClientBase;

use base 'EBox::CGI::Base';

use EBox::Gettext;
use EBox::Html;
use EBox::HtmlBlocks;

## arguments
##              title [optional]
##              error [optional]
##              msg [optional]
##              cgi   [optional]
##              template [optional]
sub new # (title=?, error=?, msg=?, cgi=?, template=?)
{
    my $class = shift;
    my %opts = @_;
    my $htmlblocks = delete $opts{'htmlblocks'};

    my $self = $class->SUPER::new(@_);

    if (not $htmlblocks) {
        $htmlblocks = 'EBox::HtmlBlocks';
    }
    if ($htmlblocks ne 'EBox::HtmlBlocks') {
        eval "use $htmlblocks";
    }

    $self->{htmlblocks} = $htmlblocks;

    bless($self, $class);
    return $self;
}

# Method: setMenuFolder
#
#   Set the name of the menu folder
#
# Parameters:
#
#   folder - string (Positional)
sub setMenuFolder
{
    my ($self, $folder) = @_;
    $self->{menuFolder} = $folder;
}

# Method: menuFolder
#
#   Fetch the menu folder. If it's not set it tries
#   to guess it from the URL
#
sub menuFolder
{
    my ($self) = @_;

    unless ($self->{menuFolder}) {
        my @split = split ('/', $ENV{'script'});
        if (@split) {
            return $split[0];
        } else {
            return undef;
        }

    }
    return $self->{menuFolder};
}

sub _header
{
    my $self = shift;
    print($self->cgi()->header(-charset=>'utf-8'));
    print(EBox::Html::header($self->{title}, $self->menuFolder()));
}

sub _top
{
    my $self = shift;
    print($self->{htmlblocks}->title());
}

sub _topNoAction
{
    my $self = shift;
    print($self->{htmlblocks}->titleNoAction());
}

sub _menu
{
    my $self = shift;
    print($self->{htmlblocks}->menu($self->menuFolder(), $self->{originalUrl}));
}

sub _footer
{
    my $self = shift;
    print($self->{htmlblocks}->footer());
}

1;
