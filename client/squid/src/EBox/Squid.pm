# Copyright (C) 2005  Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Squid;
use strict;
use warnings;

use base qw(
                EBox::Module::Service 
                EBox::Model::ModelProvider EBox::Model::CompositeProvider
                EBox::FirewallObserver  EBox::LogObserver   
                EBox::Report::DiskUsageProvider
                );

use EBox::Service;
use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::SquidFirewall;
use EBox::Squid::LogHelper;
use EBox::SquidOnlyFirewall;
use EBox::Dashboard::Value;
use EBox::Dashboard::Section;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo qw( :all );
use EBox::Gettext;
use EBox;
use Error qw(:try);
use HTML::Mason;


#Module local conf stuff
use constant SQUIDCONFFILE => '/etc/squid/squid.conf';
use constant MAXDOMAINSIZ => 255; 
use constant SQUIDPORT => '3128';
use constant DGPORT => '3129';
use constant DGDIR => '/etc/dansguardian';


sub _create
{
    my $class = shift;
    my $self  = $class->SUPER::_create(name => 'squid', 
                                       domain => 'ebox-squid',
                                       printableName => __('HTTP proxy'),
                                       @_);
    $self->{logger} = EBox::logger();
    bless ($self, $class);
    return $self;
}

sub domain
{
    return 'ebox-squid';
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
          'EBox::Squid::Model::GeneralSettings',

          'EBox::Squid::Model::ContentFilterThreshold',

          'EBox::Squid::Model::ExtensionFilter',
          'EBox::Squid::Model::ApplyAllowToAllExtensions',

          'EBox::Squid::Model::MIMEFilter',
          'EBox::Squid::Model::ApplyAllowToAllMIME',

          'EBox::Squid::Model::DomainFilterSettings',
          'EBox::Squid::Model::DomainFilter',
          'EBox::Squid::Model::DomainFilterFiles',
          'EBox::Squid::Model::DomainFilterCategories',

          'EBox::Squid::Model::GlobalGroupPolicy',

          'EBox::Squid::Model::ObjectPolicy',
          'EBox::Squid::Model::ObjectGroupPolicy',
          
          'EBox::Squid::Model::NoCacheDomains',

          'EBox::Squid::Model::FilterGroup',        
  
          'EBox::Squid::Model::FilterGroupContentFilterThreshold',

          'EBox::Squid::Model::UseDefaultExtensionFilter',
          'EBox::Squid::Model::FilterGroupExtensionFilter',
          'EBox::Squid::Model::FilterGroupApplyAllowToAllExtensions',

          'EBox::Squid::Model::UseDefaultMIMEFilter',
          'EBox::Squid::Model::FilterGroupMIMEFilter',
          'EBox::Squid::Model::FilterGroupApplyAllowToAllMIME',

          'EBox::Squid::Model::UseDefaultDomainFilter',
          'EBox::Squid::Model::FilterGroupDomainFilter',
          'EBox::Squid::Model::FilterGroupDomainFilterFiles',
          'EBox::Squid::Model::FilterGroupDomainFilterCategories',     
          'EBox::Squid::Model::FilterGroupDomainFilterSettings',    
 
          # Report clases
           'EBox::Squid::Model::Report::RequestsGraph',
           'EBox::Squid::Model::Report::TrafficSizeGraph',
           'EBox::Squid::Model::Report::TrafficDetails',
           'EBox::Squid::Model::Report::TrafficReportOptions',
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
         'EBox::Squid::Composite::General',

         'EBox::Squid::Composite::FilterTabs',
         'EBox::Squid::Composite::FilterSettings',
         'EBox::Squid::Composite::Extensions',
         'EBox::Squid::Composite::MIME',
         'EBox::Squid::Composite::Domains',

         'EBox::Squid::Composite::FilterGroupTabs',
         'EBox::Squid::Composite::FilterGroupSettings',
         'EBox::Squid::Composite::FilterGroupExtensions',
         'EBox::Squid::Composite::FilterGroupMIME',
         'EBox::Squid::Composite::FilterGroupDomains',

         #              'EBox::Squid::Composite::Report::TrafficReport',
        ];
}


sub isRunning
{
  return EBox::Service::running('ebox.squid');
}




sub DGIsRunning
{
  return EBox::Service::running('ebox.dansguardian');
}

