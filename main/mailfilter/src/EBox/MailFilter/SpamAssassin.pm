# Copyright (C) 2007 Warp Networks S.L.
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
#
use strict;
use warnings;

package EBox::MailFilter::SpamAssassin;

use Perl6::Junction qw(any all);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Service;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::MailFilter::VDomainsLdap;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use TryCatch::Lite;

use constant {
  SA_LEARN_SERVICE    => 'ebox.learnspamd',
  SA_CONF_FILE       => '/etc/spamassassin/local.cf',
  SA_PASSWD_FILE     => '/var/lib/zentyal/conf/sa-mysql.passwd',
  CONF_USER          => 'amavis',
  BAYES_DB_USER      => 'amavis',
};

sub new
{
    my $class = shift @_;

    my $self = {};
    $self->{vdomains} = new EBox::MailFilter::VDomainsLdap();

    bless $self, $class;
   return $self;
}

sub usedFiles
{
    return (
            {
             file =>  SA_CONF_FILE,
             reason => __(' To configure spamassassin daemon'),
             module => 'mailfilter',
            },

           );
}

sub _vdomains
{
    my ($self) = @_;
    return $self->{vdomains};
}

sub _confAttr
{
    my ($self, $attr) = @_;

    if (not $self->{configuration}) {
        my $mailfilter = EBox::Global->modInstance('mailfilter');
        $self->{configuration}     = $mailfilter->model('AntispamConfiguration');
    }

    return $self->{configuration}->$attr();
}

sub _learnServiceEnabled
{
    return 0; # learn accounts disabled by now
    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
    my $saLearnService = $vdomainsLdap->learnAccountsExists;
    return $saLearnService;
}

sub _manageServices
{
    my ($self, $action) = @_;

    if (not $self->_learnServiceEnabled()) {
        $action = 'stop';
    }
    EBox::Service::manage(SA_LEARN_SERVICE, $action);
}

sub doDaemon
{
    my ($self, $mailfilterService) = @_;

    if ($mailfilterService and $self->isEnabled() and $self->isRunning()) {
        $self->_manageServices('restart');
    }
    elsif ($mailfilterService and $self->isEnabled()) {
        $self->_manageServices('start');
    }
    elsif ($self->isRunning()) {
        $self->_manageServices('stop');
    }
}

sub stopService
{
    my ($self) = @_;
    if ($self->isRunning) {
        $self->_manageServices('stop');
    }
}

#
# Method: isEnabled
#
#  Returns the state of the service.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub isEnabled
{
    my ($self) = @_;

    my $mailfilter = EBox::Global->modInstance('mailfilter');
    return  $mailfilter->isEnabled() and $mailfilter->antispamNeeded();
}

sub setVDomainService
{
    my ($self, $vdomain, $service) = @_;

    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
    $vdomainsLdap->checkVDomainExists($vdomain);
    $vdomainsLdap->setAntispam($vdomain, $service);
}

sub vdomainService
{
    my ($self, $vdomain) = @_;

    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
    $vdomainsLdap->checkVDomainExists($vdomain);
    $vdomainsLdap->antispam($vdomain);
}

sub isRunning
{
    my ($self)= @_;
    if (EBox::Service::running(SA_LEARN_SERVICE)) {
        return 1;
    }

    my $mailfilter = EBox::Global->modInstance('mailfilter');
    return $mailfilter->smtpFilter()->isRunning();
}

sub writeConf
{
    my ($self) = @_;

    my @confParams;
    push @confParams, (spamThreshold => $self->spamThreshold());
    push @confParams, (trustedNetworks => $self->trustedNetworks());
    push @confParams, (bayes => $self->bayes);
    push @confParams, (bayesPath => $self->bayesPath);
    push @confParams, (bayesAutolearn => $self->autolearn);
    push @confParams, (bayesAutolearnSpamThreshold => $self->autolearnSpamThreshold);
    push @confParams, (bayesAutolearnHamThreshold => $self->autolearnHamThreshold);
    push @confParams, (
                       whitelist => $self->whitelistForSpamassassin(),
                       blacklist => $self->blacklistForSpamassassin(),
                      );
    push @confParams, (spamSubject => $self->spamSubjectTag());

    my ($password) = @{EBox::Sudo::root('/bin/cat ' . SA_PASSWD_FILE)};
    push @confParams, (password => $password);

    EBox::Module::Base::writeConfFileNoCheck(SA_CONF_FILE, "mailfilter/local.cf.mas", \@confParams);

#    $self->_vdomains->updateControlAccounts();
}

#
# Method: bayes
#
#  Returns the state of the bayesian filter.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub bayes
{
    my ($self) = @_;
    return $self->_confAttr('bayes');
}

