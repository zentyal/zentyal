# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Mail::FetchmailLdap;

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
use EBox::Module::Base;
use EBox::Service;
use File::Slurp;

use constant {
 FETCHMAIL_DN        => 'ou=fetchmail,ou=postfix',
 FETCHMAIL_CONF_FILE => '/etc/ebox-fetchmail.rc',
 FETCHMAIL_SERVICE   => 'ebox.fetchmail',
 FETCHMAIL_CRON_FILE => '/etc/cron.d/ebox-mail',
};


sub new
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Global->modInstance('users')->ldap();
    bless($self, $class);
    return $self;
}


sub _externalAccountString
{
    my ($self, %params) = @_;

    my @values  = map {
        $params{$_}
    } qw(externalAccount password mailProtocol mailServer port ssl);
    my $str = join ':', @values;
    return $str;
}

sub _externalAccountHash
{
    my ($self, $string) = @_;
    my @parts = split ':', $string;

    my %externalAccount;
    $externalAccount{user}         = $parts[0];
    $externalAccount{password}     = $parts[1];
    $externalAccount{mailProtocol} = $parts[2];
    $externalAccount{server}       = $parts[3];
    $externalAccount{port}         = $parts[4];
    if ($parts[5]) {
        # ssl option
        $externalAccount{options}        =  'ssl';
    }


    return \%externalAccount;
}

# Method: addExternallAccount
#
#
# Parameters:
#

sub addExternalAccount
 {
     my ($self, %params) = @_;
     my @mandatoryParams = qw(user localAccount password 
                              mailServer  mailProtocol port);
     foreach my $checkedParam (@mandatoryParams) {
         exists $params{$checkedParam} or
             throw EBox::Exceptions::MissingArgument($checkedParam);
     }

     my $user = $params{user};
     my $userDn = EBox::Global->modInstance('users')->userDn($user);

     my $fetchmailString = $self->_externalAccountString(%params);

     my %modifyParams = (
          add=> [ fetchmailAccount => $fetchmailString ]          
         );
 
     my $res = $self->{'ldap'}->modify($userDn, \%modifyParams);
}




sub existsAnyExternalAccount
{
    my ($self) = @_;

    my %attrs = (
            base => EBox::Global->modInstance('users')->usersDn,
            filter => 'objectclass=fetchmailUser',
            scope => 'sub'
                );

    my $result = $self->{'ldap'}->search(\%attrs);
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
    my ($self) = @_;

    my %attrs = (
            base => EBox::Global->modInstance('users')->usersDn,
            filter => 'objectclass=fetchmailUser',
            scope => 'sub'
                );

    my $result = $self->{'ldap'}->search(\%attrs);
    if ($result->count() == 0) {
        return {};
    }

    my %accountsByLocalAccount;
    foreach my $entry ($result->entries()) {
        my $localAccount = $entry->get_value('mail');
        my $externalAccounts = $self->_externalAccountsForLdapEntry($entry);
        if (@{ $externalAccounts} == 0) {
            next;
        }

        $accountsByLocalAccount{$localAccount} = {
                               localAccount => $localAccount,
                               externalAccounts => $externalAccounts,
                                     };
    }


    return \%accountsByLocalAccount;
}

sub externalAccountsForUser
{
    my ($self, $user) = @_;

    my %args = (
            base => EBox::Global->modInstance('users')->usersDn,
            filter => "&(objectclass=fetchmailUser)(uid=$user)",
            scope => 'sub'
                );

    my $result = $self->{ldap}->search(\%args);
    my ($entry) = $result->entries();

    if (not $entry) {
        return [];
    } 

    return $self->_externalAccountsForLdapEntry($entry);
}



sub _externalAccountsForLdapEntry
{
   my ($self, $entry) = @_;

    my @externalAccounts;
    foreach my $fetchmailStr ($entry->get_value('fetchmailAccount')) {
        push @externalAccounts, $self->_externalAccountHash($fetchmailStr);
    }
    
    return \@externalAccounts;
}

sub removeExternalAccount
{
    my ($self, $user, $account) = @_;

    my %attrs = (
        base => EBox::Global->modInstance('users')->usersDn,
        filter => "&(objectclass=fetchmailUser)(uid=$user)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);
    my ($entry) = $result->entries();
    if (not $result->count() > 0) {
        throw EBox::Exceptions::Internal( "Cannot find user $user" );
    }



    my @fetchmailAccounts = $entry->get_value('fetchmailAccount');
    foreach my $fetchmailAccount (@fetchmailAccounts) {
        if ($fetchmailAccount =~ m/^$account:/) {
            $entry->delete(fetchmailAccount => [$fetchmailAccount]);
            $entry->update($self->{'ldap'}->ldapCon());
            return;
        }
    }

    throw EBox::Exceptions::Internal(
          "Cannot find external account $account for user $user"
                                    );
}


sub modifyExternalAccount
{
    my ($self, $user, $account, $newAccountHash) = @_;

    my %attrs = (
        base => EBox::Global->modInstance('users')->usersDn,
        filter => "&(objectclass=fetchmailUser)(uid=$user)",
        scope => 'one'
    );

    my $result = $self->{'ldap'}->search(\%attrs);
    my ($entry) = $result->entries();
    if (not $result->count() > 0) {
        throw EBox::Exceptions::Internal( "Cannot find user $user" );
    }



    my @fetchmailAccounts = $entry->get_value('fetchmailAccount');
    foreach my $fetchmailAccount (@fetchmailAccounts) {
        if ($fetchmailAccount =~ m/^$account:/) {
            my $newAccountString = 
                 $self->_externalAccountString($newAccountHash);
            $entry->delete(fetchmailAccount => [$fetchmailAccount]);
            $entry->add(fetchmailAccount => $newAccountString);
            $entry->update($self->{'ldap'}->ldapCon());
            return;
        }
    }

    throw EBox::Exceptions::Internal(
          "Cannot find external account $account for user $user"
                                    );
}


sub writeConf
{
    my ($self) = @_;

    if (not $self->isEnabled()) {
        EBox::Sudo::root('rm -f ' . FETCHMAIL_CRON_FILE);
        return;
    }

    EBox::Module::Base::writeConfFileNoCheck(FETCHMAIL_CRON_FILE,
                         'mail/fetchmail-update.cron.mas',
                         [
                          binPath => EBox::Config::share() . 'ebox-mail/fetchmail-update',
                         ],                    
                         {
                             uid  => 'root',
                             gid  => 'root',
                             mode =>  '0644',
                         }
                        );

    my $usersAccounts = [ values %{ $self->allExternalAccountsByLocalAccount }];
    my @params = (
        usersAccounts => $usersAccounts,
       );

    
    EBox::Module::Base::writeConfFileNoCheck(FETCHMAIL_CONF_FILE, 
                         "mail/fetchmail.rc.mas",
                         \@params,
                         {
                             uid  => 'fetchmail',
                             gid  => 'nogroup',
                             mode =>  '0710',
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

    my $retrievalServices = EBox::Global->modInstance('mail')->model('RetrievalServices');
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


sub modifyTimestamp
{
    my ($self) = @_;

    my %params = (
        base => EBox::Global->modInstance('users')->usersDn,
        filter => "objectclass=fetchmailUser",
        scope => 'one',
        attrs => ['modifyTimestamp'],
    );

    my $result = $self->{'ldap'}->search(\%params);
    
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



1;
