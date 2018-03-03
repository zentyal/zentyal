# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Mail::FetchmailLdap;

use EBox::Config;
use EBox::Sudo;
use EBox::Ldap;
use EBox::MailUserLdap;
use EBox::Dashboard::ModuleStatus;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Validate;
use EBox::MailVDomainsLdap;
use EBox::Module::Base;
use EBox::Service;
use EBox::Util::Random;
use File::Slurp;
use Perl6::Junction qw(any);
use Crypt::Rijndael;
use EBox::Module::Base;
use MIME::Base64;

use constant {
 FETCHMAIL_DN        => 'ou=fetchmail,ou=postfix',
 FETCHMAIL_CONF_FILE => '/etc/zentyal-fetchmail.rc',
 FETCHMAIL_SERVICE   => 'zentyal.fetchmail',
 FETCHMAIL_CRON_FILE => '/etc/cron.d/ebox-mail',
};

sub new
{
    my ($class, $mailMod) = @_;
    my $self  = {};
    $self->{mailMod} = $mailMod;
    $self->{ldap}    = $mailMod->ldap();

    bless($self, $class);
    return $self;
}

sub initialSetup
{
    my ($self, $version) = @_;
    my $file = $self->_masterPasswdFile();
    my $user  = EBox::Config::user();
    my $group = EBox::Config::group();

    if (-r $file) {
        return;
    }

    if (-e $file) {
        throw EBox::Exceptions::Internal("File '$file' must be readable by user '$user'");
    }

    my $pass = EBox::Util::Random::generate(32);
    my $permissions = {
                          uid => $user,
                          gid => $group,
                          mode => '0600'
                       };
    EBox::Module::Base::writeFile($file, $pass, $permissions);

    return if ($version);

    my $samba = $self->{mailMod}->global()->modInstance('samba');
    if (not $samba->isProvisioned()) {
        # no accounts to migrate, since samba is not provisioned
        return;
    }

    my %attrs = (
            base => $self->{ldap}->dn(),
            filter => 'objectclass=fetchmailUser',
            scope => 'sub',
            attrs => ['fetchmailAccount']
           );

    my $result = $self->{ldap}->search(\%attrs);
    if ($result->count() == 0) {
        # no account migration needed
        return;
    }

    foreach my $entry ($result->entries()) {
        my @externalAccounts = $entry->get_value('fetchmailAccount');
        if (not @externalAccounts) {
            next;
        }
        @externalAccounts = map {
            my $account = $_;

            if (($account =~ m{^[^:]}) and (split(':', $account) >= 6)) {
                $account = $self->_encryptExternalAccountString($account);
                ($account)
            } else {
                my $dn = $entry->dn();
                EBox::error("External account string in $dn has not old format. Skipping.");
                ();
            }
        } @externalAccounts;

        $entry->replace('fetchmailAccount' => \@externalAccounts);
        $entry->update($self->{ldap}->connection());
    }
}

sub _externalAccountString
{
    my ($self, %params) = @_;

    my @values  = map {
        $params{$_}
    } qw(externalAccount mailProtocol mailServer port);
    push @values, $self->_optionsStr(%params);
    push @values, $params{password};
    my $str = join ':', @values;
    $str = $self->_encryptExternalAccountString($str);
    return $str;
}

sub _masterPasswdFile
{
    return EBox::Config::conf() . 'fetchmail.passwd';
}

sub _cipher
{
    my ($self) = @_;
    if ($self->{cipher}) {
        return $self->{cipher};
    }

    my $key;
    my $file = $self->_masterPasswdFile();
    if (not -r $file) {
        throw EBox::Exceptions::Internal("Fetchmail master password file '$file' does not exist or is not readable");
    }
    $key =  File::Slurp::read_file($file);

    $self->{cipher} = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC);
    return $self->{cipher};
}

sub _encryptExternalAccountString
{
    my ($self, $str) = @_;
    my $cipher = $self->_cipher();

    # encryption data must be multiple of 16
    my $strSize;
    {
        use bytes;
        $strSize = length($str);
    }
    my $mod16 = $strSize % 16;
    if ($mod16 != 0) {
        my $padSize = 16 - $mod16;
        $str .= ':' x $padSize;
    }

    $str = $cipher->encrypt($str);
    $str = encode_base64($str);
    return $str;
}

sub _decryptExternalAccountString
{
    my ($self, $str) = @_;
    my $cipher = $self->_cipher();
    $str = decode_base64($str);
    $str = $cipher->decrypt($str);
    return $str;
}

