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

package EBox::MailUserLdap;

use base qw(EBox::LdapUserBase);

use EBox::Sudo;
use EBox::Global;
use EBox::Ldap;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Model::Manager;
use EBox::Gettext;
use EBox::Samba::User;
use EBox::MailVDomainsLdap;
use TryCatch;

use Perl6::Junction qw(any);

use constant DIRVMAIL   =>      '/var/vmail/';
use constant SIEVE_SCRIPTS_DIR => '/var/vmail/sieve';
use constant MAX_MAILDIR_BACKUPS => 5;

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

# Method: mailboxesDir
#
#  Returns:
#    directory where the mailboxes resides
sub mailboxesDir
{
    return DIRVMAIL;
}

# Method: setupUsers
#
#  Set up existent users for working correctly when the given vdomain or with
#  all vdomains
#
#  Parameters:
#
#  onlyForVDomain - set up users for this vdomain. Omitting it will
#                    trigger the setup for all vdomains
sub setupUsers
{
    my ($self, $vdomain) = @_;
    my $userMod = EBox::Global->getInstance()->modInstance('samba');

    foreach my $user (@{ $userMod->users() }) {
        my $mail = $user->get('mail');
        if ($mail) {
            my ($lhs, $rhs) = split '@', $mail, 2;

            if ($vdomain and ($rhs ne $vdomain)) {
                next;
            }

            $user->delete('mail');
            $self->setUserAccount($user, $lhs, $rhs);
        }
    }
}

# Method: setUserAccount
#
#  This method sets a mail account to a user.
#  The user may be a system user
#
# Parameters:
#
#               user - user object
#               lhs - Either the left hand side of a mail (the foo on foo@bar.baz account) or
#                     the full mail account (don't supply rhs in that case)
#               rhs - the right hand side of a mail (the bar.baz on previous account)

sub setUserAccount
{
    my ($self, $user, $lhs, $rhs)  = @_;
    my $mail = EBox::Global->modInstance('mail');
    my $email;
    if (not $rhs) {
        $email = $lhs;
        ($lhs, $rhs) = split '@', $email, 2;
    } else {
        $email = $lhs . '@' . $rhs;
    }

    EBox::Validate::checkEmailAddress($email, __('mail account'));
    $mail->checkMailNotInUse($email, owner => $user);

    if (not $self->{vdomains}->vdomainExists($rhs)) {
        # vdomain not managed by zentyal, just set the mail attribute
        $user->set('mail', $email);
        return;
    }

    # FIXME: this breaks migration from 3.4
    #$self->_checkMaildirNotExists($lhs, $rhs);

    my $quota = $mail->defaultMailboxQuota();

    foreach my $class (qw(userZentyalMail fetchmailUser)) {
        if (not $user->hasObjectClass($class)) {
            $user->add('objectclass', $class)
        }
    }

    $user->clearCache();

    $user->set('mail', $email, 1);
    $user->set('mailbox', $rhs.'/'.$lhs.'/', 1);
    $user->set('userMaildirSize', 0, 1);
    $user->set('mailquota', $quota, 1);
    $user->set('mailHomeDirectory', DIRVMAIL, 1);

    $user->save();

    my $dir = DIRVMAIL . "/$rhs/$lhs";
    unless (EBox::Sudo::fileTest('-e', $dir)) {
        $self->_createMaildir($lhs, $rhs);
    }
}

# Method: delUserAccount
#
#  This method removes a mail account to a user
#
# Parameters:
#
#   user - user object
#
sub delUserAccount
{
    my ($self, $user) = @_;
    my $usermail = $self->userAccount($user);
    if (not $usermail) {
        return;
    }
    if (not $self->_accountIsManaged($user)) {
        $user->delete('mail');
        return;
    }

    my $mail = EBox::Global->modInstance('mail');
    # First we remove all mail aliases asociated with the user account.
    $user->delete('otherMailbox');

    # get the mailbox attribute for later use..
    my $mailbox = $user->get('mailbox');

    $user->remove('objectClass', 'userZentyalMail', 1);
    $user->remove('objectClass', 'fetchmailUser', 1);
    $user->delete('mail', 1);
    $user->delete('mailbox', 1);
    $user->delete('userMaildirSize', 1);
    $user->delete('mailquota', 1);
    $user->delete('mailHomeDirectory', 1);
    $user->delete('fetchmailAccount', 1);
    $user->save();

    my @cmds;
    # Here we remove mail directorie of user account.
    push (@cmds, '/bin/rm -rf ' . DIRVMAIL . $mailbox);

    # remove user's sieve scripts dir
    my ($lhs, $rhs) = split '@', $usermail;
    my $sieveDir   = $self->_sieveDir($usermail, $rhs);
    push (@cmds, "/bin/rm -rf $sieveDir");

    EBox::Sudo::root(@cmds);
}