#
# Method: autolearn
#
#  Returns the state of the autolearn in bayesian subsystem.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub autolearn
{
    my ($self) = @_;
    return $self->_confAttr('autolearn');
}

#
# Method: autolearnHamThreshold
#
#  Return the score that a ham message shouldn't reach to enter to the
#  learning system.
#
# Returns:
#
#  reference to a hash with spam and ham fields.
#
sub autolearnHamThreshold
{
  my ($self) = @_;
  return $self->_confAttr('autolearnHamThreshold');
}

#
# Method: autolearnSpamThreshold
#
#  Return the score that a spam message should have to obtain to enter to the
#  learning system as spam.
#
# Returns:
#
#  reference to a hash with spam and ham fields.
#
sub autolearnSpamThreshold
{
  my ($self) = @_;
  return $self->_confAttr('autolearnSpamThreshold');
}

#
# Method: autoWhitelist
#
#  Returns the state of the autoWhitelist activation
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub autoWhitelist
{
    my ($self) = @_;
    return $self->_confAttr('autoWhitelist');
}

#
# Method: spamSubjectTag
#
#  Returns the string to add to the subject of a spam message (if this option is
#  active)
#
# Returns:
#
#  string - The string to add.
#
sub spamSubjectTag
{
    my ($self) = @_;
    my $subjectTag =  $self->_confAttr('spamSubjectTag');

    if ($subjectTag) {
        if (not $subjectTag =~ m/\s$/) {
            # add withespace to the end of the tag
            $subjectTag .= ' ';
        }
    }

    return $subjectTag;
}

sub spamThreshold
{
    my ($self) = @_;

    return $self->_confAttr('spamThreshold');
}

sub vdomainSpamThreshold
{
    my ($self, $domain) = @_;
    return $self->_vdomains->spamThreshold($domain);
}

sub setVDomainSpamThreshold
{
    my ($self, $domain, $value) = @_;

    if ($value ne '') {
        $self->_checkSpamThreshold($value);
    }

    $self->_vdomains->setSpamThreshold($domain, $value);
}

sub _checkSpamThreshold
{
    my ($self, $threshold) = @_;

    if (not ($threshold =~ m/^\d+\.?\d*$/  )) {
        throw EBox::Exceptions::InvalidData(data => __('Spam threshold'), value => $threshold, advice => __('It must be a number(decimal point allowed)') );
    }

    if ($threshold <= 0) {
        throw EBox::Exceptions::Internal("The spam threshold must be greter than zero (was $threshold)");
    }

    if ($self->autolearn()) {
        if ($threshold > $self->autolearnSpamThreshold) {
            throw EBox::Exceptions::External(
                                             __("The spam's threshold cannot be higher than its autolearn threshold")
                                            );
        } elsif ($threshold <= $self->autolearnHamThreshold) {
            throw EBox::Exceptions::External(
                                             __("The spam's threshold cannot be lower or equal than its ham's autolearn threshold")
                                            );
        }
    }
}

sub dbPath
{
    my ($self) = @_;
    return EBox::Config::home() . '/.spamassassin';
}

sub confUser
{
    my ($self) = @_;
    return CONF_USER;
}

sub bayesPath
{
    my ($self) = @_;
    return $self->dbPath . '/bayes';
}

# this assume that the input is reeadable by the ebox user
sub learn
{
  my ($self, %params) = @_;

  exists $params{isSpam} or throw EBox::Exceptions::MissingArgument($_);
  exists $params{input} or throw EBox::Exceptions::MissingArgument($_);
  exists $params{username} or throw EBox::Exceptions::MissingArgument('username');

  # check wether the current spamassassin conf has bayesian filter enabled
  my $mailfilterRO =  EBox::Global->getInstance(1)->modInstance('mailfilter');
  my $saRO   = $mailfilterRO->antispam();
  if (not $saRO->bayes()) {
    throw EBox::Exceptions::External(__('Cannot learn because bayesian filter is disabled in the' .
                                        ' current configuration. ' .
                                        'In order to be able to learn enable the bayesian filter and save changes')
                                    );
  }

  my $username =  $params{username};
  if ($username =~ m/@/) {
      # XXX and what about alias?
      my ($user, $vdomain) = split '@', $username;
      my $vdomains = $mailfilterRO->model('VDomainsFilter');
      if (not $vdomains->vdomainAllowedToLearnFromIMAPFolder($vdomain)) {
          throw EBox::Exceptions::External(
__x('Accounts from the domain {d} cannot train the bayesian filter',
          d => $vdomain)
                                          );
      }
  }

  my $typeArg  = $params{isSpam} ? '--spam' : '--ham';
  my $input = $params{input};

  my $cmd =  q{su } . BAYES_DB_USER . qq{ -c 'sa-learn --mbox --max-size=0 $typeArg  $input'};
  EBox::Sudo::root($cmd);
}

