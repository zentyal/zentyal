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

package EBox::UsersAndGroups::CGI::Contact;

use base 'EBox::CGI::View::DataTable';

use EBox::Gettext;
use EBox::Global;
use EBox::UsersAndGroups::Contact;

sub new
{
    my $class = shift;
    my %params = @_;
    my $usersMod = EBox::Global->modInstance('users');
    my $contactModel = $usersMod->model('Contact');
    my $self = $class->SUPER::new('tableModel' => $contactModel, @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->SUPER::_process();


    $self->_requireParam("contact", __('contact'));

    my $dn = $self->unsafeParam('contact');
    my $contact = new EBox::UsersAndGroups::Contact(dn => $dn);

    $self->{tableModel}->{contact} = $contact;
}

1;
