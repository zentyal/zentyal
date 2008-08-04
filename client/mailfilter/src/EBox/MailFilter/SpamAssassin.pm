package EBox::MailFilter::SpamAssassin;

use strict;
use warnings;


use Perl6::Junction qw(any all);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Service;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::MailFilter::VDomainsLdap;

use constant {
  SA_SERVICE          => 'ebox.spamd',
  SA_LEARN_SERVICE    => 'ebox.learnspamd',

  SA_CONF_FILE       => '/etc/spamassassin/local.cf',

  CONF_USER          => 'amavis',
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

sub _mailfilterModule
{
    return EBox::Global->modInstance('mailfilter');
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


sub _manageServices
{
    my ($self, $action) = @_;
    EBox::Service::manage(SA_SERVICE, $action);

    my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
    my $saLearnService = $vdomainsLdap->learnAccountsExists;
    if (not $saLearnService) {
        $action = 'stop';
    }
    EBox::Service::manage(SA_LEARN_SERVICE, $action);
}

sub doDaemon
{
    my ($self, $mailfilterService) = @_;
    
    if ($mailfilterService and $self->service() and $self->isRunning()) {
        $self->_manageServices('restart');
    } 
    elsif ($mailfilterService and $self->service()) {
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
# Method: service
#
#  Returns the state of the service.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub service
{
    my ($self) = @_;
    return $self->_confAttr('enabled');
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
    return EBox::Service::running(SA_SERVICE);
}


sub writeConf
{
    my ($self) = @_;

    my @confParams;
    push @confParams, (trustedNetworks => $self->trustedNetworks());
    push @confParams, (bayes => $self->bayes);
    push @confParams, (bayesPath => $self->bayesPath);
    push @confParams, (bayesAutolearn => $self->autolearn);
    push @confParams, (bayesAutolearnSpamThreshold => $self->autolearnSpamThreshold);
    push @confParams, (bayesAutolearnHamThreshold => $self->autolearnHamThreshold);

    EBox::Module->writeConfFile(SA_CONF_FILE, "mailfilter/local.cf.mas", \@confParams);
    
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
    return $self->_confAttr('spamSubjectTag');
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

sub learn
{
  my ($self, %params) = @_;

  exists $params{isSpam} or throw EBox::Exceptions::MissingArgument($_);
  exists $params{input} or throw EBox::Exceptions::MissingArgument($_);

  # check wether the current spamassassin conf has bayesian filter enabled
  my $eboxRO = EBox::Global->getInstance(1);
  my $saRO   = $eboxRO->modInstance('mailfilter')->antispam();
  if (not $saRO->bayes()) {
    throw EBox::Exceptions::External(__('Cannot learn because bayesian filter is disabled in the' .
                                        ' current configuration. ' . 
                                        'In order to be able to learn enable the bayesian filter and save changes')
                                    );
  }


  my $typeArg = $params{isSpam} ? '--spam' : '--ham';

  my $formatArg = '';
  # currently only mbox supported
  if ($params{format} eq 'mbox') {
    $formatArg = '--mbox'; 
  }
  elsif  (exists $params{format}) {
    throw EBox::Exceptions::External(__x('Unsupported or incorrect input source fonrmat: {format}', format => $params{format}))    
  }


  my $dbpathArg = "--dbpath " . $self->dbPath();

  my $cmd;

  $cmd = "sa-learn $dbpathArg  $typeArg $formatArg " . $params{input};
  EBox::Sudo::root($cmd);

  my $user     = $self->confUser();
  $cmd = "chown -R $user.$user "  . $self->dbPath();
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


  my @trustedNetworks = map {
      my $address = $_->{address};
      my $netmask = $_->{netmask};
      my $networkAddress = EBox::NetWrappers::ip_network($address, $netmask);

      my $cidrNetwork = EBox::NetWrappers::to_network_with_mask($networkAddress, $netmask);
      
    } @ifacesAddresses;


  push @trustedNetworks, '127.0.0.1';
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




1;
