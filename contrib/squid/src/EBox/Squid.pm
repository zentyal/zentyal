# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Squid;

use base qw(
    EBox::Module::Kerberos
    EBox::FirewallObserver
    EBox::LogObserver
    EBox::NetworkObserver
);

use EBox::Service;
use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;

use EBox::Squid::Firewall;
use EBox::Squid::LogHelper;
use EBox::Squid::LdapUserImplementation;
use EBox::Squid::Types::ListArchive;

use EBox::DBEngineFactory;
use EBox::Dashboard::Value;
use EBox::Dashboard::Section;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::Sudo;
use EBox::Gettext;
use EBox::Util::Version;
use EBox;
use TryCatch::Lite;
use HTML::Mason;
use File::Basename;

use EBox::NetWrappers qw(to_network_with_mask);

use Net::LDAP;
use Net::Ping;
use Net::DNS;
use Net::NTP qw(get_ntp_response);
use Authen::Krb5::Easy qw{kinit_pwd kdestroy kerror};

# Module local conf stuff
use constant SQUID_CONF_FILE => '/etc/squid3/squid.conf';
use constant SQUID_PORT => '3128';

use constant DGDIR => '/etc/dansguardian';
use constant DGPORT => '3129';

use constant SQUID_EXTERNAL_CONF_FILE  => '/etc/squid3/squid-external.conf';
use constant SQUID_EXTERNAL_PORT => '3130';

use constant SQUIDCSSFILE => '/etc/squid3/errorpage.css';
use constant MAXDOMAINSIZ => 255;
use constant DGLISTSDIR => DGDIR . '/lists';
use constant DG_LOGROTATE_CONF => '/etc/logrotate.d/dansguardian';
use constant SQUID_LOGROTATE_CONF => '/etc/logrotate.d/squid3';
use constant CLAMD_SCANNER_CONF_FILE => DGDIR . '/contentscanners/clamdscan.conf';
use constant BLOCK_ADS_PROGRAM => '/usr/bin/adzapper.wrapper';
use constant BLOCK_ADS_EXEC_FILE => '/usr/bin/adzapper';
use constant ADZAPPER_CONF => '/etc/adzapper.conf';
use constant KEYTAB_FILE => '/etc/squid3/HTTP.keytab';
use constant SQUID3_DEFAULT_FILE => '/etc/default/squid3';
use constant CRONFILE => '/etc/cron.d/zentyal-squid';

use constant SQUID_ZCONF_FILE => '/etc/zentyal/squid.conf';
use constant AUTH_MODE_KEY    => 'auth_mode';
use constant AUTH_AD_ACL_TTL_KEY   => 'auth_ad_acl_ttl';
use constant AUTH_AD_NEGATIVE_ACL_TTL_KEY   => 'auth_ad_negative_acl_ttl';
use constant AUTH_MODE_INTERNAL    => 'internal';
use constant AUTH_MODE_EXTERNAL_AD => 'external_ad';

sub _create
{
    my $class = shift;
    my $self  = $class->SUPER::_create(name => 'squid',
                                       printableName => __('HTTP Proxy'),
                                       @_);
    $self->{logger} = EBox::logger();
    bless ($self, $class);
    return $self;
}

sub _kerberosServicePrincipals
{
    return [ 'HTTP' ];
}

sub _kerberosKeytab
{
    return {
        path => KEYTAB_FILE,
        user => 'root',
        group => 'proxy',
        mode => '440',
    };
}

sub _externalServiceKerberosKeytab
{
    my ($self) = @_;
    my $keytab = $self->_kerberosKeytab();
    $keytab->{service} = 'http';
    $keytab->{principals} = $self->_kerberosServicePrincipals();
    $keytab->{module} = $self->name();
    return $keytab;
}