# Method: userAccount
#
#  return the user mail account or undef if it doesn't exists
#
sub userAccount
{
    my ($self, $user) = @_;

    return $user->get('mail');
}

# Method: userByAccount
#
#    given an account returns the user that has it assigened. It does not work
#    with alias. (I suggest to use EBox::MailAliasLdap::getAccountsByAlias or
#    EBox::MailAliasLdap::getAccountsByAlia::aliasExist) before to take care of
#    alias)
#
#   Params:
#       account -email account
#
#   Returns:
#          the user or undef if there is not account
# TODO: REVIEW
sub userByAccount
{
    my ($self, $account) = @_;

    my $mail = EBox::Global->modInstance('mail');

    my %args = (
                base => $self->{ldap}->dn(),
                filter => "&(objectclass=person)(mail=$account)",
                scope => 'sub',
                attrs => ['samAccountName'],
               );

    my $result = $self->{ldap}->search(\%args);
    if ($result->count() == 0) {
        return undef;
    }

    my $entry = $result->entry(0);
    my $usermail = $entry->get_value('samAccountName');

    return $usermail;
}

# Method: delAccountsFromVDomain
#
#  This method removes all mail accounts from a virtual domain
#
# Parameters:
#
#               vdomain - the virtual domain name
sub delAccountsFromVDomain   #vdomain
{
    my ($self, $vdomain) = @_;

    my %accs = %{$self->allAccountsFromVDomain($vdomain)};
    while (my ($uid, $mail) = each %accs) {
        my $user = new EBox::Samba::User(samAccountName => $uid);
        $mail = $accs{$uid};

        $self->delUserAccount($user, $accs{$uid});
    }
}

sub setGroupAccount
{
    my ($self, $group, $mail) = @_;
    my $mailMod = EBox::Global->modInstance('mail');

    EBox::Validate::checkEmailAddress($mail, __('mail account'));
    $mailMod->checkMailNotInUse($mail, owner => $group);

    $group->set('mail', $mail);
}

sub delGroupAccount
{
    my ($self, $group) = @_;

    my $mailMod = EBox::Global->modInstance('mail');
    my @groupAliases = @{ $mailMod->{malias}->groupAliases($group) };
    foreach my $alias (@groupAliases) {
        $mailMod->{malias}->delAlias($alias);
    }

    $group->delete('mail');
}

# Method: _addUser
#
#   Overrides <EBox::Samba::LdapUserBase> to create a default mail
#   account user@domain if the admin has enabled the auto email account creation
#   feature
sub _addUser
{
    my ($self, $user, $passwd) = @_;

    return unless (EBox::Global->modInstance('mail')->configured());

    my $mail = EBox::Global->modInstance('mail');
    my @vdomains = $mail->{vdomains}->vdomains();
    return unless (@vdomains);

    my $model = $mail->model('MailUser');
    return unless ($model->enabledValue());
    my $vdomain = $model->domainValue();
    return unless ($vdomain and $mail->{vdomains}->vdomainExists($vdomain));

    try {
        $self->setUserAccount($user, lc($user->name()), $vdomain);
    } catch {
       EBox::info("Creation of email account for $user failed");
    }
}

sub _delGroup
{
    my ($self, $group) = @_;
    my $mail = EBox::Global->modInstance('mail');

    return unless ($mail->configured());

    $self->delGroupAccount($group);
}

sub _delGroupWarning
{
    my ($self, $group) = @_;

    return unless (EBox::Global->modInstance('mail')->configured());

    my $mail = EBox::Global->modInstance('mail');

    my $txt = __('This group has a mail alias');

    if ($mail->{malias}->groupHasAlias($group)) {
        return ($txt);
    }

    return undef;
}

sub _delUser
{
    my ($self, $user) = @_;

    return unless (EBox::Global->modInstance('mail')->configured());

    $self->delUserAccount($user);
}

sub _delUserWarning
{
    my ($self, $user) = @_;

    return unless (EBox::Global->modInstance('mail')->configured());

    my $txt = __('This user has a mail account');

    if ($self->_accountIsManaged($user)) {
        return ($txt);
    }

    return undef;
}

