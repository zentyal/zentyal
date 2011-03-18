# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::MailAliasLdap;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::MailUserLdap;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;
use EBox::Validate;
use EBox::MailVDomainsLdap;

use constant ALIASDN     => 'ou=mailalias,ou=postfix';

sub new
{
    my $class = shift;
    my $self  = {};

    $self->{ldap} = EBox::Global->modInstance('users')->ldap();

    bless($self, $class);

    return $self;
}

# Method: addAlias
#
#     Creates a new mail alias to an account.
#
# Parameters:
#
#     alias - The mail alias account to create
#     maildrop - The mail account(s) to send all mail
#     id - the username or groupname
#
sub addAlias
{
    my ($self, $alias, $maildrop, $id) = @_;

    $self->_checkAccountAlias($alias, $maildrop);

    my $user = $self->_accountUser($maildrop);
    if (not $user) {
        throw EBox::Exceptions::External(
               __x('{ac} is not a internal account', ac => $maildrop)
                                        );
    }

    $self->_addCouriermailAliasLdapElement($id, $alias, $maildrop);
}

sub addExternalAlias
{
    my ($self, $alias, $maildrop) = @_;

    $self->_checkAccountAlias($alias, $maildrop);

    my $user = $self->_accountUser($maildrop);
    if ($user) {
        throw EBox::Exceptions::External(
               __x('{ac} is not a external account', ac => $maildrop)
                                        );
    }

    my ($left, $vdomain) = split '@', $alias;

    $self->_addCouriermailAliasLdapElement("\@$vdomain", $alias, $maildrop);
}

sub _accountUser
{
    my ($self, $account) = @_;

    my $musers = EBox::Global->modInstance('mail')->{musers};

    return $musers->userByAccount($account);
}

sub _checkAccountAlias
{
    my ($self, $alias, $maildrop) = @_;

    EBox::Validate::checkEmailAddress($alias, __('mail alias'));

    # Verify alias not exists
    if ($self->accountExists($alias)) {
        throw EBox::Exceptions::DataExists('data' => __('mail account'),
                                                        'value' => $alias);
    }

    # Verify maildrop is not an alias
    # (For now it is not allowed alias of aliases)
    # XXX alias of aliases are harmless as far we know
    #if ($self->aliasExists($maildrop)) {
    #    throw EBox::Exceptions::External(
    #__x('{ac} is a mail alias. Alias of aliases are not allowed',
    #    ac => $maildrop)
    #                                    );
    #}
}

# Method: addGroupAlias
#
#     Creates a new mail alias to a group of users
#
# Parameters:
#
#     alias - The mail alias account to create
#     groupname - The group name.
#
sub addGroupAlias
{
    my ($self, $alias, $groupname) = @_;
    my $users = EBox::Global->modInstance('users');

    EBox::Validate::checkEmailAddress($alias, __('group alias'));

    if ($self->accountExists($alias)) {
        throw EBox::Exceptions::DataExists('data' => __('mail account'),
                                                        'value' => $alias);
    }

    my $mailUserLdap = EBox::MailUserLdap->new();

    my @mailAccounts = map {
        $mailUserLdap->userAccount($_)
    } $mailUserLdap->usersWithMailInGroup($groupname);

    my $first = 1;
    foreach my $mail (@mailAccounts) {
        if ($first) {
            $self->addAlias($alias, $mail, $groupname);
            $first = 0;
        } else {
            $self->addMaildrop($alias, $mail);
        }
    }

    $self->_addmailboxRelatedObject($alias, $groupname);
}

sub _addmailboxRelatedObject
{
    my ($self, $alias, $group) = @_;

    return if $self->_mailboxRelatedObjectInGroup($group);

    my $users = EBox::Global->modInstance('users');
    my $dn = $users->groupDn($group);

    my %attrs = (
                 changes => [
                         add => [
                                   'objectClass'           => 'mailboxRelatedObject',
                                   'mail'                  => $alias,
                                   ]
                         ],
                );

    my $r = $self->{ldap}->modify($dn, \%attrs);
}

sub _delmailboxRelatedObject
{
    my ($self, $alias, $group) = @_;

    return unless $self->_mailboxRelatedObjectExists($alias);

    my $users = EBox::Global->modInstance('users');
    my $dn = $users->groupDn($group);

    my %attrs = (
                 changes => [
                         delete => [
                                   'objectClass'           => 'mailboxRelatedObject',
                                   'mail'                  => $alias,
                                   ]
                         ],
                );

    my $r = $self->{ldap}->modify($dn, \%attrs);
}