sub _optionsStr
{
    my ($self, %params) = @_;
    my @optionParts;
    if ($params{ssl}) {
        push @optionParts, 'ssl';
    }
    if ($params{keep}) {
        push @optionParts, 'keep';
    }
    if ($params{fetchall}) {
        push @optionParts, 'fetchall';
    }

    my $optionsStr = "@optionParts";
    return $optionsStr;
}

sub _externalAccountHash
{
    my ($self, $string) = @_;
    $string = $self->_decryptExternalAccountString($string);

    my @parts = split ':', $string, 7; # 7 fields becuase ':' is also the
                                       # padding character

    my %externalAccount;
    $externalAccount{user}         = $parts[0];
    $externalAccount{mailProtocol} = $parts[1];
    $externalAccount{server}       = $parts[2];
    $externalAccount{port}         = $parts[3];
    my $optionsStr                 = $parts[4];
    my @options                    = split '\s+', $optionsStr;
    $externalAccount{options}      = \@options;

    $externalAccount{password}     = $parts[5];

    return \%externalAccount;
}


sub _checkFetchmailAccountParams
{
    my ($self, %params) = @_;
    my @mandatoryParams = qw(user localAccount externalAccount password
            mailServer  mailProtocol port);
    foreach my $checkedParam (@mandatoryParams) {
        exists $params{$checkedParam} or
            throw EBox::Exceptions::MissingArgument($checkedParam);
    }

    EBox::Validate::checkEmailAddress($params{localAccount}, __('Local email account'));
    $self->checkExternalAccount($params{externalAccount});
    $self->checkPassword($params{password});
    $self->checkEmailProtocol($params{mailProtocol});
    EBox::Validate::checkHost($params{mailServer}, __('Mail server'));
    EBox::Validate::checkPort($params{port}, __('Mail server port'));
}

# Method: addExternalAccount
#
#
# Parameters:
#
sub addExternalAccount
{
    my ($self, %params) = @_;
    $self->_checkFetchmailAccountParams(%params);
    my $fetchmailString = $self->_externalAccountString(%params);
    my $user = $params{user};
    $user->add('fetchmailAccount', $fetchmailString);
}

sub existsAnyExternalAccount
{
    my ($self) = @_;

    my %attrs = (
            base => $self->{ldap}->dn(),
            filter => 'objectclass=fetchmailUser',
            scope => 'sub'
                );

    my $result = $self->{ldap}->search(\%attrs);
    foreach my $entry ($result->entries()) {
        my @accounts = $entry->get_value('fetchmailAccount');
        if (@accounts) {
            return 1;
        }
    }

    return 0;
}

sub allExternalAccountsByLocalAccount
{
    my ($self, %params) = @_;
    my $zarafa = $params{zarafa};
    my @zarafaDomains = $params{zarafaDomains};

    my %attrs = (
            base => $self->{ldap}->dn(),
            filter => 'objectclass=fetchmailUser',
            scope => 'sub'
                );

    my $result = $self->{ldap}->search(\%attrs);
    if ($result->count() == 0) {
        return {};
    }

    my %accountsByLocalAccount;
    foreach my $entry ($result->entries()) {
        my $localAccount = $entry->get_value('mail');
        if ($zarafa) {
            my ($left, $accountDomain) = split '@', $localAccount, 2;
            if ($accountDomain eq any @zarafaDomains) {
                if (not $entry->get_value('zarafaAccount')) {
                    EBox::info("Ignored fetchmail entry for account $localAccount since it is a disabled Zarafa account");
                    next;
                }
            }
        }

        my @externalAccounts = map {
            $self->_externalAccountHash($_)
        } $entry->get_value('fetchmailAccount');
        if (@externalAccounts == 0) {
            next;
        }

        $accountsByLocalAccount{$localAccount} = {
                               localAccount => $localAccount,
                               externalAccounts => \@externalAccounts,
                               mda => undef,
                           };
    }

    return \%accountsByLocalAccount;
}

sub externalAccountsForUser
{
    my ($self, $user) = @_;

    my @externalAccounts;
    foreach my $fetchmailStr ($user->get('fetchmailAccount')) {
        push @externalAccounts, $self->_externalAccountHash($fetchmailStr);
    }

    return \@externalAccounts;
}