# Method: _kerberosSetup
#
#   Override to skip setup if authentication mode is not internal
#
sub _kerberosSetup
{
    my $self = shift;

    if ($self->authenticationMode() eq AUTH_MODE_INTERNAL) {
        $self->SUPER::_kerberosSetup(@_);
    }
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    $self->SUPER::initialSetup($version);

    unless ($version) {
        # Create default rules only if installing the first time
        # Allow clients to browse Internet by default
        $self->model('AccessRules')->add(source => { any => undef },
                                         policy => { allow => undef });
    }

    foreach my $name ('squid', 'logs') {
        my $mod = $self->global()->modInstance($name);
        if ($mod and $mod->changed()) {
            $mod->saveConfigRecursive();
        }
    }
}

# Method: usedFiles
#
#       Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    return [
            {
             'file' => SQUID_CONF_FILE,
             'module' => 'squid',
             'reason' => __('Front HTTP Proxy configuration file')
            },
            {
             'file' => SQUID_EXTERNAL_CONF_FILE,
             'module' => 'squid',
             'reason' => __('Back HTTP Proxy configuration file')
            },
            {
             'file' => SQUID_LOGROTATE_CONF,
             'module' => 'squid',
             'reason' => __(q{Squid's log rotation configuration}),
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
            {
             'file' =>    ADZAPPER_CONF,
             'module' => 'squid',
             'reason' => __('Configuration of adzapper'),
            },
            {
             'file' => SQUID3_DEFAULT_FILE,
             'module' => 'squid',
             'reason' => __('Set the kerberos keytab path'),
            },
            {
             'file' => KEYTAB_FILE,
             'module' => 'squid',
             'reason' => __('Extract the service principal key'),
            }
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
            },
            {
             'action' => __('Override squid upstart job'),
             'reason' => __('Zentyal will take care of starting and stopping ' .
                            'the services.'),
             'module' => 'squid'
            },
            {
             'action' => __('Remove dansguardian init script link'),
             'reason' => __('Zentyal will take care of starting and stopping ' .
                            'the services.'),
             'module' => 'squid'
            }
           ];
}

sub enableService
{
    my ($self, $status) = @_;
    if ($status) {
        my @ifaces = @{ $self->global()->modInstance('network')->ExternalIfaces() };
        if (not @ifaces) {
            throw EBox::Exceptions::External(
                __('To enable the HTTP proxy module, you need to have a least one external network interface')
            );
        }
    }
    $self->SUPER::enableService($status);
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

    return $self->model('GeneralSettings')->value('transparentProxy');
}

# # Method: https
# #
# #       Returns if the https mode is enabled
# #
# # Returns:
# #
# #       boolean - true if enabled, otherwise undef
# #
# sub https
# {
#     my ($self) = @_;

#     return $self->model('GeneralSettings')->value('https');
# }

