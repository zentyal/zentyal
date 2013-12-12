# Copyright (C) 2004-2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::CGI::SysInfo::Password;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{chain} = "SysInfo/General";
    $self->{errorchain} = "SysInfo/General";
    return $self;
}

sub _process
{
    my ($self) = @_;

    if (defined($self->param('password'))) {
        my $username = $self->unsafeParam('username');
        if (not $username) {
            throw EBox::Exceptions::DataMissing(data =>  __('Username'));
        }

        my $curpwd = $self->unsafeParam('currentpwd');
        if (not $curpwd) {
            throw EBox::Exceptions::DataMissing(data =>  __('Password'));
        }

        my $newpwd1 = $self->unsafeParam('newpwd1');
        my $newpwd2 = $self->unsafeParam('newpwd2');
        defined($newpwd1) or $newpwd1 = "";
        defined($newpwd2) or $newpwd2 = "";

        unless (EBox::Auth->checkValidUser($username, $curpwd)) {
            throw EBox::Exceptions::External(__('Incorrect '.
                        'password.'));
        }

        unless ($newpwd1 eq $newpwd2) {
            throw EBox::Exceptions::External(__('New passwords do'.
                        ' not match.'));
        }

        unless (length($newpwd1) > 5) {
            throw EBox::Exceptions::External(__('The password must'.
                        ' be at least 6 characters long'));
        }
        EBox::Auth->setPassword($username, $newpwd1);
        $self->{msg} = __('The password was changed successfully.');

        my $audit = EBox::Global->modInstance('audit');
        $audit->logAction('System', 'General', 'changePassword', $username);
    }
}

1;
