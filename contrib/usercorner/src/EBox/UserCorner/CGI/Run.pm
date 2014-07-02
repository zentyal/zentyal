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

package EBox::UserCorner::CGI::Run;
use base 'EBox::CGI::Run';


# Method: urlToClass
#
#  Returns CGI class for the given URL
#
sub urlToClass
{
    my ($self, $url) = @_;

    unless ($url) {
        return "EBox::UserCorner::CGI::Dashboard::Index";
    }

    my @parts = split('/', $url);
    # filter '' and undef
    @parts = grep { $_ } @parts;

    my $module = shift @parts;
    if (@parts) {
        # not the same format that normal EBox::Module::CGI
        return "EBox::UserCorner::CGI::${module}::" . join ('::', @parts);
    } else {
        return "EBox::UserCorner::CGI::${module}";
    }
}

sub _instanceComponent
{
    my ($self, $path, $type) = @_;
    my $model = $self->SUPER::_instanceComponent($path, $type);
    if ($model->userCorner()) {
        return $model
    } else {
        return undef;
    }
}

1;