# Method: usedFiles
#
#       Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
             'file' => '/etc/squid/squid.conf',
             'module' => 'squid',
             'reason' => __('HTTP proxy configuration file')
            },
            {
             'file' => DGDIR . '/dansguardian.conf',
             'module' => 'squid',
                 'reason' => __('Content filter configuration file')
            },
            {
             'file' => DGDIR . '/dansguardianf1.conf',
             'module' => 'squid',
             'reason' => __('Default filter group configuration')
            },
            {
             'file' => DGDIR . '/filtergroupslist',
                 'module' => 'squid',
             'reason' => __('Filter groups membership')
            },
            {
             'file' => DGDIR . '/bannedextensionlist',
             'module' => 'squid',
             'reason' => __('Content filter banned extension list')
            },
            {
             'file' => DGDIR . '/bannedmimetypelist',
                 'module' => 'squid',
             'reason' => __('Content filter banned mime type list')
            },
            {
             'file' => DGDIR . '/exceptionsitelist',
             'module' => 'squid',
             'reason' => __('Content filter exception site list')
            },
            {
             'file' => DGDIR . '/greysitelist',
             'module' => 'squid',
             'reason' => __('Content filter grey site list')
            },
            {
             'file' => DGDIR . '/bannedsitelist',
             'module' => 'squid',
                 'reason' => __('Content filter banned site list')
            },
            {
             'file' => DGDIR . '/exceptionurllist',
             'module' => 'squid',
             'reason' => __('Content filter exception URL list')
            },
            {
             'file' => DGDIR . '/greyurllist',
             'module' => 'squid',
             'reason' => __('Content filter grey URL list')
            },
            {
             'file' => DGDIR . '/bannedurllist',
             'module' => 'squid',
                 'reason' => __('Content filter banned URL list')
            }

           ];
}
# Method: enableActions 
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    root(EBox::Config::share() . '/ebox-squid/ebox-squid-enable');
}



# Method: serviceModuleName 
#
#       Override EBox::ServiceModule::ServiceInterface::serviceModuleName
#
sub serviceModuleName
{
    return 'squid';
}


#  Method: enableModDepends
#
#   Override EBox::Module::Service::enableModDepends
#
sub enableModDepends 
{
    return ['firewall', 'users'];
}



sub _doDaemon
{
    my ($self) = @_;
    my $action = undef;
    
    if ($self->service and $self->isRunning) {
        $action = 'restart';
    } elsif ($self->service) {
        $action = 'start';
    } elsif ($self->isRunning) {
        $action = 'stop';
    } else {
        return;
    }

    EBox::Service::manage('ebox.squid', $action);
}

sub _doDGDaemon
{
    my ($self) = @_;
    my $action = undef;
    
    if ($self->_dgNeeded and $self->DGIsRunning) {
        $action = 'restart';
    } elsif ($self->_dgNeeded) {
        $action = 'start';
    } elsif ($self->DGIsRunning) {
        $action = 'stop';
    } else {
        return;
    }
    
    EBox::Service::manage('ebox.dansguardian', $action);
}

sub _stopService 
{
    EBox::Service::manage('ebox.squid', 'stop');
    EBox::Service::manage('ebox.dansguardian', 'stop');
}


# # Method: _regenConfig
# #
# #       Overrides base method. It regenerates the configuration
# #       for squid and dansguardian.
# #
# sub _regenConfig 
# {
#     my ($self) = @_;
#     $self->_setSquidConf();
#     $self->_enforceServiceState();
# }

sub _cache_mem 
{
    my $cache_mem = EBox::Config::configkey('cache_mem');
    ($cache_mem) or
        throw EBox::Exceptions::External(__('You must set the '.
                        'cache_mem variable in the ebox configuration file'));
    return $cache_mem;
}






# Method: setService 
#
#       Enable/Disable the proxy service 
#
# Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setService # (enabled) 
{
    my ($self, $active) = @_;
    $self->enableService($active);
}

# Method: service 
#
#       Returns if the proxy service is enabled  
#
# Returns:
#
#       boolean - true if enabled, otherwise undef   
sub service
{
    my ($self) = @_;

    return $self->isEnabled();
}



sub _setGeneralSetting
{
    my ($self, $setting, $value) = @_;
    
    my $model = $self->model('GeneralSettings');
    
    my $oldValueGetter = $setting . 'Value';
    my $oldValue       = $model->$oldValueGetter;
    
    ($value xor $oldValue) or
          return;
    
    my $row = $model->row();
    my %fields = %{ $row->{plainValueHash} };
    $fields{$setting} = $value;
    
    $model->setRow(0, %fields);
}

