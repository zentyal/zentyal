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

package EBox::Samba::CGI::DeleteUsers;
use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Gettext;

sub _checkForbiddenChars
{
    my ($self, $value) = @_;
    # POSIX::setlocale(LC_ALL, EBox::locale());
    #
    # unless ( $value =~ m{^[\w /.?&+:\-\@,=\{\}]*$} ) {
    #     my $logger = EBox::logger;
    #     $logger->info("Invalid characters in param value $value.");
    #     $self->{error} ='The input contains invalid characters';
    #     throw EBox::Exceptions::External(__("The input contains invalid " .
    #         "characters. All alphanumeric characters, plus these non " .
    #        "alphanumeric chars: ={},/.?&+:-\@ and spaces are allowed."));
    #     if (defined($self->{redirect})) {
    #         $self->{chain} = $self->{redirect};
    #     }
    #     return undef;
    # }
    no locale;
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/samba/delusers.mas', @_);
    bless($self, $class);
    $self->setRedirect('/Samba/Tree/Manage');
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{'title'} = __('Users');

    my @args = ();
    my @users = ();
    my $deluser = $self->unsafeParam('deluser');
    if (defined $deluser and $deluser eq 1) {
        my @dns = $self->unsafeParam('dn[]');
        foreach my $dn (@dns) {
            my $user = new EBox::Samba::User(dn => $dn);
            $self->{json} = { success => 0 };
            $user->deleteObject();
            $self->{json}->{success} = 1;
            $self->{json}->{redirect} = '/Samba/Tree/Manage';
            $self->setRedirect('/Samba/Tree/Manage');
        }
    }else {
        $self->_requireParam('dns[]', 'dns[]');
        my @dns = $self->unsafeParam('dns[]');
        foreach my $dn (@dns) {
            my $user = new EBox::Samba::User(dn => $dn);
            # show dialog
            my $usersandgroups = EBox::Global->getInstance()->modInstance('samba');
            push(@users, $user);
            my $editable = $usersandgroups->editableMode();
            my $warns = $usersandgroups->allWarnings('user', $user);
            push(@args, warns => $warns);
        }
    }
    push(@args, users => \@users);
    $self->{params} = \@args;
}

1;