sub _managedAccount
{
    my ($self, $account, $vdomains) = @_;
    my ($leftover, $accountVDomain) = split '@', $account, 2;
    foreach my $vd (@{ $vdomains }) {
        if ($accountVDomain eq $vd) {
            return 1;
        }
    }
    return 0;
}

sub _userAddOns
{
    my ($self, $user) = @_;

    my $mail = EBox::Global->modInstance('mail');

    return undef unless ($mail->configured());

    my $usermail = $self->userAccount($user);
    my @vdomains =  $mail->{vdomains}->vdomains();
    my @aliases;
    my $managed;
    if ($usermail) {
        @aliases = $mail->{malias}->userAliases($user);
        $managed = $self->_managedAccount($usermail, \@vdomains);
    }

    my $quotaType = $self->maildirQuotaType($user);
    my $quota   = $self->maildirQuota($user);

    my $externalRetrievalEnabled = $mail->model('RetrievalServices')->value('fetchmail');
    my @externalAccounts = map {
        $mail->{fetchmail}->externalAccountRowValues($_)
     } @{ $mail->{fetchmail}->externalAccountsForUser($user) };

    my @paramsList = (
            user        => $user,
            mail        => $usermail,
            aliases     => \@aliases,
            vdomains    => \@vdomains,
            managed     => $managed,

            maildirQuotaType => $quotaType,
            maildirQuota => $quota,

            service => $mail->service,

            externalRetrievalEnabled => $externalRetrievalEnabled,
            externalAccounts => \@externalAccounts,
    );

    my $title;
    if  (not @vdomains) {
        $title = __('Mail account');
    } elsif (not $usermail) {
        $title =  __('Create mail account');
    } else {
        $title = __('Mail account settings');
    }

    return {
        title  => $title,
        path   => '/mail/account.mas',
        params => { @paramsList }
       };
}

sub _groupAddOns
{
    my ($self, $group) = @_;

    my $mailMod = EBox::Global->modInstance('mail');
    return unless ($mailMod->configured());

    my $mailManaged = 0;
    my $mail = $group->get('mail');
    if ($mail) {
        my ($left, $vdomain) = split('@', $mail, 2);
        $mailManaged = $mailMod->{vdomains}->vdomainExists($vdomain);
    } else {
        $mail = '';
    }

    my $aliases = $mailMod->{malias}->groupAliases($group);
    my @vd      = $mailMod->{vdomains}->vdomains();

    my $args = {
        'group'    => $group,
        'vdomains' => \@vd,
        'aliases'  => $aliases,
        'service'  => $mailMod->service(),
        'mail'         => $mail,
        'mailManaged' => $mailManaged
    };

    return {
        title  => __('Mail alias settings'),
        path   => '/mail/groupalias.mas',
        params => $args
       };
}

# sub _modifyGroup
# {
#     my ($self, $group) = @_;

#     return unless (EBox::Global->modInstance('mail')->configured());

#     my $mail = EBox::Global->modInstance('mail');
#     $mail->{malias}->updateGroupAliases($group);
# }

# Method: _accountIsManaged
#
#  This method returns if a user has a managed user acocunt
#
# Parameters:
#
#   user - user object
#
# Returns:
#
#               bool - true if user has a managed mail account
sub _accountIsManaged
{
    my ($self, $user) = @_;

    my $username = $user->name();
    my %attrs = (
                 base => $self->{ldap}->dn(),
                 filter => "&(objectclass=userZentyalMail)(samAccountName=$username)",
                 scope => 'sub'
                );

    my $result = $self->{ldap}->search(\%attrs);

    return ($result->count > 0);
}

sub _accountExistsToDelete
{
    my ($self, $user) = @_;
    my $username = $user->get('samAccountName');
    my $attrs = {
        base => $self->{ldap}->dn(),
        filter => "&(objectclass=userZentyalMail)(samAccountName=$username)",
        scope => 'sub',
    };
    my $result = $self->{ldap}->search($attrs);
    return ($result->count() > 0);
}

# Method: allAccountFromVDomain
#
#  This method returns all accounts from a virtual domain
#
# Parameters:
#
#               vdomain - The Virtual domain name
#
# Returns:
#
#               hash ref - with (uid, mail) pairs of the virtual domain
sub allAccountsFromVDomain
{
    my ($self, $vdomain) = @_;

    my %attrs = (
                 base => $self->{ldap}->dn(),
                 filter => "&(objectclass=person)(mail=*@".$vdomain.")",
                 scope => 'sub'
                );

    my $result = $self->{ldap}->search(\%attrs);

    my %accounts = map { $_->get_value('samAccountName'), $_->get_value('mail')} $result->sorted('uid');

    return \%accounts;
}