sub _generalSetting
{
    my ($self, $setting, $value) = @_;

    my $model = $self->model('GeneralSettings');
    
    my $valueGetter = $setting . 'Value';
    return $model->$valueGetter();
}


# Method: setTransproxy
#
#      Sets the transparent proxy mode. 
#
# Parameters:
#
#       enabled - boolean. True enable, undef disable
#
sub setTransproxy # (enabled)
{
    my ($self, $trans) = @_;
    $self->_setGeneralSetting('transparentProxy', $trans);

}

# Method: transproxy 
#
#       Returns if the transparent proxy mode is enabled  
#
# Returns:
#
#       boolean - true if enabled, otherwise undef   
#
sub transproxy
{
    my ($self) = @_;;
    return $self->_generalSetting('transparentProxy');
}

# Method: setPort
#
#       Sets the listening port for the proxy
#
# Parameters:
#
#       port - string: port number
#
sub setPort # (port)
{
    my ($self, $port) = @_;
    $self->_setGeneralSetting('port', $port);
}


# Method: port
#
#       Returns the listening port for the proxy
#
# Returns:
#
#       string - port number
#
sub port
{
    my ($self) = @_;

  # FIXME Workaround. It seems that in some migrations the 
  # port variable gets ereased and returns an empty value
  
  my $port = $self->_generalSetting('port');

  unless (defined($port) and ($port =~ /^\d+$/)) {
    return SQUIDPORT;
  }

  return $port;

}




# Method: globalPolicy
#
#       Returns the global policy
# 
# Returns:
#
#       string - allow | deny | filter | auth | authAndFilter
#
sub globalPolicy #
{
    my ($self) = @_;
    return $self->_generalSetting('globalPolicy');
}

# Method: setGlobalPolicy
#
#       Sets the global policy. This is the policy that will be used for those
#       objects without an own policy.
# 
# Parameters:
#
#       policy  - allow | deny | filter | auth | authAndFilter
#
sub setGlobalPolicy # (policy)
{
    my ($self, $policy) = @_;
    $self->_setGeneralSetting('globalPolicy', $policy);
}


sub globalPolicyUsesFilter
{
  my ($self) = @_;

  my $generalSettingsRow = $self->model('GeneralSettings')->row();
  my $globalPolicy = $generalSettingsRow->elementByName('globalPolicy');
  return $globalPolicy->usesFilter();
}

sub globalPolicyUsesAllowAll
{
  my ($self) = @_;

  my $generalSettingsRow = $self->model('GeneralSettings')->row();
  my $globalPolicy = $generalSettingsRow->elementByName('globalPolicy');
  return $globalPolicy->usesAllowAll();
}

sub globalPolicyUsesAuth
{
  my ($self) = @_;

  my $generalSettingsRow = $self->model('GeneralSettings')->row();
  my $globalPolicy = $generalSettingsRow->elementByName('globalPolicy');
  return $globalPolicy->usesAuth();
}



# Function: banThreshold
#
#       Gets the weighted phrase value that will cause a page to be banned.
#
# Returns:
#
#       A positive integer with the current ban threshold.
sub banThreshold
{
    my ($self) = @_;
    my $model = $self->model('ContentFilterThreshold');
    return $model->contentFilterThresholdValue();
}       

sub _dgNeeded
 {
     my ($self) = @_;
     
     if (not $self->service) {
         return undef;
      }  
     
     if ($self->globalPolicyUsesFilter()) {
         return 1;
     }
     elsif ($self->_banThresholdActive()) {
         return 1;
     }

     my $domainFilter = $self->model('DomainFilter');
     if ( @{ $domainFilter->banned } )  {
         return 1;
     }
     elsif ( @{ $domainFilter->allowed } ) {
         return 1;
     }
     elsif ( @{ $domainFilter->filtered } ) {
         return 1;
     }
        

     my $domainFilterSettings = $self->model('DomainFilterSettings');
     if ($domainFilterSettings->blanketBlockValue) {
         return 1;
     }
     elsif ($domainFilterSettings->blockIpValue) {
         return 1;
     }
     
     
     my $objectPolicy = $self->model('ObjectPolicy');
     if ( $objectPolicy->existsFilteredObjects() ) {
         return 1;
     }
     
     return undef;
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;
    ($protocol eq 'tcp') or return undef;
    # DGPORT is hard-coded, it is reported as used even if
    # the service is disabled.
    ($port eq DGPORT) and return 1;
    # the port selected by the user (by default SQUIDPORT) is only reported
    # if the service is enabled
    ($self->service) or return undef;
    ($port eq $self->port) and return 1;
    return undef;
}