# Method: setPort
#
#       Sets the listening port for the proxy
#
# Parameters:
#
#       port - string: port number
#
sub setPort
{
    my ($self, $port) = @_;

    $self->model('GeneralSettings')->setValue('port', $port);
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

    my $port = $self->model('GeneralSettings')->value('port');

    unless (defined($port) and ($port =~ /^\d+$/)) {
        return SQUID_PORT;
    }

    return $port;
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

# Method: getAdBlockPostMatch
#
#     Get the file with the ad-blocking post match
#
# Returns:
#
#     String - the ad-block file path postmatch
#
sub getAdBlockPostMatch
{
    my ($self) = @_;

    my $adBlockPostMatch = $self->get_string('ad_block_post_match');
    defined $adBlockPostMatch or
        $adBlockPostMatch = '';
    return $adBlockPostMatch;
}

# Method: setAdBlockPostMatch
#
#     Set the file with the ad-blocking post match
#
# Parameters:
#
#     file - String the ad-block file path postmatch
#
sub setAdBlockPostMatch
{
    my ($self, $file) = @_;

    $self->set_string('ad_block_post_match', $file);
}

# Method: setAdBlockExecFile
#
#     Set the adblocker exec file
#
# Parameters:
#
#     file - String the ad-block exec file
#
sub setAdBlockExecFile
{
    my ($self, $file) = @_;

    if ($file) {
        EBox::Sudo::root("cp -f $file " . BLOCK_ADS_EXEC_FILE);
    }
}

sub filterNeeded
{
    my ($self) = @_;
    unless ($self->isEnabled()) {
        return 0;
    }

    my $rules = $self->model('AccessRules');
    if ($rules->rulesUseFilter()) {
        return 1;
    }

    return 0;
}

sub authNeeded
{
    my ($self) = @_;

    unless ($self->isEnabled()) {
        return 0;
    }

    my $rules = $self->model('AccessRules');
    return $rules->rulesUseAuth();
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;

    ($protocol eq 'tcp') or return undef;

    # DGPORT and SQUID_EXTERNAL_PORT are hard-coded, they are reported as used even
    # if the services are disabled.
    ($port eq DGPORT) and return 1;
    ($port eq SQUID_EXTERNAL_PORT) and return 1;

    # the port selected by the user (by default SQUID_PORT) is only reported
    # if the service is enabled
    ($self->isEnabled()) or return undef;
    ($port eq $self->port()) and return 1;

    return undef;
}

sub _configureAuthenticationMode
{
    my ($self) = @_;

    my $mode = $self->authenticationMode();
    if ($mode eq AUTH_MODE_EXTERNAL_AD) {
        my $ad = $self->global()->modInstance('samba')->ldap();
        $ad->initKeyTabs();
    }
}

sub _setConf
{
    my ($self) = @_;

    my $filter = $self->filterNeeded();

    $self->_configureAuthenticationMode();
    $self->_writeDefaultConf();
    $self->_writeSquidConf($filter);
    $self->_writeSquidExternalConf();
    $self->writeConfFile(SQUIDCSSFILE, 'squid/errorpage.css', []);

    if ($filter) {
        $self->_writeDgConf();
    }

    EBox::Squid::Types::ListArchive->commitAllPendingRemovals();
}

sub revokeConfig
{
   my ($self) = @_;
   $self->SUPER::revokeConfig();
   EBox::Squid::Types::ListArchive->revokeAllPendingRemovals();
}

sub _antivirusNeeded
{
    my ($self, $profiles_r) = @_;

    my $global = $self->global();
    return 0 unless $global->modExists('antivirus');
    return 0 unless $global->modInstance('antivirus')->isEnabled();

    if (not $profiles_r) {
        my $profiles = $self->model('FilterProfiles');
        return $profiles->antivirusNeeded();
    }

    foreach my $profile (@{ $profiles_r }) {
        if ($profile->{antivirus}) {
            return 1;
        }
    }

    return 0;
}

sub notifyAntivirusEnabled
{
    my ($self, $enabled) = @_;
    $self->filterNeeded() or
        return;

    $self->setAsChanged();
}

sub _writeDefaultConf
{
    my ($self) = @_;

    my $vars = [];
    push (@{$vars}, 'keytab' => KEYTAB_FILE);
    $self->writeConfFile(SQUID3_DEFAULT_FILE,
        'squid/squid.default.mas', $vars,
        { mode => '0644'});
}

sub _writeSquidConf
{
    my ($self, $filter) = @_;

    my $accesRulesModel =  $self->model('AccessRules');
    my $rules = $accesRulesModel->rules();
    my $squidFilterProfiles = $accesRulesModel->squidFilterProfiles();

    my $generalSettings = $self->model('GeneralSettings');
    my $kerberos = $generalSettings->kerberosValue();

    my $global  = $self->global();
    my $sysinfo = $global->modInstance('sysinfo');
    my $users = $global->modInstance('samba');
    my $krbRealm = $kerberos ? $users->kerberosRealm() : '';
    my $krbPrincipal = 'HTTP/' . $sysinfo->hostName() . '.' . $sysinfo->hostDomain();

    my @writeParam = ();
    push @writeParam, ('filter' => $filter);
    push @writeParam, ('port'  => $self->port());
    push @writeParam, ('transparent'  => $self->transproxy());

    push @writeParam, ('rules' => $rules);
    push @writeParam, ('filterProfiles' => $squidFilterProfiles);

    push @writeParam, ('hostfqdn' => $sysinfo->fqdn());
    push @writeParam, ('auth' => $self->authNeeded());
    push @writeParam, ('principal' => $krbPrincipal);
    push @writeParam, ('realm'     => $krbRealm);
    push @writeParam, ('noAuthDomains' => $self->_noAuthDomains());


    my $ldap = $users->ldap();
    my $mode = $self->authenticationMode();
    if ($mode eq AUTH_MODE_INTERNAL) {
        push @writeParam, ('dn'       => $ldap->dn());
        push @writeParam, ('roDn'     => $self->_kerberosServiceAccountDN());
        push @writeParam, ('roPasswd' => $self->_kerberosServiceAccountPassword());        
    }  elsif ($mode eq AUTH_MODE_EXTERNAL_AD) {
        my $dc = $ldap->dcHostname();
        my $adAclTtl = EBox::Config::configkeyFromFile(AUTH_AD_ACL_TTL_KEY,
            SQUID_ZCONF_FILE);
        my $adNegativeAclTtl =
            EBox::Config::configkeyFromFile(
                AUTH_AD_NEGATIVE_ACL_TTL_KEY, SQUID_ZCONF_FILE);
        my $adPrincipal = $ldap->hostSamAccountName();

        push (@writeParam, (authModeExternalAD => 1));
        push (@writeParam, (adDC        => $dc));
        push (@writeParam, (adAclTTL    => $adAclTtl));
        push (@writeParam, (adNegativeAclTTL => $adNegativeAclTtl));
        push (@writeParam, (adPrincipal => $adPrincipal));
    } else {
        throw EBox::Exceptions::Internal("Invalid authentication mode: $mode");
    }

    $self->writeConfFile(SQUID_CONF_FILE, 'squid/squid.conf.mas', \@writeParam, { mode => '0640'});
    if (EBox::Config::boolean('debug')) {
        $self->_checkSquidFile(SQUID_CONF_FILE);
    }

    $self->writeConfFile(SQUID_LOGROTATE_CONF, 'squid/squid3.logrotate.mas', []);
}

sub _writeSquidExternalConf
{
    my ($self) = @_;

    my $globalRO = EBox::Global->getInstance(1);
    my $global  = $self->global();
    my $network = $global->modInstance('network');
    my $users   = $global->modInstance('samba');
    my $sysinfo = $global->modInstance('sysinfo');
    my $generalSettings = $self->model('GeneralSettings');

    my $writeParam = [];

    my @ifaces = @{ $network->ExternalIfaces() };
    my @listenAddr = map {
        my @addrs = map {
            ($_->{address})
        } @{ $network->ifaceAddresses($_) };
        @addrs;
    } @ifaces;
     
    if (not @listenAddr) {
        throw EBox::Exceptions::Internal("No external interfaces addresses to listen found");
    }
    push @{$writeParam}, listenAddr => \@listenAddr;

    push (@{$writeParam}, port => SQUID_EXTERNAL_PORT);
    push (@{$writeParam}, hostfqdn => $sysinfo->fqdn());

    if ($generalSettings->kerberosValue()) {
        push (@{$writeParam}, realm => $users->kerberosRealm);
    }

    if ($generalSettings->removeAdsValue()) {
        push (@{$writeParam}, urlRewriteProgram => BLOCK_ADS_PROGRAM);
        my @adsParams = ();
        push (@adsParams, postMatch => $self->getAdBlockPostMatch());
        $self->writeConfFile(ADZAPPER_CONF, 'squid/adzapper.conf.mas', \@adsParams);
    }

    my $append_domain = $network->model('SearchDomain')->domainValue();
    push (@{$writeParam}, append_domain => $append_domain);

    push (@{$writeParam}, memory => $self->_cache_mem());
    push (@{$writeParam}, max_object_size => $self->_max_object_size());

    my $cacheDirSize = $generalSettings->cacheDirSizeValue();
    push (@{$writeParam}, cacheDirSize => $cacheDirSize);
    push (@{$writeParam}, nameservers => $network->nameservers());

    my $cache_host   = $network->model('Proxy')->serverValue();
    my $cache_port   = $network->model('Proxy')->portValue();
    my $cache_user   = $network->model('Proxy')->usernameValue();
    my $cache_passwd = $network->model('Proxy')->passwordValue();
    push (@{$writeParam}, cache_host   => $cache_host);
    push (@{$writeParam}, cache_port   => $cache_port);
    push (@{$writeParam}, cache_user   => $cache_user);
    push (@{$writeParam}, cache_passwd => $cache_passwd);

    push (@{$writeParam}, notCachedDomains => $self->_notCachedDomains());
    push (@{$writeParam}, objectsDelayPools => $self->_objectsDelayPools());

    $self->writeConfFile(SQUID_EXTERNAL_CONF_FILE, 'squid/squid-external.conf.mas',
                         $writeParam, { mode => '0640'});
    if (EBox::Config::boolean('debug')) {
        $self->_checkSquidFile(SQUID_EXTERNAL_CONF_FILE);
    }
}

sub _checkSquidFile
{
    my ($self, $confFile) = @_;

    try {
        EBox::Sudo::root("squid3 -k parse $confFile");
    } catch (EBox::Exceptions::Command $e) {
        my $error = join ' ', @{ $e->error() };
        throw EBox::Exceptions::Internal("Error in squid configuration file $confFile: $error");
    }
}

sub _objectsDelayPools
{
    my ($self) = @_;

    my @delayPools = @{$self->model('DelayPools')->delayPools()};
    return \@delayPools;
}

sub _writeDgConf
{
    my ($self) = @_;

    # FIXME - get a proper lang name for the current locale
    my $lang = $self->_DGLang();

    my @dgProfiles = @{ $self->_dgProfiles };

    my @writeParam = ();

    push(@writeParam, 'port' => DGPORT);
    push(@writeParam, 'lang' => $lang);
    push(@writeParam, 'squidport' => SQUID_EXTERNAL_PORT);
    push(@writeParam, 'weightedPhraseThreshold' => $self->_banThresholdActive);
    push(@writeParam, 'nGroups' => scalar @dgProfiles);

    my $antivirus = $self->_antivirusNeeded(\@dgProfiles);
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
            'squid/dansguardian.conf.mas', \@writeParam, { mode => '0644'});

    # disable banned, exception phrases lists, regex URLs and PICS ratings
    $self->writeConfFile(DGLISTSDIR . '/bannedphraselist',
                         'squid/bannedphraselist.mas', [], { mode => '0644'});

    $self->writeConfFile(DGLISTSDIR . '/exceptionphraselist',
                         'squid/exceptionphraselist.mas', [], { mode => '0644'});

    $self->writeConfFile(DGLISTSDIR . '/pics',
                         'squid/pics.mas', [], { mode => '0644'});

    $self->writeConfFile(DGLISTSDIR . '/bannedregexpurllist',
                         'squid/bannedregexpurllist.mas', [],  { mode => '0644'});

    $self->writeDgGroups();

    if ($antivirus) {
        my $avMod = $self->global()->modInstance('antivirus');
        $self->writeConfFile(CLAMD_SCANNER_CONF_FILE,
                             'squid/clamdscan.conf.mas',
                             [ clamdSocket => $avMod->localSocket() ]);
    }

    foreach my $group (@dgProfiles) {
        my $number = $group->{number};
        my $policy = $group->{policy};

        @writeParam = ();

        push(@writeParam, 'group' => $number);
        push(@writeParam, 'policy' => $policy);
        push(@writeParam, 'antivirus' => $group->{antivirus});
        push(@writeParam, 'threshold' => $group->{threshold});
        push(@writeParam, 'groupName' => $group->{groupName});
        push(@writeParam, 'defaults' => $group->{defaults});
        EBox::Module::Base::writeConfFileNoCheck(DGDIR . "/dansguardianf$number.conf",
                'squid/dansguardianfN.conf.mas', \@writeParam, { mode => '0644'});

        if ($policy eq 'filter') {
             $self->_writeDgDomainsConf($group);
        }
    }

    $self->_writeCronFile();
    $self->_writeDgTemplates();
    $self->writeConfFile(DG_LOGROTATE_CONF, 'squid/dansguardian.logrotate', []);
}