# Method: whitelist
#
#  return the address whitelist. All the mail from the addresses in the
#  whitelist is considered not spam and none header is added
#
#  Returns:
#      refrence to the white list
sub whitelist
{
  my ($self) = @_;
  my $acl = EBox::Global->modInstance('mailfilter')->model('AntispamACL');
  return $acl->whitelist();
}

# Method: whitelistForAmavisConf
#
#  Returns:
#  the whitelist in amavis friendly format
sub whitelistForAmavisConf
{
  my ($self) = @_;
  return $self->_aclForAmavisConf('whitelist');
}

# amavis.conf uses distinct format than ldap to store domain in his ACLs..
sub _aclForAmavisConf
{
  my ($self, $list) = @_;

  my @mangledList = map {
    if (m/^@/) {
      s/^@/\./;
    }

    $_;
  } @{ $self->$list() };

  return \@mangledList;
}

# Method: whitelistforSpamassassin
#
#  Returns:
#  the whitelist in local.cf friendly format
sub whitelistForSpamassassin
{
  my ($self) = @_;
  return $self->_aclForSpamassassin('whitelist');
}

# Method: blacklistforSpamassassin
#
#  Returns:
#  the blacklist in local.cf friendly format
sub blacklistForSpamassassin
{
  my ($self) = @_;
  return $self->_aclForSpamassassin('blacklist');
}

sub _aclForSpamassassin
{
  my ($self, $list) = @_;

  my @mangledList = map {
    if (m/^@/) { # domain
      $_ = '*' . $_;
    }

    $_;
  } @{ $self->$list() };

  return \@mangledList;
}

sub vdomainWhitelist
{
  my ($self, $vdomain) = @_;

  return [$self->_vdomains->whitelist($vdomain)];
}

sub setVDomainWhitelist
{
  my ($self, $vdomain, $senderList_r) = @_;

  return $self->_vdomains->setWhitelist($vdomain, $senderList_r);
}

# Method: blacklist
#
#  return the address blacklist. All the mail from the addresses in the
#  blacklist is considered spam
#
#  Returns:
#      refrence to the black list
sub blacklist
{
  my ($self) = @_;
  my $acl = EBox::Global->modInstance('mailfilter')->model('AntispamACL');
  return $acl->blacklist();
}

# Method: blacklistForAmavisConf
#
#  Returns:
#  the blacklist in amavis friendly format
sub blacklistForAmavisConf
{
  my ($self) = @_;
  return $self->_aclForAmavisConf('blacklist');
}

sub vdomainBlacklist
{
  my ($self, $vdomain) = @_;

  return [$self->_vdomains->blacklist($vdomain)];
}

sub setVDomainBlacklist
{
  my ($self, $vdomain, $senderList_r) = @_;

  return $self->_vdomains->setBlacklist($vdomain, $senderList_r);
}

sub trustedNetworks
{
  my ($self) = @_;

  my $network = EBox::Global->modInstance('network');
  my @internalIfaces = @{ $network->InternalIfaces()  };
  my @ifacesAddresses = map {  @{ $network->ifaceAddresses($_) } } @internalIfaces;

  my %seen;
  my @trustedNetworks;
  foreach my $ifAddr (@ifacesAddresses) {
      my $address = $ifAddr->{address};
      my $netmask = $ifAddr->{netmask};
      my $networkAddress = EBox::NetWrappers::ip_network($address, $netmask);

      my $cidrNetwork = EBox::NetWrappers::to_network_with_mask($networkAddress, $netmask);
      if (not exists $seen{$cidrNetwork}) {
          push @trustedNetworks, $cidrNetwork;
          $seen{$cidrNetwork} = 1;
      }
  }

  return \@trustedNetworks
}

sub setVDomainSpamAccount
{
    my ($self, $vdomain, $active) = @_;
    $self->_vdomains->setSpamAccount($vdomain, $active);
}

sub setVDomainHamAccount
{
    my ($self, $vdomain, $active) = @_;
    $self->_vdomains->setHamAccount($vdomain, $active);
}

sub aclChanged
{
    my ($self) = @_;

    my $mailfilter = EBox::Global->modInstance('mailfilter');
    if (not $mailfilter->isEnabled()) {
        return;
    }

    my @modInstances = @{ EBox::Global->modInstances() };
    my $notifyMethod = 'notifyAntispamACL';

    foreach my $mod (@modInstances) {
        if ($mod->can($notifyMethod)) {
            $mod->$notifyMethod();
        }
    }
}

1;