sub _setConf
{
  my ($self) = @_;
  $self->_writeSquidConf();

  if ($self->_dgNeeded()) {
      $self->_writeDgConf();
  }
}


# Function: dansguardianPort 
#
#       Returns the listening port for dansguardian
#
# Returns:
#
#       string - listening port
sub dansguardianPort
{
    return DGPORT;
}


sub _writeSquidConf
{
  my ($self) = @_;

  my $trans = $self->transproxy() ? 'yes' : 'no';
  my $groupsPolicies = $self->model('GlobalGroupPolicy')->groupsPolicies();       
  my $objectsPolicies = $self->model('ObjectPolicy')->objectsPolicies();       
  

  my @writeParam = ();
  push @writeParam, ('port'  => $self->port);
  push @writeParam, ('transparent'  => $trans);
  push @writeParam, ('authNeeded'  => $self->globalPolicyUsesAuth);
  push @writeParam, ('allowAll'  => $self->globalPolicyUsesAllowAll);
  push @writeParam, ('groupsPolicies' => $groupsPolicies);
  push @writeParam, ('objectsPolicies' => $objectsPolicies);
  push @writeParam, ('memory' => $self->_cache_mem);
  push @writeParam, ('notCachedDomains'=> $self->_notCachedDomains());

  $self->writeConfFile(SQUIDCONFFILE, "squid/squid.conf.mas", \@writeParam);
}



sub _writeDgConf
{
  my ($self) = @_;


  # FIXME - get a proper lang name for the current locale
  my $lang = $self->_DGLang();

  my @dgFilterGroups = @{ $self->_dgFilterGroups };

  my @writeParam = ();
  push(@writeParam, 'port'  => DGPORT);
  push(@writeParam, 'lang'  => $lang);
  push(@writeParam, 'squidport'  => $self->port);
  push(@writeParam, weightedPhraseThreshold  => $self->_banThresholdActive);
  push(@writeParam, nGroups => scalar @dgFilterGroups);

  $self->writeConfFile(DGDIR . "/dansguardian.conf",
                       "squid/dansguardian.conf.mas", \@writeParam);


   # write group lists  
    $self->writeConfFile(DGDIR . "/filtergroupslist",
                         "squid/filtergroupslist.mas", 
                         [
                          groups => \@dgFilterGroups,
                         ]
                        );


  foreach my $group (@dgFilterGroups) {
      my $number = $group->{number};

      @writeParam = ();


      push(@writeParam, 'group'  => $number);
      push(@writeParam, 'threshold'  => $group->{threshold});
      push(@writeParam, 'groupName'  => $group->{groupName});
      push(@writeParam, 'defaults'      => $group->{defaults});
      EBox::Module::Base::writeConfFileNoCheck(DGDIR . "/dansguardianf$number.conf",
                       "squid/dansguardianfN.conf.mas", \@writeParam);

      if (not exists $group->{defaults}->{bannedextensionlist}) {
          @writeParam = ();
          push(@writeParam, 'extensions'  => $group->{bannedExtensions});
          EBox::Module::Base::writeConfFileNoCheck(DGDIR . "/bannedextensionlist$number",
                                      "squid/bannedextensionlist.mas", \@writeParam);
      }

      if (not exists $group->{defaults}->{bannedmimetypelist}) {
          @writeParam = ();
          push(@writeParam, 'mimeTypes' => $group->{bannedMIMETypes});
          EBox::Module::Base::writeConfFileNoCheck(DGDIR . "/bannedmimetypelist$number",
                           "squid/bannedmimetypelist.mas", \@writeParam);
      }

      $self->_writeDgDomainsConf($group);
  }


  $self->_cleanDomainFilterFiles();

}


sub revokeConfig
{
    my ($self) = @_;

    my $res = $self->SUPER::revokeConfig();

    $self->_cleanDomainFilterFiles();

    return $res;
}

