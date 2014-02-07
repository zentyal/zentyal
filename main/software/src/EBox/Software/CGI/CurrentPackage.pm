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

package EBox::Software::CGI::CurrentPackage;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Config;

## arguments:
##  title [required]
sub new {
    my $class = shift;
    my $self = $class->SUPER::new('title'    => __('Upgrading'),
            'template' => 'software/upgrading.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process($) {
    my $self = shift;
    my @array = ();
    $self->{params} = \@array;
}

sub _print($) {
    my $self = shift;

    my $response = $self->response();
    $response->status(200);
    $response->content_type('text/html; charset=utf-8');
    open(FD, EBox::Config::tmp . 'ebox-update-log') or return;
    my $package = <FD>;
    $response->body($package);
    close (FD);
}

1;