# Method: usersWithMailInGroup
#
#  This method returns the list of users with mail account on the group
#
# Parameters:
#
#  group - group object
#
sub usersWithMailInGroup
{
    my ($self, $group) = @_;

    my $groupdn = $group->dn();
    my %args = (
        base => $self->{ldap}->dn(),
        filter => "(&(objectclass=userZentyalMail)(memberof=$groupdn))",
        scope => 'sub',
    );

    my $result = $self->{ldap}->search(\%args);

    my $usersMod = EBox::Global->modInstance('samba');
    my @mailusers;
    foreach my $entry ($result->entries()) {
        my $object = $usersMod->entryModeledObject($entry);
        push (@mailusers, $object) if ($object);
    }

    return @mailusers;
}

# Method: checkUserMDSize
#
#  This method returns all users that should be warned about a reduction on the
#  maildir size
#
# Parameters:
#
#               vdomain - The Virtual domain name
#               newmdsize - The new maildir size
sub checkUserMDSize
{
    my ($self, $vdomain, $newmdsize) = @_;

    my %accounts = %{$self->allAccountsFromVDomain($vdomain)};
    my @warnusers = ();
    my $size = 0;

    foreach my $acc (keys %accounts) {
        $size = $self->maildirQuota($acc);
                ($size > $newmdsize) and push (@warnusers, $acc);
    }

    return \@warnusers;
}

sub _checkMaildirNotExists
{
    my ($self, $lhs, $vdomain) = @_;
    my $dir = DIRVMAIL . "/$vdomain/$lhs";

    if (EBox::Sudo::fileTest('-e', $dir)) {

        my $backupDirBase = $dir ;
        $backupDirBase =~ s{/$}{};
        $backupDirBase .= '.bak';

        my $counter = 1;
        my $backupDir = $backupDirBase . '.' . $counter;
        while (EBox::Sudo::fileTest('-e', $backupDir)) {
            $counter += 1;
            if ($counter <= MAX_MAILDIR_BACKUPS) {
                $backupDir = $backupDirBase . '.' . $counter;
            } else {
                EBox::error("Maximum number of backup directories for $dir reached. We will remove the last one ($backupDir) and use it again");
                EBox::Sudo::root("rm -rf $backupDir");
                last;
            }
        }

        EBox::Sudo::root("mv $dir $backupDir");
        EBox::warn("Mail directory $dir already existed, moving it to $backupDir");
    }
}

# Method: _createMaildir
#
#  This method creates the maildir of an account
#
# Parameters:
#
#               lhs - left hand side of an account (foo on foo@bar.baz)
#               vdomain - Virtual Domain name
sub _createMaildir
{
    my ($self, $lhs, $vdomain) = @_;
    my $vdomainDir = "/var/vmail/$vdomain";
    my $userDir   =  "$vdomainDir/$lhs/";

    my @cmds;
    push (@cmds, '/bin/mkdir -p /var/vmail');
    push (@cmds, '/bin/chmod 2775 /var/mail/');
    push (@cmds, '/bin/chown ebox.ebox /var/vmail/');

    push (@cmds, "/bin/mkdir -p $vdomainDir");
    push (@cmds, "/bin/chown ebox.ebox $vdomainDir");
    push (@cmds, "/usr/bin/maildirmake.dovecot $userDir/Maildir ebox");
    push (@cmds, "/bin/chown ebox.ebox -R $userDir");
    EBox::Sudo::root(@cmds);
}

sub _sieveDir
{
    my ($self, $lhs, $vdomain) = @_;
    return SIEVE_SCRIPTS_DIR . "/$vdomain/$lhs";
}

#  Method: maildir
#
#     get the maildir which will be used by the given account
#
#   Parameters:
#               lhs - left hand side of an account (foo on foo@bar.baz)
#               vdomain - Virtual Domain name
#
#   Returns:
#         full path of the maildir
sub maildir
{
    my ($class, $lhs, $vdomain) = @_;

    return "/var/vmail/$vdomain/$lhs/";
}

#  Method: maildirQuota
#
#     get the maildir quota for the user, please note that is only the quota
#     amount this does not signals wether it is a default quota or a custom quota
#
#   Parameters:
#        user - name of the user
sub maildirQuota
{
    my ($self, $user) = @_;
    return $user->get('mailquota');
}