sub _cleanDomainFilterFiles
{
    my ($self) = @_;
  # purge empty file list directories and orphaned files/directories
  # XXX is not the ideal palce to
  # do this but we don't have options bz deletedRowNotify is called before
  # deleting the file so the directory is not empty

    # XXX we clean the DomainFilterFiles aside bz it has at FilterFiles
    # componet with distinct name
    my $domainFilterFiles = $self->model('DomainFilterFiles');
    $domainFilterFiles->cleanOrphanedFiles();

    my $filterGroups = $self->model('FilterGroup');
    my $defaultGroupName = $filterGroups->defaultGroupName();
    foreach my $row ( @{ $filterGroups->rows() } ) {
        if ($row->valueByName('name') eq $defaultGroupName) {
            next;
        }

        my $filterPolicy =   $row->elementByName('filterPolicy');
        my $fgSettings = $filterPolicy->foreignModelInstance();
        my $fgDomainFilterFiles = $fgSettings->componentByName('FilterGroupDomainFilterFiles', 1);
        $fgDomainFilterFiles->cleanOrphanedFiles();
    }


    $domainFilterFiles->cleanEmptyDirs(); # this only need to be called one time
                                          # for all profiles
}

sub _banThresholdActive
{
    my ($self) = @_;

    my @dgFilterGroups = @{ $self->_dgFilterGroups };
    foreach my $group (@dgFilterGroups) {
        if ($group->{threshold} > 0) {
            return 1;
        }
    }

    return 0;
}

sub _notCachedDomains
{
    my ($self) = @_;
    my $model = $self->model('NoCacheDomains');
    return $model->notCachedDomains();
}


sub _dgFilterGroups
{
    my ($self) = @_;

    my $filterGroupModel = $self->model('FilterGroup');
    return $filterGroupModel->filterGroups();
}


# sub _defaultGroup
# {
#     my ($self) = @_;

#     my $default = {
#                    number => 1,
#                    groupName => 'default',
#                    threshold => $self->banThreshold,
#                    bannedExtensions =>  $self->model('ExtensionFilter')->banned(),
#                    bannedMIMETypes =>  $self->model('MIMEFilter')->banned(),
#                    defaults => {},
#                   };

#     my $domainFilter      = $self->model('DomainFilter');
#     my $domainFilterFiles = $self->model('DomainFilterFiles');

#     $default->{exceptionsitelist} = [ 
#                         domains => $domainFilter->allowed(),
#                                      includes => $domainFilterFiles->allowed(),
#                        ];

#     $default->{exceptionurllist} = [
#                                     domains => [],
#                                     includes => $domainFilterFiles->allowedUrls(),
#                                    ];

#     $default->{greysitelist} = [ 
#                         domains => $domainFilter->filtered(),
#                         includes => $domainFilterFiles->filtered(),
#                        ];
  
#     $default->{greyurllist} = [ 
#                         domains => [],
#                         includes => $domainFilterFiles->filteredUrls(),
#                        ];



#     $default->{bannedurllist} = [ 
#                         domains => [],
#                         includes => $domainFilterFiles->bannedUrls(),
#                        ];

  
  
#   my $domainFilterSettings = $self->model('DomainFilterSettings');
    
#   $default->{bannedsitelist} = [
#                     blockIp       => $domainFilterSettings->blockIpValue,
#                     blanketBlock  => $domainFilterSettings->blanketBlockValue,
#                     domains       => $domainFilter->banned(),
#                     includes      => $domainFilterFiles->banned(),
#                    ];

#     return $default;
# }

sub _writeDgDomainsConf
{
  my ($self, $group) = @_;

  my $number = $group->{number};

  my @domainsFiles = (
      'bannedsitelist'  , 'bannedurllist', 
      'greysitelist'    , 'greyurllist',
      'exceptionsitelist', 'exceptionurllist',
    );
  
  foreach my $file (@domainsFiles) {
      if (exists $group->{defaults}->{$file}) {
          next;
      }

      my $path     = DGDIR . '/' . $file . $number;
      my $template = "squid/$file.mas";
      EBox::Module::Base::writeConfFileNoCheck($path,
                                  $template, 
                                  $group->{$file},
                                 );
  }

}

sub firewallHelper 
{
    my ($self) = @_;
    if ($self->service) {
        if ($self->_dgNeeded()) {
            return new EBox::SquidFirewall();
        } else  {
            return new EBox::SquidOnlyFirewall();
        }
    }
    return undef;
}

sub proxyWidget
{
    my ($self, $widget) = @_;
    $self->isRunning() or return;

    my $section = new EBox::Dashboard::Section('proxy');

    my $status;
    $widget->add($section);

    if ($self->transproxy) {
        $status = __("Enabled");
    } else {
        $status = __("Disabled");
    }
    $section->add(new EBox::Dashboard::Value(__("Transparent proxy"),$status));

    if ($self->globalPolicy eq 'allow') {
        $status = __("Allow");
    } elsif ($self->globalPolicy eq 'deny') {
        $status = __("Deny");
    } elsif ($self->globalPolicy eq 'filter') {
        $status = __("Filter");
    }

    $section->add(new EBox::Dashboard::Value(__("Global policy"), $status));

    $section->add(new EBox::Dashboard::Value(__("Listening port"), 
                $self->port));
}

