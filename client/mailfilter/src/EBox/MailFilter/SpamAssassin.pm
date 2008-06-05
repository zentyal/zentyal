package EBox::MailFilter::SpamAssassin;

use strict;
use warnings;

use base qw(EBox::GConfModule::Partition);
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

  my $self = $class->SUPER::new(@_);
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
  return EBox::GConfModule::Partition::fullModule(@_);
}



sub _manageServices
{
    my ($self, $action) = @_;
    EBox::Service::manage(SA_SERVICE, $action);


    my $saLearnService = $self->spamAccountActive() or $self->hamAccountActive();
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
  return $self->getConfBool('active');
}

#
# Method: setService
#
#  Enable/Disable the service.
#
# Parameters:
#
#  active - true or false
#
sub setService 
{
  my ($self, $active) = @_;
  ($active and $self->service()) and return;
  (!$active and !$self->service()) and return;
  $self->setConfBool('active', $active);
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

  $self->_vdomains->updateControlAccounts();
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
	my $self = shift;
	return $self->getConfBool('bayes');
}

#
# Method: setBayes
#
#  Enable/Disable the bayesian filter.
#
# Parameters:
#
#  active - true or false
#
sub setBayes
{
	my ($self, $active) = @_;
	($active and $self->bayes()) and return;
	(!$active and !$self->bayes()) and return;
	$self->setConfBool('bayes', $active);
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
       my $self = shift;
       return $self->getConfBool('autolearn');
}

#
# Method: setAutolearn
#
#  Enable/Disable autolearn in bayesian subsystem.
#
# Parameters:
#
#  active - true or false
#
sub setAutolearn
{
       my ($self, $active) = @_;
       ($active and $self->autolearn()) and return;
       (!$active and !$self->autolearn()) and return;

       # this is to force to check the threshold's levels bz when the autolearn
       # is disabled the spam's level aren't checked against them
       $self->setAutolearnHamThreshold($self->autolearnHamThreshold);
       $self->setAutolearnSpamThreshold($self->autolearnSpamThreshold);

       $self->setConfBool('autolearn', $active);
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
  return $self->getConfString('autolearn_ham_threshold');
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
  return $self->getConfString('autolearn_spam_threshold');
}


#
# Method: setAutolearnHamThreshold
#
#  Set the  score that a ham  message shouldn't reach to enter to the
#  learning system.
#
# Parameters:
#
#  ham - new threshold for ham
sub setAutolearnHamThreshold
{
  my ($self, $threshold) = @_;
  $self->_checkAutolearnThresholds(
				ham   => $threshold,
				spam  => $self->autolearnSpamThreshold(),
			       );

   if ($threshold ne $self->autolearnHamThreshold) {
     $self->setConfString('autolearn_ham_threshold', $threshold);
   }

}


#
# Method: setAutolearnSpamThreshold
#
#  Set the  score that a spam  message should have to obtain to enter to the
#  learning system.
#
# Parameters:
#
#  spam - new threshold for spam
sub setAutolearnSpamThreshold
{
  my ($self, $threshold) = @_;

  if ($threshold < 6) {
    throw EBox::Exceptions::External(
	 __("The spam's autolearn threshold must be higher than 6.0")
				    );
   }

  $self->_checkAutolearnThresholds(
				spam => $threshold,
				ham  => $self->autolearnHamThreshold(),
			       );


  if ($threshold ne $self->autolearnSpamThreshold) {
    $self->setConfString('autolearn_spam_threshold', $threshold);
  }
}

sub _checkAutolearnThresholds
{
  my ($self, %params) = @_;
  (exists $params{spam})  or
    throw EBox::Exceptions::MissingArgument('You must supply at least a  spam parameter');
  (exists $params{ham})  or
    throw EBox::Exceptions::MissingArgument('You must supply at least a  ham parameter');

   my $hamT  = $params{ham};
   my $spamT = $params{spam};

   # check thresholds
   if ($hamT > $spamT) {
     throw EBox::Exceptions::External(
	 __("The ham's autolearn threshold cannot be higher than spam's threshold")
				     );
   }

   # check autolearn's thresholds against spam thresholds
   my @spamStateThresholds;
   @spamStateThresholds = map {
     my $th = $self->vdomainSpamThreshold($_);
     defined $th ? $th : ();
   } $self->_vdomains->vdomains(); # get threshold from vdomaind
   push @spamStateThresholds, $self->spamThreshold;
   
   
   foreach my $spamStateThreshold (@spamStateThresholds) {
     if ($spamT < $spamStateThreshold) {
       throw EBox::Exceptions::External(
					__("The spam's autolearn threshold cannot be lower than the default spam's treshold ")
				       );
     } elsif ($hamT >= $spamStateThreshold) {
       throw EBox::Exceptions::External(
	 __("The ham's autolearn threshold canot be higher or equal than the default spam level")
				       );
     }

   }
 
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
       my $self = shift;
       return $self->getConfBool('autowhitelist');
}