sub _writeCronFile
{
    my ($self) = @_;

    my $times;
    my @cronTimes;

    my $usingExternalAD = ($self->authenticationMode() eq $self->AUTH_MODE_EXTERNAL_AD());
    my $usingExternalADGroups = 0;

    my $rules = $self->model('AccessRules');
    foreach my $profile (@{$rules->filterProfiles()}) {
        if ($usingExternalAD and exists($profile->{users})) {
            $usingExternalADGroups = 1;
        }
        next unless $profile->{usesFilter} and $profile->{timePeriod};
        if ($profile->{policy} eq 'deny') {
            # this is managed in squid, we don't need to rewrite DG files for it
            next;
        }
        foreach my $day (keys %{$profile->{days}}) {
            my @times;
            # if the profile only has days, we change it at new day (00:00)
            push @times, $profile->{begin} ? $profile->{begin} : '00:00';
            if ($profile->{end}) {
                push @times, $profile->{end};
            }
            foreach my $time (@times) {
                unless (exists $times->{$time}) {
                    $times->{$time} = {};
                }
                $times->{$time}->{$day} = 1;
            }
        }
    }

    foreach my $time (keys %{$times}) {
        my ($hour, $min) = split (':', $time);
        my $days = join (',', sort (keys %{$times->{$time}}));
        push (@cronTimes, { days => $days, hour => $hour, min => $min });
    }

    # Synchronise AD groups every 30min
    if ($usingExternalADGroups) {
        push(@cronTimes, { days => '*', hour => '*', min => '*/30' });
    }

    $self->writeConfFile(CRONFILE, 'squid/zentyal-squid.cron.mas', [ times => \@cronTimes ]);
}