sub removeExternalAccount
{
    my ($self, $user, $account) = @_;
    my $username = $user->name();

    my %attrs = (
        base => $self->{ldap}->dn(),
        filter => '&(objectclass=fetchmailUser)(samAccountName=' . $username . ')',
        scope => 'sub'
    );

    my $result = $self->{ldap}->search(\%attrs);
    my ($entry) = $result->entries();
    if (not $result->count() > 0) {
        throw EBox::Exceptions::Internal("Cannot find user $username");
    }

    my @fetchmailAccounts = $entry->get_value('fetchmailAccount');
    foreach my $encoded (@fetchmailAccounts) {
        my $externalAccount = $self->_externalAccountHash($encoded);
        if ($externalAccount->{user} eq $account) {
            $entry->delete(fetchmailAccount => [$encoded]);
            $entry->update($self->{ldap}->connection());
            return;
        }
    }

    throw EBox::Exceptions::Internal(
          "Cannot find external account $account for user $username"
                                    );
}

sub modifyExternalAccount
{
    my ($self, $user, $account, $newAccountHash) = @_;
    my @newAccount = (user => $user, @{ $newAccountHash});
    $self->_checkFetchmailAccountParams(@newAccount);
    $self->removeExternalAccount($user, $account);
    $self->addExternalAccount(@newAccount);
}

sub writeConf
{
    my ($self, %params) = @_;
    my $zarafa       = $params{zarafa};
    my @zarafaDomains = $params{zarafaDomains};

    # remove old password file if it exists
    my $oldFile =  $self->_oldMasterPasswdFile();
    system "rm -f '$oldFile'";

    if (not $self->isEnabled()) {
        EBox::Sudo::root('rm -f ' . FETCHMAIL_CRON_FILE);
        return;
    }

    my $mail = $self->{mailMod};
    my $postmasterAddress =  $mail->postmasterAddress(1, 1);
    my $pollTimeInSeconds =  $mail->fetchmailPollTime() * 60;

    my $usersAccounts = [ values %{
                                    $self->allExternalAccountsByLocalAccount(zarafa => $zarafa,
                                                                             zarafaDomains => @zarafaDomains
                                                                            )
                                  }
                         ];
    my @params = (
        pollTime      => $pollTimeInSeconds,
        postmaster    => $postmasterAddress,
        usersAccounts => $usersAccounts,
       );

    EBox::Module::Base::writeConfFileNoCheck(FETCHMAIL_CONF_FILE,
                         "mail/fetchmail.rc.mas",
                         \@params,
                         {
                             uid  => 'fetchmail',
                             gid  => 'nogroup',
                             mode =>  '0600',
                         }
                        );

    EBox::Module::Base::writeConfFileNoCheck(FETCHMAIL_CRON_FILE,
                         'mail/fetchmail-update.cron.mas',
                         [
                          binPath => EBox::Config::share() . 'zentyal-mail/fetchmail-update',
                         ],
                         {
                             uid  => 'root',
                             gid  => 'root',
                             mode =>  '0644',
                         }
                        );

}

sub daemonMustRun
{
    my ($self) = @_;
    if (not $self->isEnabled()) {
        return 0;
    }

    # if there isnt external accounts configured dont bother to run fetchmail
    return $self->existsAnyExternalAccount();
}

sub isEnabled
{
    my ($self) = @_;

    my $retrievalServices = $self->{mailMod}->model('RetrievalServices');
    return $retrievalServices->row()->valueByName('fetchmail');

}

sub stop
{
    EBox::Service::manage(FETCHMAIL_SERVICE, 'stop');
}

sub start
{
    EBox::Service::manage(FETCHMAIL_SERVICE, 'start');
}

sub running
{
    EBox::Service::running(FETCHMAIL_SERVICE);
}

# Method: serviceWidget
#
#    Return the widget for fetchmail widget
#
# Returns:
#
#    <EBox::Dashboard::ModuleStatus> - the section for fetchmail service
#
sub serviceWidget
{
    my ($self) = @_;

    my $widget = new EBox::Dashboard::ModuleStatus(
        module        => 'mail',
        printableName => __('External retrieval service'),
        running       => ($self->running() ? 1 : 0),
        enabled       => ($self->isEnabled() ? 1: 0),
       );

    return $widget;

}

sub modifyTimestamp
{
    my ($self) = @_;

    my %params = (
        base => $self->{ldap}->dn(),
        filter => "objectclass=fetchmailUser",
        scope => 'sub',
        attrs => ['modifyTimestamp'],
    );

    my $result = $self->{ldap}->search(\%params);

    my $timeStamp = 0;
    foreach my $entry ($result->entries()) {
        my $entryTimeStamp = $entry->get_value('modifyTimestamp');
        $entryTimeStamp =~ s/[^\d]+$//;
        if ($entryTimeStamp > $timeStamp) {
            $timeStamp = $entryTimeStamp;
        }
    }

    return $timeStamp;
}

