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

package EBox::MailFilter;

use strict;
use warnings;

use base (
	  'EBox::GConfModule', 
	  'EBox::VDomainModule',
	  'EBox::LdapModule',
	  'EBox::Mail::FilterProvider', 
	  'EBox::FirewallObserver'
	 );

use Perl6::Junction qw(all any);

use EBox::Gettext;
use EBox::Sudo qw( :all );
use EBox::Service;
use EBox::Summary::Module;
use EBox::Summary::Status;
use EBox::Exceptions::InvalidData;
use EBox::MailFilter::ClamAV;
use EBox::MailFilter::SpamAssassin;
use EBox::MailFilter::FileFilter;
use EBox::MailFilter::FirewallHelper;
use EBox::MailVDomainsLdap;
use EBox::Validate;
use EBox::Config;

use constant {
  AMAVIS_DAEMON                 => 'amavisd-new',
  AMAVIS_CONF_FILE              => '/etc/amavis/conf.d/amavisd.conf',
  AMAVISPIDFILE			=> '/var/run/amavis/amavisd.pid',
  AMAVIS_INIT			=> '/etc/init.d/amavis',

  SA_INIT			=> '/etc/init.d/spamassassin',
  SAPIDFILE			=> '/var/run/spamd.pid',

  MAILFILTER_NAME => 'mailfilter', # name used to identify the filter
                                   # which this modules provides
};


#
# Method: _create
#
#  Constructor of the class
#
sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'mailfilter');
	bless($self, $class);

	$self->{antivirus} = new EBox::MailFilter::ClamAV('clamav', $self);
	$self->{antispam}  = new EBox::MailFilter::SpamAssassin('spamassassin', $self);
       $self->{fileFilter} = new EBox::MailFilter::FileFilter('file_filter', $self);

	return $self;
}

#
# Method: antivirus
#
# Returns:
#   - the antivirus object. This a instance of EBox::MailFilter::ClamAV
sub antivirus
{
  my ($self) = @_;
  return $self->{antivirus};
}

#
# Method: antispam
#
# Returns:
#   - the antispam object. This a instance of EBox::MailFilter::SpamAssassin
sub antispam
{
  my ($self) = @_;
  return $self->{antispam};
}


#
# Method: fileFilter
#
# Returns:
#   - the file filter object. This a instance of EBox::MailFilter::FileFilter
sub fileFilter
{
  my ($self) = @_;
  return $self->{fileFilter};
}

#
# Method: _regenConfig
#
sub _regenConfig
{
  my ($self) = @_;
  my $service = $self->service();

  $self->antivirus()->writeConf($service);
  $self->antispam()->writeConf();
  $self->_writeAmavisConf();

  $self->antivirus()->doDaemon($service);
  $self->antispam()->doDaemon($service);
  $self->_doDaemon();
}





sub _writeAmavisConf
{
  my ($self) = @_;

  my @masonParams;

  push @masonParams, ( myhostname => $self->_fqdn());
  push @masonParams, ( mydomain => $self->_domain());
  push @masonParams, ( localDomains => $self->_localDomains());

  push @masonParams, (port => $self->port);

  push @masonParams, (allowedExternalMTAs => $self->allowedExternalMTAs);

  push @masonParams, ( ldapBase         =>  EBox::Ldap->dn );
  push @masonParams, ( ldapQueryFilter  =>  '(&(objectClass=amavisAccount)(|(mail=%m)(domainMailPortion=%m)))');
  push @masonParams, ( ldapBindDn       =>  EBox::Ldap->rootDn );
  push @masonParams, ( ldapBindPasswd   =>  EBox::Ldap->rootPw );

  push @masonParams, ( antivirusActive  => $self->antivirus->service());
  push @masonParams, ( virusPolicy      => $self->filterPolicy('virus'));
  push @masonParams, ( clamdSocket     => $self->antivirus()->localSocket());

  push @masonParams, ( antispamActive     => $self->antispam->service());
  push @masonParams, ( spamThreshold => $self->antispam()->spamThreshold());
  push @masonParams, ( spamDetectedSubject => $self->antispam()->spamSubjectTag());
  push @masonParams, ( spamPolicy         => $self->filterPolicy('spam'));
  push @masonParams, 
    ( antispamWhitelist  => $self->antispam->whitelistForAmavisConf());
  push @masonParams, 
    ( antispamBlacklist  => $self->antispam->blacklistForAmavisConf());

  push @masonParams, ( bannedPolicy      => $self->filterPolicy('banned'));
  push @masonParams, ( bannedFileTypes   => $self->fileFilter->bannedFilesRegexes);

  push @masonParams, ( bheadPolicy      => $self->filterPolicy('bhead'));

  push @masonParams, (adminAddress => $self->adminAddress);

  push @masonParams, (debug => EBox::Config::configkey('debug') eq 'yes');


  $self->writeConfFile(AMAVIS_CONF_FILE, '/mailfilter/amavisd.conf.mas', \@masonParams);
}





