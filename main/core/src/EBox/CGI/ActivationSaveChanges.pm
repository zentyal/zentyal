# Copyright (C) 2018 Zentyal S.L.
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

package EBox::CGI::ActivationSaveChanges;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use TryCatch;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new('title' => __('Save Changes'),
                                  'template' => 'activation-save.mas', %params);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $save = $self->param('save');

    unless ($save) {
        $self->{redirect} = '/';
    }
}

sub _menu
{
}

sub _top
{
}

sub _title
{
}

1;