sub writeDgGroups
{
    my ($self) = @_;

    my $rules = $self->model('AccessRules');
    my @profiles = @{$rules->filterProfiles()};
    my @groups;
    my @objects;
    my $anyAddressProfileSeen;

    my (undef, $min, $hour, undef, undef, undef, $day) = localtime();

    foreach my $profile (@profiles) {
        if ($profile->{policy} eq 'deny') {
            # this is stopped in squid, nothing to do
            next;
        }
        if ($profile->{timePeriod}) {
            unless ($profile->{days}->{$day}) {
                next;
            }
            if ($profile->{begin}) {
                my ($beginHour, $beginMin) = split (':', $profile->{begin});
                if ($hour < $beginHour) {
                    next;
                } elsif (($hour == $beginHour) and ($min < $beginMin)) {
                    next;
                }
            }

            if ($profile->{end}) {
                my ($endHour, $endMin) = split (':', $profile->{end});
                if ($hour > $endHour) {
                    next;
                } elsif (($hour == $endHour) and ($min > $endMin)) {
                    next;
                }
            }

        }
        if ($profile->{anyAddress}) {
            if ($anyAddressProfileSeen) {
                next;
            }
            $anyAddressProfileSeen  = 1;
            push @objects, $profile;
        }  elsif ($profile->{group}) {
            push (@groups, $profile);
        } else {
            push (@objects, $profile);
        }
    }

    my $generalSettings = $self->model('GeneralSettings');
    my $realm = '';
    if ($generalSettings->kerberosValue()) {
        my $users = $self->global()->modInstance('samba');
        $realm = '@' . $users->kerberosRealm();
    }

    my @writeParams = ();
    push (@writeParams, groups => \@groups);
    push (@writeParams, realm => $realm);
    $self->writeConfFile(DGLISTSDIR . '/filtergroupslist',
                         'squid/filtergroupslist.mas',
                         \@writeParams, { mode => '0644'});

    $self->writeConfFile(DGLISTSDIR . '/authplugins/ipgroups',
                         'squid/ipgroups.mas',
                         [ objects => \@objects ], { mode => '0644'});
}

