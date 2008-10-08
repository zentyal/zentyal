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
                EBox::GConfModule 
                EBox::Model::ModelProvider EBox::Model::CompositeProvider
                EBox::FirewallObserver  EBox::LogObserver   
                EBox::Report::DiskUsageProvider
                EBox::ServiceModule::ServiceInterface
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
use EBox::SquidLogHelper;
use EBox::SquidOnlyFirewall;
use EBox::Summary::Module;
use EBox::Summary::Value;
use EBox::Summary::Status;
use EBox::Summary::Section;
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

          'EBox::Squid::Model::ObjectPolicy',

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
            'EBox::Squid::Composite::Extensions',
            'EBox::Squid::Composite::MIME',
            'EBox::Squid::Composite::Domains',

            'EBox::Squid::Composite::FilterTabs',
            'EBox::Squid::Composite::FilterSettings',

              'EBox::Squid::Composite::Report::TrafficReport',
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
#       Override EBox::ServiceModule::ServiceInterface::usedFiles
#
sub usedFiles
{
        return [
                {
                 'file' => '/etc/squid/squid.conf',
                 'module' => 'squid',
                 'reason' => 'HTTP proxy configuration file'
                },
                {
                 'file' => DGDIR . '/dansguardian.conf',
                 'module' => 'squid',
                 'reason' => 'Content filter configuration file'
                },
                {
                 'file' => DGDIR . "/dansguardianf1.conf",
                 'module' => 'squid',
                 'reason' => 'Content filter threshold'
                },
                {
                 'file' => DGDIR . "/bannedextensionlist",
                 'module' => 'squid',
                 'reason' => 'Content filter banned extension list'
                },
                {
                 'file' => DGDIR . "/bannedmimetypelist",
                 'module' => 'squid',
                 'reason' => 'Content filter banned mime type list'
                },
                {
                 'file' => DGDIR . "/exceptionsitelist",
                 'module' => 'squid',
                 'reason' => 'Content filter exception site list'
                },
                {
                 'file' => DGDIR . "/greysitelist",
                 'module' => 'squid',
                 'reason' => 'Content filter grey site list'
                },
                {
                 'file' => DGDIR . "/bannedsitelist",
                 'module' => 'squid',
                 'reason' => 'Content filter banned site list'
                }
               ];
}
# Method: enableActions 
#
#       Override EBox::ServiceModule::ServiceInterface::enableActions
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
#   Override EBox::ServiceModule::ServiceInterface::enableModDepends
#
sub enableModDepends 
{
    return ['firewall'];
}


