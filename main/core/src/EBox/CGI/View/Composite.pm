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

# Class: EBox::CGI::View::Composite
#
#     This CGI is intended to show the composite model. The optional
#     parameters can follow this format:
#
#      modelName - directory
#
#     For example, ObjectTable=objectTable/keys/obje7908/members
#

package EBox::CGI::View::Composite;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use TryCatch;

# Constructor: new
#
#       Create the general Composite View CGI
#
# Parameters:
#
#       <EBox::CGI::ClientBase::new> the parent parameters
#
#       compositeModel - <EBox::Model::Composite> the composite model
#       to show
#
# Returns:
#
#       <EBox::CGI::View::Composite> - the recently created CGI
#
sub new
{
    my ($class, %params) = @_;
    my $composite = delete $params{composite};
    my $self = $class->SUPER::new(template => $composite->Viewer(), %params);
    $self->{composite} = $composite;

    bless ($self, $class);
    return $self;
}

# Method: _header
#
#      Overrides to dump the page title in the HTML title if defined
#
# Overrides:
#
#      <EBox::CGI::ClientBase::_header>
#
sub _header
{
    my ($self) = @_;

    my $response = $self->response();
    $response->content_type('text/html; charset=utf-8');
    my $pageTitle;
    try {
        $pageTitle = $self->{composite}->pageTitle();
    } catch {
        EBox::error("Cannot get pageTitle for Composite");
        $pageTitle = '';
    }
    return EBox::Html::header($pageTitle, $self->menuFolder());
}

sub _process
{
    my ($self) = @_;

    my $composite = $self->{'composite'};
    my $directory = $self->param('directory');
    $self->setMenuFolder($composite->menuFolder());

    if (defined $directory) {
        $composite->setDirectory($directory);
    }
    else {
        $composite->setDirectory('');
    }

    $self->{params} = $self->masonParameters();
}

# Method: masonParameters
#
#      Overrides <EBox::CGI::ClientBase::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();

    return [
        model      => $self->{composite},
        user       => $self->user(),
        hasChanged => $global->unsaved(),
    ];
}

1;