# FIXME: template format has changed, reimplement this
sub _writeDgTemplates
{
    my ($self) = @_;

    my $lang = $self->_DGLang();
    my $file = DGDIR . '/languages/' . $lang . '/template.html';

    my $extra_messages = '';
    my $edition = $self->global()->edition();

    if (($edition eq 'community') or ($edition eq 'basic')) {
        $extra_messages = __sx('This is a Community Edition. Get one of the fully supported {oh}Commercial Editions{ch} for automatic security updates.',
                               oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
    }

    EBox::Module::Base::writeConfFileNoCheck($file,
                                             'squid/template.html.mas',
                                             [
                                                extra_messages => $extra_messages,
                                                image_name => "zentyal-$edition.png",
                                             ]);
}

sub _banThresholdActive
{
    my ($self) = @_;

    my @dgProfiles = @{ $self->_dgProfiles };
    foreach my $group (@dgProfiles) {
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
sub _noAuthDomains
{
    my ($self) = @_;

    my $model = $self->model('NoAuthDomains');
    return $model->noAuthDomains();
}

sub _dgProfiles
{
    my ($self) = @_;

    my $profileModel = $self->model('FilterProfiles');
    return $profileModel->dgProfiles();
}

sub _writeDgDomainsConf
{
    my ($self, $group) = @_;

    my $number = $group->{number};

    my @domainsFiles = ('bannedsitelist',
                        'exceptionsitelist', 'exceptionurllist');

    foreach my $file (@domainsFiles) {
        next if (exists $group->{defaults}->{$file});

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
    my $ro = $self->isReadOnly();

    if ($self->isEnabled()) {
        return new EBox::Squid::Firewall(ro => $ro);
    }

    return undef;
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
                                        'icon' => 'squid',
                                        'text' => $self->printableName(),
                                        'order' => 800);

    $folder->add(new EBox::Menu::Item('url' => 'Squid/Composite/General',
                                      'text' => __('General Settings')));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/AccessRules',
                                      'text' => __(q{Access Rules})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/FilterProfiles',
                                      'text' => __(q{Filter Profiles})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/CategorizedLists',
                                      'text' => __(q{Categorized Lists})));

    $folder->add(new EBox::Menu::Item('url' => 'Squid/View/DelayPools',
                                      'text' => __(q{Bandwidth Throttling})));

    $root->add($folder);
}

#  Method: _daemons
#
#   Overrides <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            name => 'zentyal.squid3-external'
        },
        {
            name => 'ebox.dansguardian',
            precondition => \&filterNeeded
        },
        {
            name => 'squid3'
        }
    ];
}