sub _domain
{
  my $domain = `hostname --domain`;

  if ($? != 0) {
    throw EBox::Exceptions::Internal('eBox was unable to get the omain for his host/' .
	'Please, check than your resolver and /etc/hosts file are propely configured.'
				    )
  }

  chomp $domain;
  return $domain;
}

sub _fqdn
{
  my $fqdn = `hostname --fqdn`;

  if ($? != 0) {
    throw EBox::Exceptions::Internal('eBox was unable to get the full qualified domain name (FQDN) for his host/' .
	'Please, check than your resolver and /etc/hosts file are propely configured.'
				    )
  }

  chomp $fqdn;
  return $fqdn;
}


sub _localDomains
{
  my ($self) = @_;

  my @vdomains =   EBox::MailVDomainsLdap->new->vdomains();
  push @vdomains, @{ $self->externalDomains() };

  return [@vdomains];
}

#
# Method: isRunning
#
#  Returns if the module is running.
#
# Returns:
#
#  boolean - true if it's running, otherwise false
#
sub isRunning
{
  my ($self) = @_;
  
  return 1 if $self->_amavisdIsRunning();
  return 1 if  $self->antivirus->isRunning;
  
  return 0;
}


sub _amavisdIsRunning
{
  my ($self) = @_;
  return EBox::Service::running(AMAVIS_DAEMON);
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
  return $self->get_bool('active');
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

	if (not $active) {
	  $self->_assureFilterNotInUse();
	}


	$self->set_bool('active', $active);
}



sub _assureFilterNotInUse
{
  my ($self) = @_;

  my $mail = EBox::Global->modInstance('mail');

  $mail->service('filter') or
    return;

  my $filterInUse = $mail->externalFilter();
  if ($filterInUse eq MAILFILTER_NAME) {
    throw EBox::Exceptions::External(
	  __('Cannot proceed because the filter is in use'),
				    );
  }

}

#
# Method: _doDaemon
#
#  Sends restart/start/stop command to the daemons depending of their actual
#  state and the state stored in gconf
#
sub _doDaemon
  {
    my $self = shift;

    if ($self->service() and $self->isRunning()) {
      EBox::Service::manage(AMAVIS_DAEMON, 'restart');
    } 
    elsif ($self->service()) {
      EBox::Service::manage(AMAVIS_DAEMON, 'start');
    } 
    elsif ($self->isRunning()) {
      EBox::Service::manage(AMAVIS_DAEMON, 'stop');
    }
  }


#
# Method: _stopService
#
#  Stop the service daemons
#
sub _stopService
{
	my $self = shift;
	if ($self->isRunning('active')) {
	  $self->antispam()->stopService();
	  $self->antivirus()->stopService();

	  EBox::Service::manage(AMAVIS_DAEMON, 'stop');
	}
}





#
# Method: port
#
# Returns:
#  return the port used by the mail filter for input
#
sub port
{
  my ($self) = @_;
  return $self->get_int('port');
}

