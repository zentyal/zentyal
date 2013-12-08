# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::CGI::Mail::AddExternalAccount;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::UsersAndGroups::User;
use EBox::Validate;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

my %printableByParam = (
   'externalAccount' => __('External account'),
   'password' => __('Password'),
   'mailServer' => __('Server'),
   'mailProtocol' => __('Protocol'),
   'port'    => __('Port'),
   'localAccount' => 'localAccount',
);

my %validProtocols = (pop3 => 1, pop3s => 1, imap => 1, imaps => 1);

sub _process
{
    my $self = shift;

    $self->_requireParam('user', __('user'));
    my $user = $self->unsafeParam('user');
    $self->{redirect} = "UsersAndGroups/User?user=$user";
    $self->keepParam('user');

    my %params;
    while (my ($name, $printable) = each %printableByParam) {
        $self->_requireParam($name, $printable);
        $params{$name} = $self->unsafeParam($name);
    }

    my $userObject = new EBox::UsersAndGroups::User(dn => $user);
    $params{user} = $userObject;

    if (not $validProtocols{$params{mailProtocol}}) {
        throw EBox::Exceptions::InvalidData(
            data => __('Mail protocol'),
            value => $params{protocol},
           );
    }
    if ($params{mailProtocol} eq 'pop3s') {
        $params{mailProtocol} = 'pop3';
        $params{ssl} = 1;
    } elsif ($params{mailProtocol} eq 'imaps') {
        $params{mailProtocol} = 'imap';
        $params{ssl} = 1;
    }

    $params{keep} = $self->param('keep');
    $params{fetchall} = $self->param('fetchall');

    my $mail = EBox::Global->modInstance('mail');
    $mail->{fetchmail}->addExternalAccount(%params);
}

1;
