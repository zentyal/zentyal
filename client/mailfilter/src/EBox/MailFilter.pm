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
          'EBox::FirewallObserver',
          'EBox::ServiceModule::ServiceInterface',
          'EBox::Model::ModelProvider',
          'EBox::Model::CompositeProvider',
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
use EBox::MailFilter::FirewallHelper;
use EBox::MailVDomainsLdap;
use EBox::Validate;
use EBox::Config;
use EBox::Global;

use constant {
  AMAVIS_SERVICE                 => 'ebox.amavisd-new',
  AMAVIS_CONF_FILE              => '/etc/amavis/conf.d/amavisd.conf',
  AMAVISPIDFILE                 => '/var/run/amavis/amavisd.pid',
  AMAVIS_INIT                   => '/etc/init.d/amavis',

  SA_INIT                       => '/etc/init.d/spamassassin',
  SAPIDFILE                     => '/var/run/spamd.pid',

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
    
    $self->{antivirus} = new EBox::MailFilter::ClamAV();
    $self->{antispam}  = new EBox::MailFilter::SpamAssassin();
    
    return $self;
}

# Method: actions
#
#       Override EBox::ServiceModule::ServiceInterface::actions
#
sub actions
{
    return [ 
            {
             'action' => __('Add clamav user to amavis group'),
             'reason' => __('Clamav need access to amavis fields to properly scan mail'),
             'module' => 'mailfilter',
            },
            {
             'action' => __('Update LDAP'),
             'reason' => __('Add amavis specific classes and fields'),
             'module' => 'mailfilter',
            },
           ]
}


# Method: usedFiles 
#
#       Override EBox::ServiceModule::ServiceInterface::files
#
sub usedFiles 
{
    my @usedFiles = (
                     {    
                      'file' =>   AMAVIS_CONF_FILE,
                      'reason' => __('To configure amavis'),
                      'module' => 'mailfilter'
                     },
                     {
                      'file' => '/etc/ldap/slapd.conf',
            'reason' => __('To add the LDAP schemas used by eBox mailfilter'),
                      'module' => 'users'
                     }
                    );
    
    push @usedFiles, EBox::MailFilter::ClamAV::usedFiles();
    push @usedFiles, EBox::MailFilter::SpamAssassin::usedFiles();
    

    return \@usedFiles;
}

# Method: enableActions 
#
#       Override EBox::ServiceModule::ServiceInterface::enableActions
#
sub enableActions
{
    root(EBox::Config::share() . '/ebox-mailfilter/ebox-mailfilter-enable');
}

#  Method: serviceModuleName
#
#   Override EBox::ServiceModule::ServiceInterface::serviceModuleName
#
sub serviceModuleName
{
    return 'mailfilter';
}

#  Method: enableModDepends
#
#   Override EBox::ServiceModule::ServiceInterface::enableModDepends
#
#  The mail dependency only exists bz we need the ldap mail data or we wil lrun
#  in error when seting mail domains options
sub enableModDepends 
{
    my ($self) = @_;
    my @depends = qw(network);

    my $mail = EBox::Global->modInstance('mail');
    if ($mail) {
        if (not $mail->configured()) {
            push @depends, 'mail';
        }
    }


    return \@depends;;
}


# Method: modelClasses
#
# Overrides:
#
#    <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
            'EBox::MailFilter::Model::General',

            'EBox::MailFilter::Model::ExternalMTA',
            'EBox::MailFilter::Model::ExternalDomain',

            'EBox::MailFilter::Model::BannedFilesPolicy',            
            'EBox::MailFilter::Model::FileExtensionACL',
            'EBox::MailFilter::Model::MIMETypeACL',
            'EBox::MailFilter::Model::BadHeadersPolicy',
            
            'EBox::MailFilter::Model::AntivirusConfiguration',
            'EBox::MailFilter::Model::FreshclamStatus',       
     
            'EBox::MailFilter::Model::AntispamConfiguration',
            'EBox::MailFilter::Model::AntispamACL',
            'EBox::MailFilter::Model::AntispamTraining',

            'EBox::MailFilter::Model::VDomains',
           ];
}