#
# Method: setAutoWhitelist
#
#  Enable/Disable the auto-whiteleist feature
#
# Parameters:
#
#  active - true or false
#
sub setAutoWhitelist
{
       my ($self, $active) = @_;
       ($active and $self->autoWhitelist()) and return;
       (!$active and !$self->autoWhitelist()) and return;
       $self->setConfBool('autowhitelist', $active);
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
	my $self = shift;
	return $self->getConfString('spam_subject_tag');
}

#
# Method: setSpamSubjectTag
#
#  Sets the string to add to the subject of a spam message.
#
# Parameters:
#
#  subject - A string to add.
#
sub setSpamSubjectTag
{
	my ($self, $subject) = @_;
	($subject eq $self->spamSubjectTag()) and return;
	$self->setConfString('spam_subject_tag', $subject);
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
    }
    elsif ($threshold <= $self->autolearnHamThreshold) {
      throw EBox::Exceptions::External(
	__("The spam's threshold cannot be lower or equal than its ham's autolearn threshold")
				      );
    }
  }
}

sub spamThreshold
{
  my ($self) = @_;

  return $self->getConfString('spam_threshold');
}


sub setSpamThreshold
{
  my ($self, $newLevel) = @_;

  $self->_checkSpamThreshold($newLevel);

  ($newLevel == $self->spamThreshold) and return;

  $self->setConfString('spam_threshold', $newLevel);
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



# valid sender values :
#  address@domain
#  @domain
sub _checkSender
{
  my ($self, $sender) = @_;

  if ($sender =~ m/^@/) {
    # domain case
    my ($unused, $domainName,) = split '@', $sender, 2;
    EBox::Validate::checkDomainName($domainName, __('domain name'));
  }
  elsif ($sender =~ m/@/) {
    # sender addres
    EBox::Validate::checkEmailAddress($sender, __('email address'));
  }
  else {
    throw EBox::Exceptions::External(
	 __(q{The sender can be either an email address or a domain name prefixed with '@'})
				    );
  }


}


sub whitelist
{
  my ($self) = @_;
  $self->getConfList('whitelist');
}

sub whitelistForAmavisConf
{
  my ($self) = @_;
  return $self->_aclForAmavisConf('whitelist');
}



# amavis.conf uses distinct format than ldap to store domain in his acls..
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


sub setWhitelist
{
  my ($self, $whitelist_r) = @_;
  foreach my $entry (@{ $whitelist_r }) {
    $self->_checkSender($entry)
  }

  $self->setConfList('whitelist', 'string', $whitelist_r);
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

sub blacklist
{
  my ($self) = @_;
  $self->getConfList('blacklist');
}


sub blacklistForAmavisConf
{
  my ($self) = @_;
  return $self->_aclForAmavisConf('blacklist');
}

sub setBlacklist
{
  my ($self, $blacklist_r) = @_;
  foreach my $entry (@{ $blacklist_r }) {
    $self->_checkSender($entry)
  }

  $self->setConfList('blacklist', 'string', $blacklist_r);
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




sub setSpamAccountActive
{
    my ($self, $active) = @_;
    my $oldActive = $self->spamAccountActive;
    ($active and $oldActive) and return;
    ((not $active) and (not $oldActive)) and return;

    $self->setConfBool('spam_account_active', $active);
}

sub spamAccountActive
{
    my ($self) = @_;
    return $self->getConfBool('spam_account_active');
}

sub setHamAccountActive
{
    my ($self, $active) = @_;
    my $oldActive = $self->hamAccountActive;
    ($active and $oldActive) and return;
    ((not $active) and (not $oldActive)) and return;

    $self->setConfBool('ham_account_active', $active);
}

sub hamAccountActive
{
    my ($self) = @_;
    return $self->getConfBool('ham_account_active');
}


1;
