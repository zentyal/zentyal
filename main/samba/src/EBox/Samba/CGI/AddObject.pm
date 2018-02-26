# Copyright (C) 2013-2014 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHObjectT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::Samba::CGI::AddObject;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/addobject.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    my @args;

    $self->_requireParam('dn', 'dn');
    my $dn = $self->unsafeParam('dn');

    my $addGroup = $dn =~ /^(CN|OU)=Groups,/;
    my $allowAddOU = $dn !~ /^CN=/;

    push (@args, dn => $dn);
    push (@args, addGroup => $addGroup);
    push (@args, allowAddOU => $allowAddOU);

    $self->{params} = \@args;
}

1;
