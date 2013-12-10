# Copyright (C) 2013 Zentyal S.L.
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

package EBox::CGI::View::Tree;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use TryCatch::Lite;

# Constructor: new
#
#       Create the general Tree View CGI
#
# Parameters:
#
#       <EBox::CGI::ClientBase::new> the parent parameters
#
#       modelModel - <EBox::Model::Tree> the model model
#       to show
#
# Returns:
#
#       <EBox::CGI::View::Tree> - the recently created CGI
#
sub new
{
    my $class = shift;
    my %params = @_;

    my $model = $params{model};
    my $self = $class->SUPER::new(template => $model->Viewer(), %params);
    $self->{model} = $model;

    bless ($self, $class);

    return $self;
}

# Method: _header
#
#      Overrides to print the page title in the HTML title if defined
#
# Overrides:
#
#      <EBox::CGI::ClientBase::_header>
#
sub _header
{
    my ($self) = @_;

    print $self->cgi()->header(-charset=>'utf-8');
    my $pageTitle;
    try {
        $pageTitle = $self->{model}->pageTitle();
    } catch {
        EBox::error("Cannot get pageTitle for Tree");
        $pageTitle = '';
    }
    print EBox::Html::header($pageTitle, $self->menuFolder());
}

sub _process
{
    my ($self) = @_;

    my $model = $self->{'model'};
    $self->setMenuFolder($model->menuFolder());

    my @params;
    push (@params, 'model' => $model);
    $self->{params} = \@params;
}

1;