sub _mailboxRelatedObjectInGroup
{
    my ($self, $group) = @_;

    my $users = EBox::Global->modInstance('users');

    my %attrs = (
        base => $users->groupsDn(),
        filter => "&(objectclass=mailboxRelatedObject)(cn=$group)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);
    my $entry = $result->entry(0);

    return $entry->get_value('mail') if ($result->count() != 0);
}

sub _mailboxRelatedObjectExists
{
    my ($self, $alias) = @_;

    my $users = EBox::Global->modInstance('users');

    my %attrs = (
        base => $users->groupsDn(),
        filter => "&(objectclass=mailboxRelatedObject)(mail=$alias)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);

    return ($result->count > 0);
}

# Method: addVDomainALias
#
#     Creates a new domain alias  for a mail domain
#
# Parameters:
#
#     vdomain - The mail domain for aliasing
#     alias   - The mail alias domain  to create
#
sub addVDomainAlias
{
    my ($self, $vdomain, $alias) = @_;

    EBox::Validate::checkDomainName($alias, __('Domain alias'));

    my $vdomainsLdap =  EBox::MailVDomainsLdap->new();
    if (not $vdomainsLdap->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} does not exists',
                                              d => $vdomain
                                            )
                                        );
    }
    if ($vdomainsLdap->vdomainExists($alias)) {
                throw EBox::Exceptions::External(__x(
  'Cannot use {d} as alias for a mail domain because a domain which this name already exists',
                                              d => $vdomain
                                            )
                                        );
    }

    if ($self->aliasExists($alias)) {
        throw EBox::Exceptions::DataExists(data => __('Domain alias'));
    }

    $alias = '@' . $alias;
    $vdomain = '@' . $vdomain;
    $self->_addCouriermailAliasLdapElement($vdomain, $alias, $vdomain);
}

# Method: vdomainAliases
#
#     return all the domain alias for a domain.
#
# Parameters:
#
#     vdomain - The mail domain
#
sub vdomainAliases
{
    my ($self, $vdomain) = @_;

    my $vdomainsLdap =  EBox::MailVDomainsLdap->new();
    if (not $vdomainsLdap->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} does not exists',
                                              d => $vdomain
                                            )
                                        );
    }

    my %attrs = (
            base => $self->aliasDn,
            filter => "&(objectclass=couriermailalias)(maildrop=@".$vdomain.")",
            scope => 'sub'
                );

    my $result = $self->{'ldap'}->search(\%attrs);

    my @alias = map { $_->get_value('mail')} $result->sorted('mail');

    return \@alias;
}

sub externalAccountAliases
{
    my ($self, $vdomain) = @_;
    my $vdomainsLdap =  EBox::MailVDomainsLdap->new();
    if (not $vdomainsLdap->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} does not exists',
                                              d => $vdomain
                                            )
                                        );
    }

    my %attrs = (
            base => $self->aliasDn,
            filter => "&(objectclass=couriermailalias)(uid=\@$vdomain)",
            scope => 'sub'
                );

    my $result = $self->{'ldap'}->search(\%attrs);

    my @alias;
    foreach my $entry ($result->sorted('maildrop')) {
        my $mail = $entry->get_value('mail');
        if ($mail =~ m/^\@/) {
            # vdomain alias, skipping
            next;
        }

        push @alias, $mail;
    }

    return \@alias;
}

sub _addCouriermailAliasLdapElement
{
    my ($self, $id, $alias, $maildrop) = @_;

    my $dn = "mail=$alias, " . $self->aliasDn();
    my %attrs = (
                 attr => [
                          'objectclass'           => 'couriermailalias',
                          'objectclass'           =>      'account',
                          'userid'                => $id,
                          'mail'                  => $alias,
                          'maildrop'              => $maildrop
                         ]
                );

    my $r = $self->{'ldap'}->add($dn, \%attrs);
}

# Method: updateGroupAliases
#
#     When a change on users of a group this method updates the maildrops of the
#     mail alias account.
#
# Parameters:
#
#     group - The group name
#
sub updateGroupAliases
{
    my ($self, $group) = @_;

    foreach my $alias (@{ $self->groupAliases($group) }) {
        $self->delAlias($alias);
        $self->addGroupAlias($alias, $group);
    }
}

# Method: addMaildrop
#
#     This method adds a new maildrop to an existing mail alias account (used on
#     group mail alias accounts).
#
# Parameters:
#
#     alias - The mail alias account to create
#     maildrop - The mail account to add to the alias account
#
sub addMaildrop
{
    my ($self, $alias, $maildrop) = @_;

    unless ($self->aliasExists($alias)) {
        throw EBox::Exceptions::DataNotFound('data' => __('mail alias account'),
                                                          'value' => $alias);
    }

    my $dn = "mail=$alias, " . $self->aliasDn();

    my %attrs = (
        changes => [
            add => [ 'maildrop' => $maildrop ]
        ]
    );

    my $r = $self->{'ldap'}->modify($dn, \%attrs);
}