#  Method: _daemonsToDisable
#
#   Overrides <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    # XXX: although squid3 is already listed in _daemons, we add it also here
    #      to force its stop during enabled (it was done in the initial-setup script)
    #      maybe we can double check if that's really necessary
    return [
        { name => 'dansguardian', type => 'init.d' },
        { name => 'squid3', type => 'upstart' }
    ];
}

# Impelment LogHelper interface
sub tableInfo
{
    my ($self) = @_;

    my $titles = { 'timestamp'  => __('Date'),
                   'remotehost' => __('Host'),
                   'rfc931'     => __('User'),
                   'url'        => __('URL'),
                   'domain'     => __('Domain'),
                   'bytes'      => __('Bytes'),
                   'mimetype'   => __('Mime/type'),
                   'event'      => __('Event')
                 };
    my @order = ( 'timestamp', 'remotehost', 'rfc931', 'url', 'domain',
                  'bytes', 'mimetype', 'event');

    my $events = { 'accepted' => __('Accepted'),
                   'denied' => __('Denied'),
                   'filtered' => __('Filtered') };
    return [{
            'name' => __('HTTP Proxy'),
            'tablename' => 'squid_access',
            'titles' => $titles,
            'order' => \@order,
            'filter' => ['url', 'domain', 'remotehost', 'rfc931'],
            'events' => $events,
            'eventcol' => 'event',
           }];
}