#  Method: maildirQuotaType
#
#     get the type of the quota assigned to the user
#
#   Parameters:
#        user - user object
#
#    Returns:
#       one of this strings:
#          'default' - uses default quota type
#          'noQuota' - the user has a custom unlimtied quota
#          'custom'  - the user has a non-unlimted custom quota
sub maildirQuotaType
{
    my ($self, $user)  = @_;

    my $userQuota = $user->get('userMaildirSize');
    if (not $userQuota) {
        return 'default';
    }

    my $quota = $self->maildirQuota($user);
    if ($quota == 0) {
        return 'noQuota';
    } else {
        return 'custom';
    }

    return 'default';
}

#  Method: setMaildirQuotaUsesDefault
#
#     sets wether the user is using the default quota or not. Additionally if
#     user is set to use the default quota the quota value is synchronized with
#     the default quota
#
#   Parameters:
#        user - user object
#        isDefault - wether the user is using the default quota
sub setMaildirQuotaUsesDefault
{
    my ($self, $user, $isDefault) = @_;

    my $userMaildirSizeValue = $isDefault ? 0 : 1;
    $user->set('userMaildirSize', $userMaildirSizeValue, 1);
    if ($isDefault) {
        # sync quota with default
        my $mail = EBox::Global->modInstance('mail');
        my $defaultQuota = $mail->defaultMailboxQuota();
        $user->set('mailquota', $defaultQuota, 1);
    }
    $user->save();
}

#  Method: setMaildirQuota
#
#     sets the quota value for a user. Do not use it with users which use
#     default quota; in this case use only setMaildirQuotaUsesDefault
#
#   Parameters:
#        user - name of the user
#        quota - numeric value of the quota in Mb
sub setMaildirQuota
{
    my ($self, $user, $quota) = @_;
    defined $user or
        throw EBox::Exceptions::MissingArgument('user');
    defined $quota or
        throw EBox::Exceptions::MissingArgument('quota');

    if (not $self->userAccount($user)) {
        throws EBox::Exceptions::Internal(
             "User $user->name has not mail account"
           );
    }

    if ($quota < 0) {
        throw EBox::Exceptions::External(
            __('Quota can only be a positive number or zero for unlimited quota')
           )
    }

    $user->set('mailquota', $quota);
}

#  Method: regenMaildirQuotas
#
# regenerate user accounts mailquotas to reflect the changes in default
# quota configuration (only if default quota has changed)
sub regenMaildirQuotas
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');
    my $defaultQuota = $mail->defaultMailboxQuota();

    # Check mailbox size against last saved value
    my $prevDefaultQuota = $mail->get_int('prevMailboxSize');

    # Only regenerate if default quota has changed (or first time)
    return if (defined($prevDefaultQuota) and ($defaultQuota eq $prevDefaultQuota));

    EBox::info("Changing default quota to $defaultQuota MB");

    # Save new value
    $mail->set_int('prevMailboxSize', $defaultQuota);
    $mail->_saveConfig();

    my $usersMod = EBox::Global->modInstance('samba');

    foreach my $user (@{$usersMod->users()}) {
        my $account = $self->userAccount($user);
        $account or next;

        my ($username, $vdomain) =split '@', $account, 2;
        if (not $self->{vdomains}->vdomainExists($vdomain)) {
            next;
        }

        if ($self->maildirQuotaType($user) eq 'default') {
            $self->setMaildirQuota($user, $defaultQuota);
        }
    }
}

# Method: gidvmail
#
#  This method returns the gid value of ebox user
#
sub gidvmail
{
    my ($self) = @_;
    return scalar (getgrnam(EBox::Config::group));
}

# Method: uidvmail
#
#  This method returns the uid value of ebox user
#
sub uidvmail
{
    my ($self) = @_;

    return scalar (getpwnam(EBox::Config::user));
}

# Method: defaultUserModel
#
#   Overrides <EBox::UsersAndGrops::LdapUserBase::defaultUserModel>
#   to return our default user template
sub defaultUserModel
{
    return 'mail/MailUser';
}

# Method: multipleOUSupport
#
#   Returns 1 if this module supports users in multiple OU's,
#   0 otherwise
#
sub multipleOUSupport
{
    return 1;
}

# Method: hiddenOUs
#
#   Returns the list of OUs to hide on the UI
#
sub hiddenOUs
{
    return [ 'postfix' ];
}

1;
