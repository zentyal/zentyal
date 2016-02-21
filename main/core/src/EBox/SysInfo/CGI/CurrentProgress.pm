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

package EBox::SysInfo::CGI::CurrentProgress;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::ProgressIndicator;

use TryCatch;
use JSON;

## arguments:
##  title [required]
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => __('Upgrading'),
                                  'template' => 'none',
                                  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->{params} = [];
}

sub _print
{
    my ($self) = @_;

    my $progressId = $self->param('progress');
    my $progress = EBox::ProgressIndicator->retrieve($progressId);

    my $responseContent = $progress->stateAsHash();
    $responseContent->{changed} = $self->modulesChangedStateAsHash();

    my $response = $self->response();
    $response->content_type('application/json; charset=utf-8');
    $response->body(to_json($responseContent));
}

sub modulesChangedStateAsHash
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $state = $global->unsaved() ? 'changed' : 'notchanged';
    return $state;
}

1;