# Method: delMaildrop
#
#     This method removes a maildrop to an existing mail alias account (used on
#     group mail alias accounts).
#
# Parameters:
#
#     alias - The mail alias account to create
#     maildrop - The mail account to add to the alias account
#
sub delMaildrop
{
    my ($self, $alias, $maildrop) = @_;

    unless ($self->aliasExists($alias)) {
        throw EBox::Exceptions::DataNotFound('data' => __('mail alias account'),
                                                          'value' => $alias);
    }

    my $dn = "mail=$alias, " . $self->aliasDn();

    #if is the last maildrop delete the alias account
    my @mlist = @{$self->accountListByAliasGroup($alias)};
    my %attrs;

    if (@mlist == 1) {
        $self->delAlias($alias);
    } else {
        %attrs = (
            changes => [
                delete => [ 'maildrop'  => $maildrop ]
            ]
        );
        my $r = $self->{'ldap'}->modify($dn, \%attrs);
    }
}

# Method: delAlias
#
#     This method removes a mail alias account
#
# Parameters:
#
#     alias - The mail alias account to create
#
sub delAlias
{
    my ($self, $alias) = @_;

    unless ($self->aliasExists($alias)) {
        throw EBox::Exceptions::DataNotFound('data' => __('mail alias account'),
                                                        'value' => $alias);
    }

    # We Should warn about users whose mail account belong to this vdomain.

    my $r = $self->{'ldap'}->delete("mail=$alias, " . $self->aliasDn);
}

# Method: delGrouopAlias
#
#     This method removes a group mail alias account
#
# Parameters:
#
#     alias - The mail alias account to delete
#     group - The group
#
sub delGroupAlias
{
    my ($self, $alias, $group) = @_;

    $self->delAlias($alias);

    $self->_delmailboxRelatedObject($alias, $group);

    my @aliases = @{$self->groupAliases($group)};
    if (@aliases and not $self->_mailboxRelatedObjectInGroup($group)) {
        $alias = shift @aliases;
        $self->_addmailboxRelatedObject($alias, $group);
    }
}

# Method: delAliasesFromVDomain
#
#     This method removes all mail aliases from a virtual domain
#
# Parameters:
#
#     vdomain - The Virtual domain name
#
sub delAliasesFromVDomain
{
    my ($self, $vdomain) = @_;

    my @aliases = @{$self->_allAliasFromVDomain($vdomain)};

    foreach (@aliases) {
        $self->delAlias($_);
    }
}

# Method: accountAlias
#
#     This method returns all mail alias accounts that have a mail account of
#     a user
#
# Parameters:
#
#     mail - The mail account
#
sub accountAlias
{
    my ($self, $mail) = @_;

    my %args = (
        base => $self->aliasDn,
        filter => "&(userid=$mail)(maildrop=$mail)",
        scope => 'one',
        attrs => ['mail']
    );

    my $result = $self->{ldap}->search(\%args);

    my @malias = ();
    foreach my $alias ($result->sorted('mail'))
    {
        @malias = (@malias, $alias->get_value('mail'));
    }

    return @malias;
}

# Method: groupAccountAlias
#
#     This method returns all mail group alias accounts that have a mail account
#     of a user
#
# Parameters:
#
#     mail - The mail account
#
sub groupAccountAlias
{
    my ($self, $mail) = @_;

    my %args = (
        base => $self->aliasDn,
        filter => "&(!(userid=$mail))(maildrop=$mail)",
        scope => 'one',
        attrs => ['mail']
    );

    my $result = $self->{ldap}->search(\%args);

    my @malias = ();
    foreach my $alias ($result->sorted('mail'))
    {
        @malias = (@malias, $alias->get_value('mail'));
    }

    return @malias;
}

# Method: accountListByAliasGroup
#
#     This method returns an array ref with all maildrops of a group alias account
#
# Parameters:
#
#     mail - The mail aliasaccount
#
# Returns:
#
#     array ref - Array that contains mail accounts
#
sub accountListByAliasGroup
{
    my ($self, $mail) = @_;

    my %args = (
        base => $self->aliasDn,
        filter => "(mail=$mail)",
        scope => 'one',
        attrs => ['maildrop']
    );

    my $result = $self->{ldap}->search(\%args);

    my @mlist = map { $_->get_value('maildrop') } $result->sorted('uid');

    return \@mlist;
}

# Method: aliasDn
#
#     This method returns the DN of alias ldap leaf
#
# Returns:
#
#     string - DN of alias leaf
#
sub aliasDn
{
    my ($self) = @_;

    return ALIASDN . "," . $self->{ldap}->dn;
}

