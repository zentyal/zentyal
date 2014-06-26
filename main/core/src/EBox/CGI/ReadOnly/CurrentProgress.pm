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

package EBox::ReadOnly::CGI::CurrentProgress;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::ProgressIndicator;

use Error qw(:try);
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

    my $response = $progress->stateAsHash();
    $response->{changed} = $self->modulesChangedStateAsHash();

    print($self->cgi()->header(-charset=>'utf-8'));
    print to_json($response);
}

sub modulesChangedStateAsHash
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $state = $global->unsaved() ? 'changed' : 'notchanged';
    return $state;
}

1;