# Method: compositeClasses
#
# Overrides:
#
#    <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
            'EBox::MailFilter::Composite::Index',
            'EBox::MailFilter::Composite::GeneralAndBadHeader',
            'EBox::MailFilter::Composite::ExternalConnections',

            'EBox::MailFilter::Composite::FileFilter',

            'EBox::MailFilter::Composite::Antivirus',
            'EBox::MailFilter::Composite::Antispam',
           ];
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
# Method: _regenConfig
#
sub _regenConfig
{
    my ($self) = @_;
    my $service = $self->service();

    if ($service) {
        $self->antivirus()->writeConf($service);
        $self->antispam()->writeConf();
        $self->_writeAmavisConf();

        my $vdomainsLdap =  new EBox::MailFilter::VDomainsLdap();
        $vdomainsLdap->regenConfig();
    }
    
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
    push @masonParams, ( bannedFileTypes   => $self->bannedFilesRegexes);

    push @masonParams, ( bheadPolicy      => $self->filterPolicy('bhead'));

    push @masonParams, (adminAddress => $self->adminAddress);

    push @masonParams, (debug => EBox::Config::configkey('debug') eq 'yes');


    my $uid = getpwnam('amavis');
    my $gid = getgrnam('amavis');


    my $fileAttrs = {
                     mode => '0640',
                     uid   => $uid,
                     gid   => $gid,
                    };

    $self->writeConfFile(AMAVIS_CONF_FILE, '/mailfilter/amavisd.conf.mas', \@masonParams, $fileAttrs);
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
        throw EBox::Exceptions::Internal(
   'eBox was unable to get the full qualified domain name (FQDN) for his host/' .
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
    

    if ($self->antivirus->service() and not $self->antivirus->isRunning) {
        return 0;
    }

    if ($self->antispam->service() and not $self->antispam->isRunning) {
        return 0;
    }


    return 1 if $self->_amavisdIsRunning();
    
    return 0;
}


sub _amavisdIsRunning
{
    my ($self) = @_;
    return EBox::Service::running(AMAVIS_SERVICE);
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
    return $self->isEnabled();
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
      EBox::Service::manage(AMAVIS_SERVICE, 'restart');
    } 
    elsif ($self->service()) {
      EBox::Service::manage(AMAVIS_SERVICE, 'start');
    } 
    elsif ($self->isRunning()) {
      EBox::Service::manage(AMAVIS_SERVICE, 'stop');
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
        
        EBox::Service::manage(AMAVIS_SERVICE, 'stop');
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
    my $generalModel = $self->model('General');
    return $generalModel->port();
}

#


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
    my $externalMTA = $self->model('ExternalMTA');
    return $externalMTA->allowed();
}






sub externalDomains
{
    my ($self) = @_;
    my $externalDomain = $self->model('ExternalDomain');
    return $externalDomain->allowed();
}





sub adminAddress
{
    my ($self) = @_;
    my $general = $self->model('General');
    return $general->notificationAddress();
}



sub bannedFilesRegexes
{
  my ($self) = @_;



  my @bannedRegexes;

  my $extensionACL = $self->model('FileExtensionACL');
  push @bannedRegexes, @{ $extensionACL->bannedRegexes() };

  
  my $mimeACL = $self->model('MIMETypeACL');
  push @bannedRegexes, @{ $mimeACL->bannedRegexes() };

  return \@bannedRegexes;
}


#
# Method: filterPolicy
#
#  Returns the policy of a filter type passed as parameter. The filter type
#  could be:
#       - virus: Virus filter.
#       - spam: Spam filter.
#       - bhead: Bad headers checks.
#       - banned: Banned names and types checks.
#  And the policy:
#       - D_PASS
#       - D_REJECT
#       - D_BOUNCE
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
    
    my $modelName;
    if ($ftype eq 'banned') {
        $modelName = 'BannedFilesPolicy';
    }
    elsif ($ftype eq 'bhead') {
        $modelName = 'BadHeadersPolicy';
    }
    elsif ($ftype eq 'virus') {
        $modelName = 'AntivirusConfiguration';
    }
    elsif ($ftype eq 'spam') {
        $modelName = 'AntispamConfiguration';
    }


    my $model = $self->model($modelName);
    return $model->policy();
}

## firewall method
sub usesPort
{
  my ($self, $protocol, $port, $iface) = @_;

  if ($protocol ne 'tcp') {
    return undef;
  }

  # if we have a interface specified we can check if we don't use it. 
  if ((defined $iface) and ($iface ne 'lo')) {
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
                              active          => $self->service,
                              antivirusActive => $self->antivirus->service,
                              port            => $self->port,
                              fwport          => $self->fwport,
                              externalMTAs    => $externalMTAs,
                                             );
}




#
# Method: statusSummary
#
#       Returns an EBox::Summary::Status to add to the services section of the
#       summary page. This class contains information about the state of the
#       module.
#
# Returns:
#
#       EBox::Summary::Status instance.
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
#        Reimplements the method found in EBox::Mail::FilterProvider
# 
sub mailMenuItem
{
        my ($self) = @_;

        my $menuItem = new EBox::Menu::Item(
                                            url   => 'MailFilter/Composite/Index',
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


  my $name       = $self->mailFilterName;
  my $active     = $self->service ? 1 : 0;
  my %properties = (
                     address     => '127.0.0.1',
                     port        => $self->port(),
                     forwardPort => $self->fwport,
                     prettyName  => __('eBox internal mail filter'),
                     module      => $self->name,
                     active      => $active,
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
