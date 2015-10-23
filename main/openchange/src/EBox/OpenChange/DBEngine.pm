# Copyright (C) 2014-2015 Zentyal S.L.
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

package EBox::OpenChange::DBEngine;
use base 'EBox::MyDBEngine';

sub new
{
    my ($class, $openchange) = @_;
    my $self = {};
    $self->{openchange} = $openchange;
    bless($self,$class);
    return $self;
}

# Method: connect
#
#      Connect to the database as the constructor does not.
#
sub connect
{
    my ($self) = @_;
    $self->_connect();
}

sub _dbname
{
    return 'openchange';
}

sub _dbuser
{
    return 'openchange';
}

sub _dbpass
{
    my ($self) = @_;
    my $file = $self->{openchange}->OPENCHANGE_MYSQL_PASSWD_FILE();
    return $self->{openchange}->_getPassword($file, 'mysql openchange password');
}

1;