sub _doDaemon
{
        my $self = shift;
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
        my $self = shift;
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

# Method: _regenConfig
#
#       Overrides base method. It regenerates the configuration
#       for squid and dansguardian.
#
sub _regenConfig 
{
        my $self = shift;
        $self->_setSquidConf();
        $self->_doDaemon();
        $self->_doDGDaemon();
}

sub _cache_mem 
{
        my $cache_mem = EBox::Config::configkey('cache_mem');
        ($cache_mem) or
                throw EBox::Exceptions::External(__('You must set the '.
                        'cache_mem variable in the ebox configuration file'));
        return $cache_mem;
}





# Method: setAuth
#
#       Set authentication
#
# Parameters:
#
#       auth - boolean: the authentication 
sub setAuth # (auth)
{
        my ($self, $auth) = @_;
        ($auth and $self->auth) and return;
        (!$auth and !$self->auth) and return;
        $self->set_bool('auth', $auth);
}


# Method: auth
#
#       Return authentication
#
# Returns:
#
#       boolean - 
sub auth
{
        my $self = shift;
        return $self->get_bool('auth');
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
        my $self = shift;
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
  my $self = shift;     

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
#       string - allow | deny | filter
#
sub globalPolicy #
{
        my $self = shift;
        return $self->_generalSetting('globalPolicy');
}

# Method: setGlobalPolicy
#
#       Sets the global policy. This is the policy that will be used for those
#       objects without an own policy.
# 
# Parameters:
#
#       policy  - allow | deny | filter
#
sub setGlobalPolicy # (policy)
{
        my ($self, $policy) = @_;
        $self->_setGeneralSetting('globalPolicy', $policy);
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

        if ($self->globalPolicy eq 'filter') {
            return 1;
        }
        elsif ($self->banThreshold > 0) {
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
        if ( @{ $objectPolicy->filteredAddresses() } ) {
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

sub _setSquidConf
{
        my $self = shift;
        if ($self->_dgNeeded) {
                $self->_squidAndDG;
        } else {
                $self->_squidOnly;
        }
}

sub _squidOnly
{
        my $self = shift;
#       my $ob = EBox::Global->modInstance('objects');
        my $objects;
        my $policy = $self->globalPolicy;
        my $squidpolicy = $policy;
        my $trans = 'no';
        my @exceptions = ();
        ($self->transproxy) and $trans = 'yes';

        my $objectPolicy = $self->model('ObjectPolicy');

        if ($policy eq 'deny') {
                push(@exceptions, @{$objectPolicy->filteredAddresses});
                push(@exceptions, @{$objectPolicy->unfilteredAddresses});
        } else {
                $squidpolicy = "allow";
                push(@exceptions, @{$objectPolicy->bannedAddresses});
        }
        
        foreach my $addr (@exceptions) {
                $objects .= "acl objects src  $addr\n";
        }

        my @array = ();
        push(@array, 'port'  => $self->port);
        push(@array, 'transparent'  => $trans);
        push(@array, 'policy'  => $squidpolicy);
        push(@array, 'objects' => $objects);
        push(@array, 'memory' => $self->_cache_mem);

        $self->writeConfFile(SQUIDCONFFILE, "squid/squid.conf.mas", \@array);
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

sub _squidAndDG
{
        my $self = shift;
#       my $ob = EBox::Global->modInstance('objects');
        my $objects;



        my $policy = $self->globalPolicy;
        my $squidpolicy = $policy;
        my $trans = 'no';

        my @exceptions = ();
        my $threshold = $self->banThreshold;
        ($self->transproxy) and $trans = 'yes';


        my $objectPolicy = $self->model('ObjectPolicy');        

        if ($policy eq 'allow') {
                push(@exceptions, @{$objectPolicy->bannedAddresses});
                push(@exceptions, @{$objectPolicy->filteredAddresses});
        } else {
                $squidpolicy = "deny";
                push(@exceptions, @{$objectPolicy->unfilteredAddresses});
        }

        foreach my $addr (@exceptions) {
                $objects .= "acl objects src  $addr\n";
        }

        my @writeParam = ();
        push(@writeParam, 'port'  => $self->port);
        push(@writeParam, 'transparent'  => $trans);
        push(@writeParam, 'policy'  => $squidpolicy);
        push(@writeParam, 'objects' => $objects);
        push(@writeParam, 'memory' => $self->_cache_mem);

        $self->writeConfFile(SQUIDCONFFILE, "squid/squid.conf.mas", \@writeParam);

        # FIXME - get a proper lang name for the current locale
        my $lang = $self->_DGLang();

        @writeParam = ();
        push(@writeParam, 'port'  => DGPORT);
        push(@writeParam, 'lang'  => $lang);
        push(@writeParam, 'squidport'  => $self->port);
        push(@writeParam, weightedPhraseThreshold  => $threshold);
        $self->writeConfFile(DGDIR . "/dansguardian.conf",
                                "squid/dansguardian.conf.mas", \@writeParam);

        @writeParam = ();
        push(@writeParam, 'threshold'  => $threshold);
        $self->writeConfFile(DGDIR . "/dansguardianf1.conf",
                                "squid/dansguardianf1.conf.mas", \@writeParam);


        @writeParam = ();
        my $extensionFilter = $self->model('ExtensionFilter');
        push(@writeParam, 'extensions'  => $extensionFilter->banned);
        $self->writeConfFile(DGDIR . "/bannedextensionlist",
                                "squid/bannedextensionlist.mas", \@writeParam);
        # Write down the banned mime type list
        @writeParam = ();
        my $mimeFilter = $self->model('MIMEFilter');
        push(@writeParam, 'mimeTypes' => $mimeFilter->banned);
        $self->writeConfFile(DGDIR . "/bannedmimetypelist",
                             "squid/bannedmimetypelist.mas", \@writeParam);

        $self->_writeDgDomainsConf();
}


sub _writeDgDomainsConf
{
  my ($self) = @_;

  my $domainFilter = $self->model('DomainFilter');

  
  
  my $allowed = $domainFilter->allowed;
  $self->writeConfFile(DGDIR . "/exceptionsitelist",
                       "squid/exceptionsitelist.mas", 
                       [ domains => $allowed ],
                      );
  
  my $filtered = $domainFilter->filtered;  
  $self->writeConfFile(DGDIR . "/greysitelist",
                       "squid/greysitelist.mas", 
                       [ domains => $filtered ],
                      );
  
  
  my $domainFilterSettings = $self->model('DomainFilterSettings');
  my $banned = $domainFilter->banned;
  my $banOptions = [
                    blockIp       => $domainFilterSettings->blockIpValue,
                    blanketBlock  => $domainFilterSettings->blanketBlockValue,
                    domains       => $banned,

                   ];
  
  $self->writeConfFile( DGDIR . "/bannedsitelist",
                       "squid/bannedsitelist.mas", 
                       $banOptions
                       );
                                 
}




sub firewallHelper 
{
        my $self = shift;
        if ($self->service) {
                if ($self->_dgNeeded()) {
                        return new EBox::SquidFirewall();
                } else  {
                        return new EBox::SquidOnlyFirewall();
                }
        }
        return undef;
}

sub statusSummary
{
        my $self = shift;
        return new EBox::Summary::Status('squid', __('HTTP Proxy'),
                                        $self->isRunning, $self->service);
}

# Method: summary
#
#       Overrides EBox::Module method.
#   
#     
sub summary
{
        my $self = shift;
        $self->isRunning() or return undef;

        my $item = new EBox::Summary::Module(__("Proxy"));
        my $section = new EBox::Summary::Section();
        my $status;
        $item->add($section);
        
        if ($self->transproxy) {
                $status = __("Enabled");
        } else {
                $status = __("Disabled");
        }
        $section->add(new EBox::Summary::Value(__("Transparent proxy"),$status));
        
        if ($self->globalPolicy eq 'allow') {
                $status = __("Allow");
        } elsif ($self->globalPolicy eq 'deny') {
                $status = __("Deny");
        } elsif ($self->globalPolicy eq 'filter') {
                $status = __("Filter");
        }

        $section->add(new EBox::Summary::Value(__("Global policy"), $status));
        
        $section->add(new EBox::Summary::Value(__("Listening port"), 
                                               $self->port));
        return $item;
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
                                            'text' => __('HTTP proxy'));

        $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/General',
                                          'text' => __('General')));


        $folder->add(new EBox::Menu::Item('url' => 'Squid/View/ObjectPolicy',
                                          'text' => __(q{Objects' Policy})));

        $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/FilterSettings',
                                          'text' => __('Filter settings')));


        $root->add($folder);
}

# Impelment LogHelper interface
sub tableInfo {
        my $self = shift;
        my $titles = { 'timestamp' => __('Date'),
                        'remotehost' => __('Host'),
                        'url'   => __('URL'),
                        'bytes' => __('Bytes'),
                        'mimetype' => __('Mime/type'),
                        'event' => __('Event')
        };
        my @order = ( 'timestamp', 'remotehost', 'url', 
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
        my $self = shift;

        return (new EBox::SquidLogHelper);
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
