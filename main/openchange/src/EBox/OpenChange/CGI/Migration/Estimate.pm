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

package EBox::OpenChange::CGI::Migration::Estimate;

use base 'EBox::CGI::Base';

use JSON::XS;

# Group: Public methods

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}

# Group: Protected methods

sub _process
{
    my ($self) = @_;

    my $postRawData = $self->unsafeParam('POSTDATA');
    my $postData = JSON::XS->new()->decode($postRawData);
    use Data::Dumper;
    EBox::debug(Dumper($postData));

    $self->{json} = {
        'total' => '753 MB',
        'mail'  => 2000,
        'contacts' => 232,
        'journal' =>  32,
        'time' => '1 hour 2 min',
    };

    # Set this on error
    # $self->{json}->{error} = 'error msg';
}

1;