sub logHelper
{
    my ($self) = @_;
    return (new EBox::Squid::LogHelper);
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

sub addPathsToRemove
{
    my ($self, $when, @files) = @_;
    my $key = 'paths_to_remove_on_' . $when;
    my $state = $self->get_state();
    my $toRemove = $state->{$when};
    $toRemove or $toRemove = [];

    push @{$toRemove }, @files;
    $state->{$key} = $toRemove;
    $self->set_state($state);
}

sub clearPathsToRemove
{
    my ($self, $when) = @_;
    my $key = 'paths_to_remove_on_' . $when;
    my $state = $self->get_state();
    delete $state->{$key};
    $self->set_state($state);
}

sub pathsToRemove
{
    my ($self, $when) = @_;
    my $key = 'paths_to_remove_on_' . $when;
    my $state = $self->get_state();
    my $toRemove = $state->{$key};
    $toRemove or $toRemove = [];
    return $toRemove;
}

sub aroundRestoreConfig
{
    my ($self, $dir, %options) = @_;
    my $categorizedLists =  $self->model('CategorizedLists');
    $categorizedLists->beforeRestoreConfig();
    $self->SUPER::aroundRestoreConfig($dir, %options);
    $categorizedLists->afterRestoreConfig();
}

# LdapModule implementation
sub _ldapModImplementation
{
    return new EBox::Squid::LdapUserImplementation();
}

# Method: regenGatewaysFailover
#
# Overrides:
#
#    <EBox::NetworkObserver::regenGatewaysFailover>
#
sub regenGatewaysFailover
{
    my ($self) = @_;

    $self->restartService();
}

# Security Updates Add-On message
sub _commercialMsg
{
    return __sx('Want to avoid threats such as malware, phishing and bots? Get one of the {oh}Commercial Editions{ch} that will keep your Content Filtering rules always up-to-date.',
                oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
}

sub authenticationMode
{
    my ($self) = @_;
    my $users = $self->global()->modInstance('samba');
    my $usersMode = $users->mode();
    if ($usersMode eq $users->STANDALONE_MODE) {
        return AUTH_MODE_INTERNAL;
    } elsif ($usersMode eq $users->EXTERNAL_AD_MODE) {
        return AUTH_MODE_EXTERNAL_AD;
    } else {
        EBox::warn("Unknown users mode: $usersMode. Falling back to squid internal authorization mode");
        return AUTH_MODE_INTERNAL;
    }
}

sub ifaceExternalChanged
{
    my ($self, $iface, $toExternal) = @_;
    if (not $self->_externalIfacesAfterChange($toExternal)) {
        return 1;
    }
    return 0;
}

sub ifaceMethodChanged
{
    my ($self, $iface, $old, $new) = @_;
    my $network = $self->global()->modInstance('network');
    if (not $network->ifaceIsExternal($iface)) {
        return 0;
    }

    my $noExternalMethod = 0;
    my @noExternalMethods = qw(notset trunk);
    foreach my $method (@noExternalMethods) {
        if ($method eq $old) {
            return 0;
        }
        if ($method eq $new) {
            $noExternalMethod = 1;
        }
    }

    if (not $noExternalMethod) {
        return 0;
    }
        
    if (not $self->_externalIfacesAfterChange(0)) {
        return 1;
    }

    return 0;

}

sub changeIfaceExternalProperty
{
    my ($self, $iface, $toExternal) = @_;
    $self->_ifaceChangeDone($iface, $toExternal);
}

sub freeIface
{
    my ($self, $iface, $toExternal) = @_;
    
    my $ifaceExternal = $self->global()->modInstance('network')->ifaceIsExternal($iface);
    if ($ifaceExternal) {
        $self->_ifaceChangeDone($iface, 0);
    }
}

sub _externalIfacesAfterChange
{
    my ($self, $toExternal) = @_;
    if (not $self->isEnabled()) {
        # we do not care, external interfaces are check when enabling the module
        return 1;
    }
    if ($toExternal) {
        return 1;
    }
    my $network = $self->global()->modInstance('network');
    my $nExternal = @{ $network->ExternalIfaces() };
    # simulate changed
    $nExternal -= 1 ;
    return ($nExternal > 0)
}

sub _ifaceChangeDone
{
    my ($self, $iface, $toExternal) = @_;
    if (not $self->_externalIfacesAfterChange($toExternal)) {
        EBox::warn("Disabling HTTP proxy because $iface is not longer external and there are not interfaces left");
        $self->enableService(0);
    }
}

1;
