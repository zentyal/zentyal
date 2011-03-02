# Copyright (C) 2008-2010 eBox Technologies S.L.
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
            EBox::FirewallObserver EBox::LogObserver EBox::LdapModule
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
use EBox::Squid::LdapUserImplementation;
use EBox::Squid::Model::DomainFilterFiles;

use EBox::DBEngineFactory;
use EBox::Dashboard::Value;
use EBox::Dashboard::Section;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo qw( :all );
use EBox::Gettext;
use EBox;
use Error qw(:try);
use HTML::Mason;
use File::Basename;

use EBox::NetWrappers qw(to_network_with_mask);

#Module local conf stuff
use constant SQUIDCONFFILE => '/etc/squid/squid.conf';
use constant MAXDOMAINSIZ => 255;
use constant SQUIDPORT => '3128';
use constant DGPORT => '3129';
use constant DGDIR => '/etc/dansguardian';
use constant DGLISTSDIR => DGDIR . '/lists';
use constant DG_LOGROTATE_CONF => '/etc/logrotate.d/dansguardian';
use constant CLAMD_SCANNER_CONF_FILE => DGDIR . '/contentscanners/clamdscan.conf';

sub _create
{
    my $class = shift;
    my $self  = $class->SUPER::_create(name => 'squid',
                                       domain => 'ebox-squid',
                                       printableName => __n('HTTP Proxy'),
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

        'EBox::Squid::Model::DefaultAntiVirus',
        'EBox::Squid::Model::FilterGroupAntiVirus',

        'EBox::Squid::Model::DelayPools1',
        'EBox::Squid::Model::DelayPools2',

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

        'EBox::Squid::Composite::DelayPools',

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
#       Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
             'file' => '/etc/squid/squid.conf',
             'module' => 'squid',
             'reason' => __('HTTP Proxy configuration file')
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
             'file' => DGLISTSDIR . '/filtergroupslist',
             'module' => 'squid',
             'reason' => __('Filter groups membership')
            },
            {
             'file' => DGLISTSDIR . '/bannedextensionlist',
             'module' => 'squid',
             'reason' => __('Content filter banned extension list')
            },
            {
             'file' => DGLISTSDIR . '/bannedmimetypelist',
             'module' => 'squid',
             'reason' => __('Content filter banned mime type list')
            },
            {
             'file' => DGLISTSDIR . '/exceptionsitelist',
             'module' => 'squid',
             'reason' => __('Content filter exception site list')
            },
            {
             'file' => DGLISTSDIR . '/greysitelist',
             'module' => 'squid',
             'reason' => __('Content filter grey site list')
            },
            {
             'file' => DGLISTSDIR . '/bannedsitelist',
             'module' => 'squid',
             'reason' => __('Content filter banned site list')
            },
            {
             'file' => DGLISTSDIR . '/exceptionurllist',
             'module' => 'squid',
             'reason' => __('Content filter exception URL list')
            },
            {
             'file' => DGLISTSDIR . '/greyurllist',
             'module' => 'squid',
             'reason' => __('Content filter grey URL list')
            },
            {
             'file' => DGLISTSDIR . '/bannedurllist',
             'module' => 'squid',
             'reason' => __('Content filter banned URL list')
            },
            {
             'file' =>    DGLISTSDIR . '/bannedphraselist',
             'module' => 'squid',
             'reason' => __('Forbidden phrases list'),
            },
            {
             'file' =>    DGLISTSDIR . '/exceptionphraselist',
             'module' => 'squid',
             'reason' => __('Exception phrases list'),
            },
            {
             'file' =>    DGLISTSDIR . '/pics',
             'module' => 'squid',
             'reason' => __('PICS ratings configuration'),
            },
            {
             'file' => DG_LOGROTATE_CONF,
             'module' => 'squid',
             'reason' => __(q{Dansguardian's log rotation configuration}),
            },
            {
             'file' => CLAMD_SCANNER_CONF_FILE,
             'module' => 'squid',
             'reason' => __(q{Dansguardian's antivirus scanner configuration}),
            },
            {
             'file' =>    DGLISTSDIR . '/authplugins/ipgroups',
             'module' => 'squid',
             'reason' => __('Filter groups per IP'),
            },
           ];
}


# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
            {
             'action' => __('Overwrite blocked page templates'),
             'reason' => __('Dansguardian blocked page templates will be overwritten with Zentyal'
                           . ' customized templates.'),
             'module' => 'squid'
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


#  Method: enableModDepends
#
#   Override EBox::ServiceModule::ServiceInterface::enableModDepends
#
sub enableModDepends
{
    my ($self) = @_;

    my @mods = ('firewall', 'users');
    if ($self->_antivirusNeeded()) {
        push @mods,  'antivirus';
    }

    return \@mods;
}


sub _cache_mem
{
    my $cache_mem = EBox::Config::configkey('cache_mem');
    ($cache_mem) or
        throw EBox::Exceptions::External(__('You must set the '.
                        'cache_mem variable in the Zentyal configuration file'));
    return $cache_mem;
}

sub _max_object_size
{
    my $max_object_size = EBox::Config::configkey('maximum_object_size');
    ($max_object_size) or
        throw EBox::Exceptions::External(__('You must set the '.
                        'max_object_size variable in the Zentyal configuration file'));
    return $max_object_size;
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

sub _setGeneralSetting
{
    my ($self, $setting, $value) = @_;

    my $model = $self->model('GeneralSettings');

    my $oldValueGetter = $setting . 'Value';
    my $oldValue       = $model->$oldValueGetter;

    ($value xor $oldValue) or return;

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
    my ($self) = @_;

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
#
sub banThreshold
{
    my ($self) = @_;
    my $model = $self->model('ContentFilterThreshold');
    return $model->contentFilterThresholdValue();
}

sub _dgNeeded
{
    my ($self) = @_;

    if (not $self->isEnabled()) {
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
    ($self->isEnabled()) or return undef;
    ($port eq $self->port) and return 1;
    return undef;
}


# we override this because we want to call _cleanDomainFilterFiles regardless of
# th enable state of the service. why?. We dont want to have orphaned domain
# filter files bz they can spend a lot of space and for this we need to call
# _cleanDomainFilterFiles after each restart or revokation
sub restartService
{
    my ($self, @params) = @_;

    $self->_cleanDomainFilterFiles();

    $self->SUPER::restartService(@params);
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

sub _antivirusNeeded
{
    my ($self, $filterGroups_r) = @_;

    if (not $filterGroups_r) {
        my $filterGroups = $self->model('FilterGroup');
        return $filterGroups->antivirusNeeded();
    }

    foreach my $filterGroup (@{ $filterGroups_r }) {
        if ($filterGroup->{antivirus}) {
            return 1;
        }
    }

    return 0;
}


sub notifyAntivirusEnabled
{
    my ($self, $enabled) = @_;
    $self->_dgNeeded() or
        return;

    $self->setAsChanged();
}


sub _writeSquidConf
{
    my ($self) = @_;

    my $trans = $self->transproxy() ? 'yes' : 'no';
    my $groupsPolicies = $self->model('GlobalGroupPolicy')->groupsPolicies();
    my $objectsPolicies = $self->model('ObjectPolicy')->objectsPolicies();

    my $cacheDirSize = $self->model('GeneralSettings')->cacheDirSizeValue();

    my $users = EBox::Global->modInstance('users');
    my $network = EBox::Global->modInstance('network');

    my $append_domain = $network->model('SearchDomain')->domainValue();
    my $cache_host = $network->model('Proxy')->serverValue();
    my $cache_port = $network->model('Proxy')->portValue();

    my @writeParam = ();
    push @writeParam, ('port'  => $self->port);
    push @writeParam, ('transparent'  => $trans);
    push @writeParam, ('authNeeded'  => $self->globalPolicyUsesAuth);
    push @writeParam, ('allowAll'  => $self->globalPolicyUsesAllowAll);
    push @writeParam, ('localnets' => $self->_localnets());
    push @writeParam, ('groupsPolicies' => $groupsPolicies);
    push @writeParam, ('objectsPolicies' => $objectsPolicies);
    push @writeParam, ('objectsDelayPools' => $self->_objectsDelayPools);
    push @writeParam, ('nameservers' => $network->nameservers());
    push @writeParam, ('append_domain' => $append_domain);
    push @writeParam, ('cache_host' => $cache_host);
    push @writeParam, ('cache_port' => $cache_port);
    push @writeParam, ('memory' => $self->_cache_mem);
    push @writeParam, ('max_object_size' => $self->_max_object_size);
    push @writeParam, ('notCachedDomains'=> $self->_notCachedDomains());
    push @writeParam, ('cacheDirSize'     => $cacheDirSize);
    push @writeParam, ('dn'     => $users->ldap()->dn());
    unless ($users->mode() eq 'slave') {
        push @writeParam, ('ldapport' => $users->ldap()->ldapConf()->{'port'});
    } else {
        push @writeParam, ('ldapport' => $users->ldap()->ldapConf()->{'replicaport'});
    }
    my $global = EBox::Global->getInstance(1);
    if ( $global->modExists('remoteservices') ) {
        my $rs = EBox::Global->modInstance('remoteservices');
        push(@writeParam, ('snmpEnabled' => $rs->eBoxSubscribed() ));
    }

    $self->writeConfFile(SQUIDCONFFILE, "squid/squid.conf.mas", \@writeParam);
}


sub _objectsDelayPools
{
    my ($self) = @_;

    my @delayPools1 = @{$self->model('DelayPools1')->delayPools1()};
    my @delayPools2 = @{$self->model('DelayPools2')->delayPools2()};

    my @delayPools;
    push (@delayPools, @delayPools1);
    push (@delayPools, @delayPools2);

    return \@delayPools;
}


sub _localnets
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');
    my $ifaces = $network->InternalIfaces();
    my @localnets;
    for my $iface (@{$ifaces}) {
        my $net = to_network_with_mask($network->ifaceNetwork($iface), $network->ifaceNetmask($iface));
        push (@localnets, $net);
    }

    return \@localnets;
}


sub _writeDgConf
{
    my ($self) = @_;

    # FIXME - get a proper lang name for the current locale
    my $lang = $self->_DGLang();

    my @dgFilterGroups = @{ $self->_dgFilterGroups };

    my @writeParam = ();

    push(@writeParam, 'port' => DGPORT);
    push(@writeParam, 'lang' => $lang);
    push(@writeParam, 'squidport' => $self->port);
    push(@writeParam, 'weightedPhraseThreshold' => $self->_banThresholdActive);
    push(@writeParam, 'nGroups' => scalar @dgFilterGroups);

    my $antivirus = $self->_antivirusNeeded(\@dgFilterGroups);
    push(@writeParam, 'antivirus' => $antivirus);

    my $maxchildren = EBox::Config::configkey('maxchildren');
    push(@writeParam, 'maxchildren' => $maxchildren);

    my $minchildren = EBox::Config::configkey('minchildren');
    push(@writeParam, 'minchildren' => $minchildren);

    my $minsparechildren = EBox::Config::configkey('minsparechildren');
    push(@writeParam, 'minsparechildren' => $minsparechildren);

    my $preforkchildren = EBox::Config::configkey('preforkchildren');
    push(@writeParam, 'preforkchildren' => $preforkchildren);

    my $maxsparechildren = EBox::Config::configkey('maxsparechildren');
    push(@writeParam, 'maxsparechildren' => $maxsparechildren);

    my $maxagechildren = EBox::Config::configkey('maxagechildren');
    push(@writeParam, 'maxagechildren' => $maxagechildren);

    $self->writeConfFile(DGDIR . '/dansguardian.conf',
            'squid/dansguardian.conf.mas', \@writeParam);

    # write group lists
    $self->writeConfFile(DGLISTSDIR . "/filtergroupslist",
                         'squid/filtergroupslist.mas',
                         [ groups => \@dgFilterGroups ]);

    # disable banned, exception phrases lists, regex URLs and PICS ratings
    $self->writeConfFile(DGLISTSDIR . '/bannedphraselist',
                         'squid/bannedphraselist.mas', []);

    $self->writeConfFile(DGLISTSDIR . '/exceptionphraselist',
                         'squid/exceptionphraselist.mas', []);

    $self->writeConfFile(DGLISTSDIR . '/pics',
                         'squid/pics.mas', []);

    $self->writeConfFile(DGLISTSDIR . '/bannedregexpurllist',
                         'squid/bannedregexpurllist.mas', []);

    $self->_writeDgIpGroups();

    if ($antivirus) {
        my $avMod = EBox::Global->modInstance('antivirus');
        $self->writeConfFile(CLAMD_SCANNER_CONF_FILE,
                             'squid/clamdscan.conf.mas',
                             [ clamdSocket => $avMod->localSocket() ]);
    }

    foreach my $group (@dgFilterGroups) {
        my $number = $group->{number};

        @writeParam = ();

        push(@writeParam, 'group' => $number);
        push(@writeParam, 'antivirus' => $group->{antivirus});
        push(@writeParam, 'threshold' => $group->{threshold});
        push(@writeParam, 'groupName' => $group->{groupName});
        push(@writeParam, 'defaults' => $group->{defaults});
        EBox::Module::Base::writeConfFileNoCheck(DGDIR . "/dansguardianf$number.conf",
                'squid/dansguardianfN.conf.mas', \@writeParam);

        if (not exists $group->{defaults}->{bannedextensionlist}) {
            @writeParam = ();
            push(@writeParam, 'extensions'  => $group->{bannedExtensions});
            EBox::Module::Base::writeConfFileNoCheck(DGLISTSDIR . "/bannedextensionlist$number",
                    'squid/bannedextensionlist.mas', \@writeParam);
        }

        if (not exists $group->{defaults}->{bannedmimetypelist}) {
            @writeParam = ();
            push(@writeParam, 'mimeTypes' => $group->{bannedMIMETypes});
            EBox::Module::Base::writeConfFileNoCheck(DGLISTSDIR . "/bannedmimetypelist$number",
                    'squid/bannedmimetypelist.mas', \@writeParam);
        }

        $self->_writeDgDomainsConf($group);
    }

    $self->_writeDgTemplates();

    $self->_writeDgLogrotate();
}


sub _writeDgIpGroups
{
    my ($self) = @_;

    my $objects = $self->model('ObjectPolicy');

    $self->writeConfFile(DGLISTSDIR . '/authplugins/ipgroups',
                       'squid/ipgroups.mas',
                       [
                        filterGroups =>
                           $objects->objectsFilterGroups()
                       ]);
}

sub _writeDgTemplates
{
    my ($self) = @_;

    my $lang = $self->_DGLang();
    my $file = DGDIR . '/languages/' . $lang . '/template.html';

    EBox::Module::Base::writeConfFileNoCheck($file,
                                             'squid/template.html.mas',
                                             []);
}

sub _writeDgLogrotate
{
    my ($self) = @_;
    $self->writeConfFile(DG_LOGROTATE_CONF,
                        'squid/dansguardian.logrotate',
                        []);
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
    # XXX is not the ideal place to
    # do this but we don't have options bz deletedRowNotify is called before
    # deleting the file so the directory is not empty

    # FIXME: This is a workaround, as there are bugs with parentComposite
    # should be implemented better someday
    # This avoids the bug of deleting list files in the second restart
    my $dir = $self->isReadOnly() ? 'ebox-ro' : 'ebox';
    my @keys = $self->{redis}->_redis_call('keys',
        "/$dir/modules/squid/*/FilterGroupDomainFilterFiles/*/fileList_path");
    # default profile
    push @keys, $self->{redis}->_redis_call('keys',
        "/$dir/modules/squid/*/DomainFilterFiles/*/fileList_path");

    my %fgDirs;
    foreach my $key (@keys) {
        my $path = $self->get_string($key);
        my $basename = basename($path);
        $fgDirs{$path} = 1;
        $fgDirs{"$path/archives"} = 1;
        $fgDirs{"$path/archives/$basename"} = 1;
        my $profileDir = dirname($path);
        $fgDirs{$profileDir} = 1;
    }

    #foreach my $domainFilterFiles ( @{ $self->_domainFilterFilesComponents() } ) {
        # FIXME: _domainFilterFilesComponents returns a wrong list
        # that's why this is workarounded with _redis_call
        # $fgDirs{$domainFilterFiles->listFileDir} = 1;

        #$domainFilterFiles->setupArchives();

        # No need to clean files separately, we will clean
        # the whole non-referenced dirs in the next loop
        #$domainFilterFiles->cleanOrphanedFiles();
    #}

    my $defaultListFileDir = EBox::Squid::Model::DomainFilterFiles->listFileDir();

    # As now the directories for each profile are not deleted separately with
    # cleanOrphanedFiles, we change the depth of the find to remove them here
    # my $findCmd = 'find ' .  $defaultListFileDir  . ' -maxdepth 1 -type d';
    my $findCmd = 'find ' .  $defaultListFileDir  . ' -mindepth 1 -maxdepth 3';
    my @dirs = `$findCmd`;
    chomp @dirs;

    my @deleteCmds;
    foreach my $dir (@dirs) {
        next if exists $fgDirs{$dir};

        push (@deleteCmds, "rm -rf $dir");
    }
    EBox::Sudo::root(@deleteCmds);
}

sub _domainFilterFilesComponents
{
    my ($self) = @_;

    my @components;

    my $filterGroups = $self->model('FilterGroup');
    my $defaultGroupName = $filterGroups->defaultGroupName();
    foreach my $id ( @{ $filterGroups->ids() } ) {
        my $row = $filterGroups->row($id);
        my $filterPolicy =   $row->elementByName('filterPolicy');
        my $fSettings = $filterPolicy->foreignModelInstance();

        my $domainFilterFiles;
        if ($row->valueByName('name') eq $defaultGroupName) {
            push @components,
                $fSettings->componentByName('DomainFilterFiles', 1);
        } else {
            push @components,
                $fSettings->componentByName('FilterGroupDomainFilterFiles', 1);
        }
    }

    return \@components;
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

sub _writeDgDomainsConf
{
    my ($self, $group) = @_;

    my $number = $group->{number};

    my @domainsFiles = ('bannedsitelist', 'bannedurllist',
                        'greysitelist', 'greyurllist',
                        'exceptionsitelist', 'exceptionurllist');

    foreach my $file (@domainsFiles) {
        if (exists $group->{defaults}->{$file}) {
            next;
        }

        my $path = DGLISTSDIR . '/' . $file . $number;
        my $template = "squid/$file.mas";
        EBox::Module::Base::writeConfFileNoCheck($path,
                                                 $template,
                                                 $group->{$file});
    }
}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
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

    $section->add(new EBox::Dashboard::Value(__("Listening port"), $self->port));
}

### Method: widgets
#
#   Overrides <EBox::Module::widgets>
#
sub widgets
{
    return {
        'proxy' => {
            'title' => __("HTTP Proxy"),
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
                                        'text' => $self->printableName(),
                                        'separator' => 'Gateway',
                                        'order' => 210);

    $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/General',
                                      'text' => __('General')));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/DelayPools',
                                      'text' => __(q{Bandwidth Throttling})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/ObjectPolicy',
                                      'text' => __(q{Objects' Policy})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/GlobalGroupPolicy',
                                      'text' => __(q{Groups' Policy})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/FilterGroup',
                                      'text' => __(q{Filter Profiles})));

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
    my ($self) = @_;

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
    return [{
            'name' => __('HTTP Proxy'),
            'index' => 'squid',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'squid_access',
            'filter' => ['url', 'remotehost', 'rfc931'],
            'events' => $events,
            'eventcol' => 'event',
            'consolidate' => $self->_consolidateConfiguration(),
           }];
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
                       rfc931 => {},
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
    my $cachePrintableName = 'HTTP Proxy cache';

    return { $cachePrintableName => [ $cachePath ] };

}

# Method to return the language to use with DG depending on the locale
# given by EBox
sub _DGLang
{
    my $locale = EBox::locale();
    my $lang = 'ukenglish';

    # TODO: Make sure this list is not obsolete
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

sub aroundDumpConfig
{
    my ($self, $dir, %options) = @_;

    my $bugReport = $options{bug};
    if (not $bugReport) {
        $self->SUPER::aroundDumpConfig($dir, %options);
        return
    }

    # for bug report we dont save archive files
    $self->_dump_to_file($dir);

    $self->dumpConfig($dir, %options);
}

sub restoreConfig
{
    my ($self, $dir) = @_;
    # to regenerate categorized domain files
    $self->_cleanDomainFilterFiles(orphanedCheck => 1);
}

sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    my $db = EBox::DBEngineFactory::DBEngine();

    my $traffic = $self->runMonthlyQuery($beg, $end, {
        'select' => "CASE WHEN code ~ 'HIT' THEN 'hit' ELSE 'miss' END" .
                    " AS main_code, SUM(bytes) AS bytes, SUM(hits) AS hits",
        'from' => 'squid_access_report',
        'where' => "event = 'accepted'",
        'group' => "main_code"
    }, { 'key' => 'main_code' });

    my $newtraffic;
    for my $fk (keys(%{$traffic})) {
        for my $sk (keys(%{$traffic->{$fk}})) {
            if(!defined($newtraffic->{$sk})) {
                $newtraffic->{$sk} = {};
            }
            $newtraffic->{$sk}->{$fk} = $traffic->{$fk}->{$sk};
        }
    }

    $report->{'summarized_traffic'} = $newtraffic;

    $report->{'top_domains'} = $self->runQuery($beg, $end, {
        'select' => 'domain, COALESCE(hit_bytes,0) AS hit_bytes, ' .
                    'COALESCE(miss_bytes,0) AS miss_bytes, ' .
                    'COALESCE(hit_bytes,0) + COALESCE(miss_bytes,0) ' .
                    'AS traffic_bytes, ' .
                    'COALESCE (hit_hits,0) + COALESCE(miss_hits,0) AS hits',
        'from' =>
            "(SELECT domain, SUM(bytes) AS hit_bytes, SUM(hits) AS hit_hits " .
            "FROM squid_access_report WHERE code ~ 'HIT' AND _date_ " .
            "GROUP BY domain) AS h " .
            "FULL OUTER JOIN " .
            "(SELECT domain, SUM(bytes) AS miss_bytes, SUM(hits) AS miss_hits " .
            "FROM squid_access_report WHERE code ~ 'MISS' AND _date_ " .
            "GROUP BY domain) AS m " .
            "USING (domain)",
        'limit' => $options->{'max_top_domains'},
        'order' => 'traffic_bytes DESC',
        'options' => {
            'no_date_in_where' => 1
        }
    });

    $report->{'top_blocked_domains'} = $self->runQuery($beg, $end, {
        'select' => 'domain, SUM(hits) AS hits',
        'from' => 'squid_access_report',
        'where' => "event = 'denied' OR event = 'filtered'",
        'group' => 'domain',
        'limit' => $options->{'max_top_blocked_domains'},
        'order' => 'hits DESC'
    });

    $report->{'top_subnets'} = $self->runQuery($beg, $end, {
        'select' => 'subnet, COALESCE(hit_bytes,0) AS hit_bytes, ' .
                    'COALESCE(miss_bytes,0) AS miss_bytes, ' .
                    'COALESCE(hit_bytes,0) + COALESCE(miss_bytes,0) ' .
                    'AS traffic_bytes, ' .
                    'COALESCE (hit_hits,0) + COALESCE(miss_hits,0) AS hits',
        'from' =>
            "(SELECT network(inet(ip || '/24')) AS subnet, " .
            "SUM(bytes) AS hit_bytes, SUM(hits) AS hit_hits " .
            "FROM squid_access_report WHERE code ~ 'HIT' AND _date_ " .
            "GROUP BY subnet) AS h " .
            "FULL OUTER JOIN " .
            "(SELECT network(inet(ip || '/24')) AS subnet, " .
            "SUM(bytes) AS miss_bytes, SUM(hits) AS miss_hits " .
            "FROM squid_access_report WHERE code ~ 'MISS' AND _date_ " .
            "GROUP BY subnet) AS m " .
            "USING (subnet)",
        'limit' => $options->{'max_top_subnets'},
        'order' => 'traffic_bytes DESC',
        'options' => {
            'no_date_in_where' => 1
        }
    });

    $report->{'top_blocked_subnets'} = $self->runQuery($beg, $end, {
        'select' => "network(inet(ip || '/24')) AS subnet, SUM(hits) AS hits",
        'from' => 'squid_access_report',
        'where' => "event = 'denied' OR event = 'filtered'",
        'group' => 'subnet',
        'limit' => $options->{'max_top_blocked_subnets'},
        'order' => 'hits DESC'
    });

    $report->{'top_ips'} = $self->runQuery($beg, $end, {
        'select' => 'ip, COALESCE(hit_bytes,0) AS hit_bytes, ' .
                    'COALESCE(miss_bytes,0) AS miss_bytes, ' .
                    'COALESCE(hit_bytes,0) + COALESCE(miss_bytes,0) ' .
                    'AS traffic_bytes, ' .
                    'COALESCE (hit_hits,0) + COALESCE(miss_hits,0) AS hits',
        'from' =>
            "(SELECT ip, " .
            "SUM(bytes) AS hit_bytes, SUM(hits) AS hit_hits " .
            "FROM squid_access_report WHERE code ~ 'HIT' AND _date_ " .
            "GROUP BY ip) AS h " .
            "FULL OUTER JOIN " .
            "(SELECT ip, " .
            "SUM(bytes) AS miss_bytes, SUM(hits) AS miss_hits " .
            "FROM squid_access_report WHERE code ~ 'MISS' AND _date_ " .
            "GROUP BY ip) AS m " .
            "USING (ip)",
        'limit' => $options->{'max_top_ips'},
        'order' => 'traffic_bytes DESC',
        'options' => {
            'no_date_in_where' => 1
        }
    });

    $report->{'top_blocked_ips'} = $self->runQuery($beg, $end, {
        'select' => 'ip, SUM(hits) AS hits',
        'from' => 'squid_access_report',
        'where' => "event = 'denied' OR event = 'filtered'",
        'group' => 'ip',
        'limit' => $options->{'max_top_blocked_ips'},
        'order' => 'hits DESC'
    });

    $report->{'top_users'} = $self->runQuery($beg, $end, {
        'select' => 'username, SUM(bytes) AS traffic_bytes, SUM(hits) AS hits',
        'from' => 'squid_access_report',
        'where' => "event = 'accepted' AND username <> '-'",
        'group' => 'username',
        'limit' => $options->{'max_top_users'},
        'order' => 'traffic_bytes DESC'
    });

    $report->{'top_blocked_users'} = $self->runQuery($beg, $end, {
        'select' => 'username, SUM(hits) AS hits',
        'from' => 'squid_access_report',
        'where' => "(event = 'denied' OR event = 'filtered') AND username <> '-'",
        'group' => 'username',
        'limit' => $options->{'max_top_blocked_users'},
        'order' => 'hits DESC'
    });

    $report->{'top_domains_by_user'} = $self->runCompositeQuery($beg, $end,
    {
        'select' => 'username, SUM(bytes) AS bytes',
        'from' => 'squid_access_report',
        'where' => "event = 'accepted' AND username <> '-'",
        'group' => 'username',
        'limit' => $options->{'max_users_top_domains_by_user'},
        'order' => 'bytes DESC'
    },
    'username',
    {
        'select' => 'domain, SUM(bytes) AS traffic_bytes, SUM(hits) AS hits',
        'from' => 'squid_access_report',
        'where' => "event = 'accepted' AND username = '_username_'",
        'group' => 'domain',
        'limit' => $options->{'max_domains_top_domains_by_user'},
        'order' => 'traffic_bytes DESC'
    });

    return $report;
}

sub consolidateReportQueries
{
    return [
        {
            'target_table' => 'squid_access_report',
            'query' => {
                'select' => 'rfc931 AS username, remotehost AS ip, domain_from_url(url) AS domain, event, code, SUM(bytes) AS bytes, COUNT(event) AS hits',
                'from' => 'squid_access',
                'group' => 'username, ip, domain, event, code'
            }
        }
    ];
}

# LdapModule implementation
sub _ldapModImplementation
{
    return new EBox::Squid::LdapUserImplementation();
}

1;