### Method: widgets
#
#   Overrides <EBox::Module::widgets>
#
sub widgets
{
    return {
        'proxy' => {
            'title' => __("HTTP proxy"),
            'widget' => \&proxyWidget
        }
    };
}

# Method: menu 
#
#       Overrides EBox::Module method.
#
#
sub menu
{
    my ($self, $root) = @_;
    my $folder = new EBox::Menu::Folder('name' => 'Squid',
                                        'text' => $self->printableName());
    
    $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/General',
                                      'text' => __('General')));
    

        $folder->add(new EBox::Menu::Item('url' => 'Squid/View/ObjectPolicy',
                                          'text' => __(q{Objects' Policy})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/GlobalGroupPolicy',
                                      'text' => __(q{Groups' Policy})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/FilterGroup',
                                      'text' => __(q{Filter profiles})));

#     $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/FilterSettings',
#                                       'text' => __('Filter settings')));


    $root->add($folder);
}

#  Method: _daemons
#
#   Override <EBox::ServiceModule::ServiceInterface::_daemons>
#
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.squid'
        },
        {
            'name' => 'ebox.dansguardian',
            'precondition' => \&_dgNeeded
        }
    ];
}

# Impelment LogHelper interface
sub tableInfo 
{
    my ($self) =@_;
    my $titles = { 'timestamp' => __('Date'),
                   'remotehost' => __('Host'),
                   'rfc931'     => __('User'),
                   'url'   => __('URL'),
                   'bytes' => __('Bytes'),
                   'mimetype' => __('Mime/type'),
                   'event' => __('Event')
                 };
    my @order = ( 'timestamp', 'remotehost', 'rfc931', 'url', 
                  'bytes', 'mimetype', 'event');

    my $events = { 'accepted' => __('Accepted'), 
                   'denied' => __('Denied'),
                   'filtered' => __('Filtered') };
    return {
            'name' => __('HTTP proxy'),
            'index' => 'squid',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'access',
            'timecol' => 'timestamp',
            'filter' => ['url', 'remotehost'],
            'events' => $events,
            'eventcol' => 'event',
            'consolidate' => $self->_consolidateConfiguration(),
           };
}


sub _consolidateConfiguration
{
    my ($self) = @_;

    my $traffic = {
                   accummulateColumns => {
                                          requests => 1,
                                          accepted => 0,
                                          accepted_size => 0,
                                          denied   => 0,
                                          denied_size => 0,
                                          filtered => 0,
                                          filtered_size => 0,
                                         },
                   consolidateColumns => {
#                       rfc931 => {},
                       event => {
                                 conversor => sub { return 1 },
                                 accummulate => sub {
                                     my ($v) = @_;
                                     return $v;      
                                   },
                                },
                       bytes => {
                                 # size is in Kb
                                 conversor => sub {
                                     my ($v)  = @_;
                                     return sprintf("%i", $v/1024);
                                 },
                                 accummulate => sub {
                                     my ($v, $row) = @_;
                                     my $event = $row->{event};
                                     return $event . '_size';
                                 }
                                },
                     }
                  };


    return {
            squid_traffic => $traffic,

           };
}



sub logHelper
{
    my ($self) = @_;
    return (new EBox::Squid::LogHelper);
}



# Overrides:
#   EBox::Report::DiskUsageProvider::_facilitiesForDiskUsage
sub _facilitiesForDiskUsage
{
  my ($self) = @_;
  
  my $cachePath          = '/var/spool/squid';
  my $cachePrintableName = __(q{HTTP Proxy's cache files} );

  return {
          $cachePrintableName => [ $cachePath ],
         };

}

# Method to return the language to use with DG depending on the locale
# given by EBox
sub _DGLang
{
    my $locale = EBox::locale();
    my $lang = 'ukenglish';

    my %langs = (
                 'da' => 'danish',
                 'de' => 'german',
                 'es' => 'arspanish',
                 'fr' => 'french',
                 'it' => 'italian',
                 'nl' => 'dutch',
                 'pl' => 'polish',
                 'pt' => 'portuguese',
                 'sv' => 'swedish',
                 'tr' => 'turkish',
                );

    $locale = substr($locale,0,2);
    if ( exists $langs{$locale} ) {
        $lang = $langs{$locale};
    }

    return $lang;

}

1;