# Method: listMailGroupsByUser
#
#     This method returns all groups whith an alias account which the user passed
#     as parameter belongs.
#
# Parameters:
#
#     user - usename
#
# Returns:
#
#     array - With the group's name list
#
sub listMailGroupsByUser
{
    my ($self, $user) = @_;

    my %groupsWithAlias;
    my $users = EBox::Global->modInstance('users');

    # We get also system groups (gid < 2000)
    my @groups = @{$users->groupsOfUser($user, 1)};

    foreach my $group (@groups) {
        if ($self->groupHasAlias($group)) {
            $groupsWithAlias{$group} = 1;
        }
    }

    return keys %groupsWithAlias;
}

# Method: groupAliases
#
#     This method returns the mail alias accounts of a group
#
# Parameters:
#
#     group - The group name
#
# Returns:
#     array reference - mail alias accounts
#
sub groupAliases
{
    my ($self, $group) = @_;

    my %args = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(uid=$group)",
        scope => 'sub',
        attrs => ['mail']
    );

    my $result = $self->{ldap}->search(\%args);

    my @aliases = map { $_->get_value('mail')  }$result->sorted('mail');

    return \@aliases;
}

# Method: groupHasAlias
#
#     This method returns if the group has any mail alias account
#
# Parameters:
#
#     group - The group name
#
# Returns:
#
#     true if the group has any alias account, false otherwise
#
sub groupHasAlias
{
    my ($self, $group) = @_;

    my %args = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(uid=$group)",
        scope => 'one',
        attrs => ['mail']
    );

    my $result = $self->{ldap}->search(\%args);

    return ($result->count > 0);
}

# Method: aliasExists
#
#     This method returns wether a given alias exists
#
# Parameters:
#
#     mail - The mail account
#
sub aliasExists
{
    my ($self, $alias) = @_;

    my %attrs = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(mail=$alias)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);

    return ($result->count > 0);
}

# Method: accountExists
#
#     This method returns an account exists like an alias account or mail account
#
# Parameters:
#
#     mail - The mail account
#
# Returns:
#
#     true if the account exists, false otherwise
#
sub accountExists
{
    my ($self, $alias) = @_;

    my $users = EBox::Global->modInstance('users');

    my %attrs = (
        base => $users->usersDn,
        filter => "&(objectclass=couriermailaccount)(mail=$alias)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);

    return (($result->count > 0) || ($self->aliasExists($alias)));
}

# Method: accountsByAlias
#
#     given an alias address return all the accounts that are alaised
#
# Params:
#
#     alias - alias addres
#
# Returns:
#
#     reference a list with the accounts  or undef if there is not alias or
#     not aliased addresses
#
sub accountsByAlias
{
    my ($self, $alias) = @_;

    my %attrs = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(mail=$alias)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);
    if ($result->count() == 0) {
        return [];
    }

    my $entry = $result->entry(0);
    my @accounts = $entry->get_value('maildrop');

    return \@accounts;
}

# Method: _allAliasFromVDomain
#
#     This method returns all mail alias accounts and domain aliases from/for
#     a virtual domain
#
# Parameters:
#
#     vdomain - The Virtual domain name
#
# Returns:
#
#     array ref - with all alias account from a virtual domain.
#
sub _allAliasFromVDomain
{
    my ($self, $vdomain) = @_;

    my %attrs = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(mail=*@".$vdomain.")",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);

    my @alias = map { $_->get_value('mail') } $result->sorted('mail');

    push @alias, @{ $self->vdomainAliases($vdomain) };

    return \@alias;
}

sub _syncVDomainAliasTable
{
    my ($self, $vdomain, $aliasTable) = @_;

    my %aliasToDelete = map { $_ => 1 } @{ $self->vdomainAliases($vdomain) };

    foreach my $alias (@{ $aliasTable->aliases() }) {
        my $fullAlias = '@' . $alias;

        if (not $self->aliasExists($fullAlias)) {
            $self->addVDomainAlias($vdomain, $alias);
        }

        delete $aliasToDelete{$fullAlias};
    }

    # alias no present in the table must be deleted
    foreach my $alias (keys %aliasToDelete) {
        $self->delAlias($alias);
    }
}

sub _syncExternalAliasTable
{
    my ($self, $vdomain, $aliasTable) = @_;

    my %aliasToDelete = map { $_ => 1 } @{ $self->externalAccountAliases($vdomain) };

    foreach my $alias_r (@{ $aliasTable->aliasesAndExternalAccounts() }) {
        my ($alias, $account) = @{ $alias_r };

        if (not $self->aliasExists($alias)) {
            $self->addExternalAlias($alias, $account);
        }

        delete $aliasToDelete{$alias};
    }

    # alias no present in the table must be deleted
    foreach my $alias (keys %aliasToDelete) {
        $self->delAlias($alias);
    }
}

1;
