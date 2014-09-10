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

use strict;
use warnings;

package EBox::Mail::CGI::AddExternalAccount;
use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Samba::User;
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
    my ($self) = @_;
    $self->{json}->{success} = 0;

    $self->_requireParam('user', __('user'));
    my $userDN = $self->unsafeParam('user');
    $self->{json}->{userDN} = $userDN;

    my %params;
    while (my ($name, $printable) = each %printableByParam) {
        $self->_requireParam($name, $printable);
        $params{$name} = $self->unsafeParam($name);
    }

    my $userObject = new EBox::Samba::User(dn => $userDN);
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
    if ($params{keep} and $params{fetchall}) {
        throw EBox::Exceptions::External(
            __('Keep messages and fetch all mail cannot work together because a implementation limitation')
           );

    }

    my $mail = EBox::Global->modInstance('mail');
    $mail->{fetchmail}->addExternalAccount(%params);

    my @externalAccounts = map {
        $mail->{fetchmail}->externalAccountRowValues($_)
    } @{ $mail->{fetchmail}->externalAccountsForUser($userObject) };

    $self->{json}->{externalAccounts} = \@externalAccounts;
    $self->{json}->{userDN}  = $userDN;
    $self->{json}->{msg} = __x('External account {acc} added', acc => $params{externalAccount});
    $self->{json}->{success} = 1;
}

1;
