# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::MailAliasLdap;

use EBox::Sudo;
use EBox::Global;
use EBox::Ldap;
use EBox::MailUserLdap;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Validate;
use EBox::MailVDomainsLdap;
use EBox::Samba::User;

use constant ALIASDN => 'cn=alias,cn=mail,cn=zentyal,cn=configuration';

sub new
{
    my ($class, $vdomainsLdap) = @_;
    my $self  = {};

    $self->{ldap} = EBox::Global->modInstance('samba')->ldap();

    if ($vdomainsLdap) {
        $self->{vdomains} = $vdomainsLdap;
    } else {
        $self->{vdomains} = new EBox::MailVDomainsLdap;
    }


    bless($self, $class);
    return $self;
}

# Method: addUserAlias
#
#     Creates a new mail alias to an account.
#
# Parameters:
#
#     user  - The user object
#     alias - The mail alias account to create
#     maildrop - The mail account(s) to send all mail
#
sub addUserAlias
{
    my ($self, $user, $alias) = @_;

    my $maildrop = $user->get('mail');
    $self->_checkAccountAlias($alias, $maildrop);

    my @otherMailbox = $user->get('otherMailbox');
    push @otherMailbox, $alias;
    $user->set('otherMailbox', \@otherMailbox);
}

# Method: delUserAlias
#
#     Removes a mail alias from the user
#
# Parameters:
#
#     user  - The user object
#     alias - The mail alias account to create
sub delUserAlias
{
    my ($self, $user, $alias) = @_;
    $user->deleteValues('otherMailbox' => $alias);
}

# Method: userAliases
#
#   Returns:
#     list with the user aliases
sub userAliases
{
    my ($self, $user) = @_;
    return $user->get('otherMailbox');
}


sub addExternalAlias
{
    my ($self, $vdomain, $alias, $maildrop) = @_;

    $self->_checkAccountAlias($alias, $maildrop, 1);

    my $user = $self->_accountUser($maildrop);
    if ($user) {
        throw EBox::Exceptions::External(
               __x('{ac} is not a external account', ac => $maildrop)
                                        );
    }

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
    my ($self, $alias, $maildrop, $noCheckExternalAliases) = @_;

    EBox::Validate::checkEmailAddress($alias, __('mail alias'));
    EBox::Global->modInstance('mail')->checkMailNotInUse($alias, onlyCheckLdap => $noCheckExternalAliases);

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
#     group - group object
#
sub addGroupAlias
{
    my ($self, $group, $alias) = @_;
    EBox::Validate::checkEmailAddress($alias, __('group alias'));
    EBox::Global->modInstance('mail')->checkMailNotInUse($alias);

    my $mail = $group->get('mail');
    if (not $mail) {
        throw EBox::Exceptions::External(
            __x('Cannot create alias because group {name} does not mail acocunt set',
                mail => $group->name
               )
        );
    }

    my ($user, $vdomain) = split('@', $mail, 2);
    if (not $self->{vdomains}->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} is not managed by Zentyal',
                                              d => $vdomain
                                            )
                                        );
    }

    my $id = $group->get('samAccountName');
    $self->_addCouriermailAliasLdapElement($id, $alias, $mail);
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

    my $vdomainsLdap =  $self->{vdomains};
    if (not $vdomainsLdap->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} does not exist',
                                              d => $vdomain
                                            )
                                        );
    }
    if ($vdomainsLdap->vdomainExists($alias)) {
                throw EBox::Exceptions::External(__x(
  'Cannot use {d} as alias for a mail domain because a domain which this name already exists',
                                              d => $alias
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

    my $vdomainsLdap =  $self->{vdomains};
    if (not $vdomainsLdap->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} does not exist',
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
    my $vdomainsLdap =  $self->{vdomains};
    if (not $vdomainsLdap->vdomainExists($vdomain)) {
        throw EBox::Exceptions::External(__x(
                                             'Mail domain {d} does not exist',
                                              d => $vdomain
                                            )
                                        );
    }

    my %attrs = (
            base => $self->aliasDn,
            filter => "&(objectclass=couriermailalias)(mailsource=\@$vdomain)",
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

    my $dn = "cn=$alias," . $self->aliasDn();
    my %attrs = (
                 attr => [
                          'objectclass'      => 'couriermailalias',
                          'mailsource'       => $id,
                          'mail'             => $alias,
                          'maildrop'         => $maildrop
                         ]
                );

    my $r = $self->{'ldap'}->add($dn, \%attrs);
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

    my $r = $self->{'ldap'}->delete("cn=$alias, " . $self->aliasDn);
}

# Method: delGrouopAlias
#
#     This method removes a group mail alias account
#
# Parameters:
#
#     alias - The mail alias account to delete
#
sub delGroupAlias
{
    my ($self, $alias) = @_;

    $self->delAlias($alias);
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
    my @mlist = map { $_->get_value('maildrop') } $result->sorted('mailsource');

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

    # We get also system groups (gid < 2000)
    my @groups = @{$user->groups()};

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

    my $cn = $group->get('samAccountName');
    my %args = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(mailsource=$cn)",
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

    my $aliasId = $group->get('mail');
    $aliasId or
        return undef;
    my %args = (
        base => $self->aliasDn,
        filter => "&(objectclass=couriermailalias)(mailsource=$aliasId)",
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

    my $users = EBox::Global->modInstance('samba');

    my %attrs = (
        base => $users->ldap()->dn(),
        filter => "&(|(objectclass=userZentyalMail)(objectclass=zentyalDistributionGroup))(mail=$alias)",
        scope => 'sub'
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
            $self->addExternalAlias($vdomain, $alias, $account);
        }

        delete $aliasToDelete{$alias};
    }

    # alias no present in the table must be deleted
    foreach my $alias (keys %aliasToDelete) {
        $self->delAlias($alias);
    }
}

1;
