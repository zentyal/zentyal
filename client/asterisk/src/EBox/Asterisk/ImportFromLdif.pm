# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Asterisk::ImportFromLdif;
use base 'EBox::UsersAndGroups::ImportFromLdif::Base';
#

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::AsteriskLdapUser;
use EBox::Asterisk::Extensions;

sub classesToProcess
{
    return [
            { class => 'AsteriskExtension', priority => 30  },
            { class => 'posixAccount',     priority => 35 },
           ];
}


my $ldapUser;
sub _ldapUser
{
    my ($package) = @_;

    if (not $ldapUser) {
        $ldapUser = EBox::AsteriskLdapUser->new();
    }

    return $ldapUser;
}


sub processPosixAccount
{
    my ($package, $entry) = @_;

    my $username = $entry->get_value('uid');
    my $ldapUser = $package->_ldapUser();

    # check if the user has asterisk enabled..
    my @objectClasses = $entry->get_value('objectClass');
    my $isSIPUser = grep {  $_ eq 'AsteriskSIPUser' } @objectClasses;
    $ldapUser->setHasAccount($username, $isSIPUser);

    if ($isSIPUser) {
        my $extensions  = EBox::Asterisk::Extensions->new();
        my $extn     = $entry->get_value('AstAccountCallerID');
        
        if (not $extensions->extensionExists($extn)) {
            $extensions->modifyUserExtension($username, $extn);
        }

        #my $mail     = $entry->get_value('AstAccountVMail');
    }

}


# here we will remvoe all non-user extensions
sub startupAsteriskExtension
{
    my ($package) = @_;
    my $extensions  = EBox::Asterisk::Extensions->new();

    my @exts = $extensions->extensions();
    foreach my $ext (@exts) {
        $extensions->delExtension($ext);
    }
}

# here we will porcess and recreate all non-user extensions
sub processAsteriskExtension
{
    my ($package, $entry) = @_;
    # we need to discrimate between user extensions (created automatically with
    # _addUser) and meeting, voicemails extensions that should be recreated here


    my $ext = $entry->get_value('AstExtension');

    if (not ($ext =~ m/^\d*-?\d+$/)) {
        # this mean that is a user extension bz the vlaue of the extension is
        # the username 

        # XXX in the future we will use non-nuemric extensions which will not be
        # user extensions. We wil have to look to extension type, app data or
        # something to bette discriminate 
        return;
    }

    my ($extNumber) = split ('-', $ext);
    if ($extNumber <= EBox::Asterisk::Extensions::maxUserExtension()) {
        # user extensions are not recreated here
        return;
    }

    my $prio = $entry->get_value('AstPriority');
    my $app = $entry->get_value('AstApplication');
    my $appData = $entry->get_value('AstApplicationData');

    my $extensions  = EBox::Asterisk::Extensions->new();
    $extensions->addExtension($ext, $prio, $app, $appData);
}

# sub _noUserExtensions
# {
#     my ($package) = @_;

#     my $extensions  = EBox::Asterisk::Extensions->new();
#     my $maxUserExtension = $extensions->maxUserExtension();

#     my %args = (
#                 base => $extensions->extensionsDn(),
#                 filter => 'objectclass=AsteriskExtension',
#                 scope => 'sub',
#                );

#     my $result = $extensions->{ldap}->search(\%args);

#     my @extns = map { 
#         if ($_->get_value('AstExtension') > $maxUserExtension) {
#             $_->get_value('cn')                         
#         } else {
#             ()
#         }
#     } $result->entries();

#     return \@extns;
# }

1;