sub _fetchmailRegenTsFile
{
    return EBox::Config::tmp() . '/fetchmailRegenTs';
}

sub fetchmailRegenTs
{
    my ($self) = @_;
    my $tsFile = $self->_fetchmailRegenTsFile();
    if (not -r $tsFile) {
        return 0;
    }

    my $data = File::Slurp::read_file($tsFile);
    return $data;
}

sub setFetchmailRegenTs
{
    my ($self, $ts) = @_;
    my $tsFile = $self->_fetchmailRegenTsFile();
    return File::Slurp::write_file($tsFile, $ts);
}

sub checkExternalAccount
{
    my ($self, $externalAccount) = @_;

    if ($externalAccount =~ m/\@/) {
        EBox::Validate::checkEmailAddress(
                 $externalAccount,
                 __('External account')
                );
    } else {
         # no info found on valid usernames for fetchmail..
        if ($externalAccount =~ m/\s/) {
            throw EBox::Exceptions::InvalidData (
                'data' => __('External account username'),
                'value' => $externalAccount,
                'advice' => __('No spaces allowed')
               );
        }
        unless ($externalAccount =~ m/^[\w.\-_]+$/) {
            throw EBox::Exceptions::InvalidData (
                'data' => __('External account username'),
                'value' => $externalAccount);
        }
    }
}

sub checkPassword
{
    my ($self, $password) = @_;
        if ($password =~ m/'/) {
            throw EBox::Exceptions::External(
                __(q{Character "'" is forbidden for external})
            );
        }
}

sub checkEmailProtocol
{
    my ($self, $mailProtocol) = @_;
    if (($mailProtocol ne 'pop3') and ($mailProtocol ne 'imap')) {
        throw EBox::Exceptions::External(
         __x('Unknown mail protocol: {proto}', proto => $mailProtocol)
        );
    }
}

sub externalAccountRowValues
{
    my ($self, $account) = @_;

    # direct correspondence values
    my %values = (
        externalAccount => $account->{user},
        password => $account->{password},
        server => $account->{server},
        port => $account->{port},
    );

    my $mailProtocol = $account->{mailProtocol};
    my $ssl = 0;
    my $keep = 0;
    my $fetchall = 0;
    if (exists $account->{options}) {
        if (ref $account->{options}) {
            foreach my $opt (@{ $account->{options} }) {
                if ($opt eq 'ssl') {
                    $ssl = 1;
                } elsif ($opt eq 'keep') {
                    $keep = 1;
                } elsif ($opt eq 'fetchall') {
                    $fetchall = 1;
                }
            }
        } else {
            $ssl = $account->{options} eq 'ssl';
        }
    }

    $self->checkEmailProtocol($mailProtocol);
    my $rowProtocol;
    if ($mailProtocol eq 'pop3') {
        $rowProtocol = $ssl ? 'pop3s' : 'pop3';
    } elsif ($mailProtocol eq 'imap') {
        $rowProtocol = $ssl ? 'imaps' : 'imap';
    }

    $values{protocol} = $rowProtocol;
    $values{keep}     = $keep;
    $values{fetchall} = $fetchall;
    return \%values;
}


sub _oldMasterPasswdFile
{
    my ($self) = @_;
    return EBox::Config::conf() . 'old.fetchmail.passwd';
}

sub revokeConfig
{
    my ($self) = @_;
    # put again old password file if it exists
    my $oldFile =  $self->_oldMasterPasswdFile();
    if (-r $oldFile) {
        my $dst = $self->_masterPasswdFile();
        system "mv '$oldFile' '$dst'";
    }
}

sub dumpConfig
{
    my ($self, $dir) = @_;
    my $file = $self->_masterPasswdFile();
    if (-r $file) {
        system "cp '$file' '$dir/fetchmail.passwd'";
    }
}

sub restoreConfig
{
    my ($self, $dir) = @_;
    my $src = "$dir/fetchmail.passwd";
    my $dst = $self->_masterPasswdFile();
    if (not (-r $src)) {
        return;
    }
    if (-r $dst) {
        my $oldFile =  $self->_oldMasterPasswdFile();
        system "cp '$dst' '$oldFile'"
    }

    system "cp -b '$src' '$dst'";
}

1;