#
# Method: setPort
#
#  set the filter's port
#
# Parameters
#  port - the new filter's port
#
sub setPort
{
  my ($self, $port) = @_;
  $port ne $self->port or return;

  EBox::Validate::checkPort($port, __(q{Mailfilter's port}));

  my $global  = EBox::Global->getInstance();
  my @mods = grep {  $_->can('usesPort') } @{ $global->modInstances  };
  foreach my $mod (@mods) {
    if ($mod->usesPort('tcp', $port)) {
      throw EBox::Exceptions::External(
				       __x('The port {port} is already used by module {mod}',
					   port => $port,
					   mod  => $mod->name,
					  )
				      );
    }
  }


  $self->set_int('port', $port);
}


#
# Method: fwport
#
# Returns:
#  return the port used by the mail filter for forwarding messages to the mta
#
sub fwport
{
  my ($self) = @_;

  # if $relayhost_is_client is true,
  #  The static port number is also overridden, and is dynamically 
  # calculated  as being one above the incoming SMTP/LMTP session port number.
  my $fwport = $self->port() + 1;
  return $fwport;
}


# Method : allowedExternalMTAs
#
#  get the list of external MTA's addresses which are allowed to connect to the
#  filter.
#
#  Returns:
#   the MTAs list as a list reference
sub allowedExternalMTAs
{
  my ($self) = @_;
  return $self->get_list('allowed_external_mtas');
}

# Method : setAllowedExternalMTAs
#
#  set the list of external MTA's addresses which are allowed to connect to the
#  filter.
#
#  Parameters:
#   mtasList - a reference to the list of addresses of allowed external MTAs
sub setAllowedExternalMTAs
{
  my ($self, $mtasList) = @_;

  foreach my $mta (@{ $mtasList }) {
    EBox::Validate::checkHost($mta, __("MTA's address"));

    # check that mta sin't internal
    my $internal;
    if ( $mta =~ m/^[\d.]+$/ ) {
      $internal =  EBox::Validate::isIPInNetwork('127.0.0.0', '255.0.0.0', $mta);
    } else {
      $internal = $mta eq 'localhost';
    }

    if ($internal) {
      throw EBox::Exceptions::External(
				       __x('Invalid externa; MTA {mta}. Local net addresses are not allowed', mta => $mta)
				      );
    }
  }

  $self->set_list('allowed_external_mtas', 'string', $mtasList);
  # set firewall as changed bz this may change firewall rules
  my $firewall = EBox::Global->modInstance('firewall');
  $firewall->setAsChanged();
}



# Method : addAllowedExternalMTA
#
#  add a MTA  to the list of the MTA's which are allowed to connect to
#  the 
#  filter.
#
#  Parameters:
#   mta - the IP address or the hostname of the MTA to be added
sub addAllowedExternalMTA
{
  my ($self, $mta) = @_;

  my @mtas = @{ $self->get_list('allowed_external_mtas') };
  if ($mta eq any @mtas) {
    throw EBox::Exceptions::External(
       __x('{mta} is already allowed', mta => $mta )
				    );
  }

  unshift @mtas, $mta;
  $self->setAllowedExternalMTAs(\@mtas);
		
}

# Method : removeAllowedExternalMTA
#
#  remove a MTA's  from the list of the MTA's which are allowed to connect to
#  the 
#  filter.
#
#  Parameters:
#   mta - the IP address or the hostname of the MTA to be removed
sub removeAllowedExternalMTA
{
  my ($self, $mta) = @_;

  my @mtas = @{ $self->get_list('allowed_external_mtas') };
  my @mtasWithoutRemoved = grep { $_ ne $mta } @mtas;
  if (@mtas == @mtasWithoutRemoved) {
    throw EBox::Exceptions::External(
	     __x('{mta} not found', mta => $mta)
				    );
  }

  $self->setAllowedExternalMTAs(\@mtasWithoutRemoved);
}


sub externalDomains
{
  my ($self) = @_;
  return $self->get_list('external_domains');
}


sub addExternalDomain
{
  my ($self, $domain) = @_;

  EBox::Validate::checkDomainName($domain , __('Mail domain'));

  my @domains = @{  $self->externalDomains };
  if ($domain eq any @domains) {
    throw EBox::Exceptions::External (
	    __x('{domain} is already acknowledged as external mail domain',
		domain => $domain,
	       )
				     );
  }

  push @domains, $domain;

  $self->set_list('external_domains', 'string', \@domains);
}

sub removeExternalDomain
{
  my ($self, $domain) = @_;

  EBox::Validate::checkDomain($domain , __('Mail domain'));

  my @domains = @{  $self->externalDomains };
  my @domainsWithoutRemoved = grep {  $_ ne $domain } @domains;

  if (@domains == @domainsWithoutRemoved) {
    throw EBox::Exceptions::External(
	     __x('Domain {domain} was not acknowledged as external mail domain',
		 domain => $domain,
		)
				    );
  }

  $self->set_list('external_domains', 'string', \@domainsWithoutRemoved);
}



sub adminAddress
{
  my ($self) = @_;
  return $self->get_string('admin_address');
}


sub setAdminAddress
{
  my ($self, $address) = @_;

  if (defined $address) {
    EBox::Validate::checkEmailAddress($address, __('Administrator address'));
    $self->set_string('admin_address', $address);
  }
  else {  # removal 
    $self->unset('admin_address');
  }

}


#
# Method: filterPolicy
#
#  Returns the policy of a filter type passed as parameter. The filter type
#  could be:
#  	- virus: Virus filter.
#  	- spam: Spam filter.
#  	- bhead: Bad headers checks.
#  	- banned: Banned names and types checks.
#  And the policy:
#  	- D_PASS
#	- D_REJECT
#  	- D_BOUNCE
#       - D_DISCARD
#
# Parameters:
# 
#  ftype - A string with filter type.
#   
# Returns:
#
#  string - The string with the policy established to the filter type.
#
sub filterPolicy
  {
    my ($self, $ftype) = @_;
    my $ftypeKey = $self->_ftypePolicyKey($ftype);

    my $policy =  $self->get_string($ftypeKey);
    $policy or throw EBox::Exceptions::Internal("No filter policy set for $ftype");

    return $policy;
  }

#
# Method: setFilterPolicy
#
#  Sets the policy to a filter type. (see filterPolicy method to filter types
#  and policies details.)
#
# Parameters:
#
#  ftype - A string with the filter type.
#  policy - A string with the policy.
#
sub setFilterPolicy
  {
    my ($self, $ftype, $policy) = @_;

    my @policies = ('D_PASS', 'D_REJECT', 'D_BOUNCE', 'D_DISCARD');
    if (not ($policy eq any @policies)) {
      throw EBox::Exceptions::InvalidData(
					  'data'  => __('policy type'),
					  'value' => $policy
					 );
    }

    ($policy eq $self->filterPolicy($ftype)) and return;

    my $ftypeKey = $self->_ftypePolicyKey($ftype);
    $self->set_string($ftypeKey, $policy);
}

sub _ftypePolicyKey
{
  my ($self, $ftype) = @_;

  my @ftypes = ('virus', 'spam', 'bhead', 'banned');
  
  if (not ($ftype eq any @ftypes)) {
    throw EBox::Exceptions::InvalidData(
					'data'  => __('filter type'),
					'value' => $ftype
				       );
  }

  return $ftype . '_policy';
}




## firewall method
sub usesPort
{
  my ($self, $protocol, $port, $iface) = @_;

  if ($protocol ne 'tcp') {
    return undef;
  }

  if ($iface ne 'lo') {
    # see if we need to listen in normal interfaces
    my $externalMTAs = @{ $self->allowedExternalMTAs() } > 0;
    if (not $externalMTAs) {
      return undef;
    }
  }


  if ($port == $self->port) {
    return 1;
  }
  elsif ($port == $self->fwport) {
    return 1;
  }

  return undef;
}


sub firewallHelper
{
  my ($self) = @_;

  my $externalMTAs = $self->allowedExternalMTAs();
  return new EBox::MailFilter::FirewallHelper(
			      port        => $self->port,
			      fwport        => $self->fwport,
			      externalMTAs => $externalMTAs,
					     );
}




#
# Method: statusSummary
#
#	Returns an EBox::Summary::Status to add to the services section of the
#	summary page. This class contains information about the state of the
#	module.
#
# Returns:
#
#	EBox::Summary::Status instance.
#
sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('mailfilter', __('Mail filter system'),
		$self->isRunning(), $self->service());
}

#
# Method: mailMenuItem
#
#	 Reimplements the method found in EBox::Mail::FilterProvider
# 
sub mailMenuItem
{
	my ($self) = @_;

	my $menuItem = new EBox::Menu::Item(
					    url   => 'MailFilter/Index',
					    text => __('Mail filter settings')
					   );

	return $menuItem;
}



# Method: _ldapModImplementation
#
#        All modules using any of the functions in LdapUserBase.pm
#     should override this method to return the implementation
#  of that interface.
#
# Returns:
#
#  An object implementing EBox::LdapUserBase
sub _ldapModImplementation
{
	my $self = shift;

	return new EBox::MailFilter::VDomainsLdap();
}

# Method: _vdomainModImplementation
#
#  All modules using any of the functions in LdapVDomainsBase.pm
#  should override this method to return the implementation
#  of that interface.
#
# Returns:
#
#  An object implementing EBox::LdapVDomainsBase

sub _vdomainModImplementation
{
	my $self = shift;

	return new EBox::MailFilter::VDomainsLdap();
}

   



#  Method: mailFilter
#
#   Reimplements the method needed for EBox::Mail::FilterProvider
sub mailFilter
{
  my ($self) = @_;

  if (not $self->service) {
    return undef;
  }


  my $name       = $self->mailFilterName;
  my %properties = (
		     address     => '127.0.0.1',
		     port        => $self->port(),
		     forwardPort => $self->fwport,
		     prettyName  => __('eBox internal mail filter'),
		     module      => $self->name,
		    );

  
  return ($name, \%properties);
}


#  Method: mailFilterSummary
#
#   Reimplements the method needed for EBox::Mail::FilterProvider
sub mailFilterSummary
{
  my ($self, $section) = @_;


  my $antivirus = new EBox::Summary::Status(
					    'idle_parameter', 
					    __('Antivirus'),
					    $self->antivirus->isRunning(), 
					    $self->antivirus-> service(),
					    1, # no button
					   );

  $section->add($antivirus);

  my $antispam = new EBox::Summary::Status(
					    'idle_parameter', 
					    __('Antispam'),
					    $self->antispam->isRunning(), 
					    $self->antispam-> service(),
					    1, # no button
					   );

  $section->add($antispam);
  
  
  return $section;
}


#  Method: mailFilterName
#
#   Implements the method needed for EBox::Mail::FilterProvider
sub mailFilterName
{
  return MAILFILTER_NAME;
}

1;
