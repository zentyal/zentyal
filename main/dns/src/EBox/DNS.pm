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
use strict;
use warnings;

package EBox::DNS;

use base qw( EBox::Module::Service
             EBox::FirewallObserver
             EBox::SysInfo::Observer
             EBox::NetworkObserver );

use EBox::Objects;
use EBox::Gettext;
use EBox::Config;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Sudo;
use EBox::Validate qw( :all );
use EBox::DNS::Model::DomainTable;
use EBox::DNS::Model::HostnameTable;
use EBox::DNS::Model::AliasTable;
use EBox::Model::Manager;
use EBox::Sudo;
use EBox::DNS::FirewallHelper;
use EBox::NetWrappers;

use EBox::Exceptions::Sudo::Command;
use EBox::Exceptions::UnwillingToPerform;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;

use TryCatch::Lite;
use File::Temp;
use File::Slurp;
use Fcntl qw(:seek);
use IO::Socket::INET;
use Net::IP;
use Perl6::Junction qw(any);
use Tie::File;

use constant BIND9DEFAULTFILE     => "/etc/default/bind9";
use constant BIND9CONFDIR         => "/etc/bind";
use constant BIND9CONFFILE        => "/etc/bind/named.conf";
use constant BIND9CONFOPTIONSFILE => "/etc/bind/named.conf.options";
use constant BIND9CONFLOCALFILE   => "/etc/bind/named.conf.local";
use constant BIND9_UPDATE_ZONES   => "/var/lib/bind";

use constant PIDFILE       => "/var/run/bind/run/named.pid";
use constant KEYSFILE => BIND9CONFDIR . '/keys';

use constant DNS_CONF_FILE => EBox::Config::etc() . 'dns.conf';
use constant DNS_INTNETS => 'intnets';
use constant NS_UPDATE_CMD => 'nsupdate';
use constant DELETED_RR_KEY => 'deleted_rr';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'dns',
                                      printableName => 'DNS',
                                      @_);

    bless ($self, $class);
    return $self;
}

# Method: appArmorProfiles
#
#   Overrides to set the own AppArmor profile
#
# Overrides:
#
#   <EBox::Module::Base::appArmorProfiles>
#
sub appArmorProfiles
{
    my ($self) = @_;

    EBox::info('Setting DNS apparmor profile');
    my @params = ();
    return [
            {
                'binary' => 'usr.sbin.named',
                'local'  => 1,
                'file'   => 'dns/apparmor-named.local.mas',
                'params' => \@params,
            },
            {
                'binary' => 'usr.sbin.mysqld',
                'local'  => 1,
                'file'   => 'dns/apparmor-mysqld.local.mas',
                'params' => \@params,
            }
    ];
}

# Method: addDomain
#
#  Add new domain to table model
#
# Parameters:
#
#  Check <EBox::DNS::Model::DomainTable> for details
#
# Returns:
#
#  String - the identifier for the domain
#
sub addDomain
{
    my ($self, $domainData) = @_;

    my $domainModel = $self->model('DomainTable');

    return $domainModel->addDomain($domainData);
}

# Method: addService
#
#   Add a new SRV record to the domain
#
# Parameters:
#
#   Check <EBox::DNS::Model::DomainTable> for details
#
sub addService
{
    my ($self, $domain, $service) = @_;

    my $model = $self->model('DomainTable');

    $model->addService($domain, $service);
}

# Method: delService
#
#   Deletes a SRV record from the domain
#
# Parameters:
#
#   Check <EBox::DNS::Model::DomainTable> for details
#
sub delService
{
    my ($self, $domain, $service) = @_;

    my $model = $self->model('DomainTable');

    $model->delService($domain, $service);
}

# Method: addText
#
#   Add a new TXT record to the domain
#
# Parameters:
#
#   Check <EBox::DNS::Model::DomainTable> for details
#
sub addText
{
    my ($self, $domain, $txt) = @_;

    my $model = $self->model('DomainTable');

    $model->addText($domain, $txt);
}

# Method: delText
#
#   Deletes a TXT record from the domain
#
# Parameters:
#
#   Check <EBox::DNS::Model::DomainTable> for details
#
sub delText
{
    my ($self, $domain, $txt) = @_;

    my $model = $self->model('DomainTable');

    $model->delText($domain, $txt);
}

# Method: addHost
#
#   Adds a host to the domain
#
# Parameters:
#
#   Check <EBox::DNS::Model::DomainTable> for details
#
sub addHost
{
    my ($self, $domain, $host) = @_;

    my $model = $self->model('DomainTable');

    $model->addHost($domain, $host);
}

# Method: delHost
#
#   Deletes a host from the domain
#
# Parameters:
#
#   Check <EBox::DNS::Model::DomainTable> for details
#
sub delHost
{
    my ($self, $domain, $host) = @_;

    my $model = $self->model('DomainTable');

    $model->delHost($domain, $host);
}

# Method: domains
#
#   Returns an array with all domain names
#
# Returns:
#
#   Array ref - containing hash refs with the following elements:
#       name - String the domain's name
#       dynamic - boolean indicating if the domain is dynamic
#       managed - boolean indicating if the domain is managed by zentyal
#
sub domains
{
    my $self = shift;

    my $array = [];
    my $model = $self->model('DomainTable');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $domaindata = {
            name  => $row->valueByName('domain'),
            dynamic => $row->valueByName('dynamic'),
            samba => $row->valueByName('samba'),
            managed => $row->valueByName('managed')
        };
        push @{$array}, $domaindata;
    }

    return $array;
}

# Method: getHostnames
#
#   Given a domain name, it returns an array ref of hostnames that
#   it contains.
#
# Parameters:
#
#   domain - String the domain's name
#
# Returns:
#
#   array ref - containing the same structure as
#               <EBox::DNS::hostnames> returns
#
sub getHostnames
{

    my ($self, $domain) = @_;

    unless (defined $domain) {
        throw EBox::Exceptions::MissingArgument('domain');
    }

    my $domainRow = $self->model('DomainTable')->findRow(domain => $domain);
    unless (defined $domainRow) {
        throw EBox::Exceptions::DataNotFound(data  => __('domain'),
                                             value => $domain);
    }

    return $self->_hostnames($domainRow->subModel('hostnames'));
}

# Method: aliases
#
#   Returns an array with all alias structure of a hostname
#
# Parameters:
#
#   model - Model to iterate over
#
# Returns:
#
#  array ref with this structure data:
#      name - alias name
#
sub aliases
{
    my ($self, $model) = @_;

    my $array = [];
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push @{$array}, $row->valueByName('alias');
    }

    return $array;
}

# Method: hostIpAddresses
#
#   Returns an array with all IP of a hostname
#
# Parameters:
#
#   model - Model to iterate over
#
# Returns:
#
#  array ref with this structure data:
#      ip - Ip address
#
sub hostIpAddresses
{
    my ($self, $model) = @_;

    my $array = [];
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push @{$array}, $row->valueByName('ip');
    }

    return $array;
}

# Method: getServices
#
#   Given a domain name, it returns an array ref of SRV records that
#   it contains.
#
# Parameters:
#
#   domain - String the domain's name
#
# Returns:
#
#   array ref - containing the same structure as
#               <EBox::DNS::_services> returns
#
sub getServices
{

    my ($self, $domain) = @_;

    my $domainRow = $self->model('DomainTable')->findRow(domain => $domain);
    unless (defined $domainRow) {
        throw EBox::Exceptions::DataNotFound(data  => __('domain'),
                                             value => $domain);
    }

    my $model = $domainRow->subModel('srv');
    return $self->_serviceRecords($model);
}

# Method: getTexts
#
#   Given a domain name, it returns an array ref of TXT records that
#   it contains.
#
# Parameters:
#
#   domain - String the domain's name
#
# Returns:
#
#   array ref - containing the same structure as
#               <EBox::DNS::_texts> returns
#
sub getTexts
{
    my ($self, $domain) = @_;

    my $domainRow = $self->model('DomainTable')->findRow(domain => $domain);
    unless (defined $domainRow) {
        throw EBox::Exceptions::DataNotFound(data  => __('domain'),
                                             value => $domain);
    }

    return $self->_textRecords($domainRow->subModel('txt'));
}

# Method: getTsigKeys
#
#   Returns the TSIG keys for the configured domains
#
sub getTsigKeys
{
    my ($self) = @_;

    my $keys = {};
    my $model = $self->model('DomainTable');
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $keyName = $row->valueByName('domain');
        my $keySecret = $row->valueByName('tsigKey');
        $keys->{$keyName} = $keySecret;
    }
    return $keys;
}

# Method: findAlias
#
#       Return the hostname which the alias refers to given a domain
#
# Parameters:
#
#       domainName - String the domain name
#       alias - String the alias name
#
# Returns:
#
#       String - the hostname which the alias refers to
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#       argument is missing
#
#       <EBox::Exceptions::DataNotFound> - thrown if the domain does
#       not exist or the alias does not exist
#
sub findAlias
{
    my ($self, $domainName, $alias) = @_;

    $domainName or throw EBox::Exceptions::MissingArgument('domainName');
    $alias or throw EBox::Exceptions::MissingArgument('alias');

    my $domModel = $self->model('DomainTable');
    $domModel->{cachedVersion} = 0;
    my $id = $domModel->find(domain => $domainName);
    unless (defined ($id)) {
        throw EBox::Exceptions::DataNotFound(data => 'domain',
                                             value => $domainName);
    }
    my $row = $domModel->row($id);
    foreach my $ids (@{$row->subModel('hostnames')->ids()}) {
        my $hostnameRow = $row->subModel('hostnames')->row($id);
        for my $aliasId (@{$hostnameRow->subModel('alias')->ids()}) {
            my $aliasRow = hostnameRow->subModel('alias')->row($aliasId);
            if ($alias eq $aliasRow->valueByName('alias')) {
                return $hostnameRow->valueByName('hostname');
            }
        }
    }

    throw EBox::Exceptions::DataNotFound(data  => 'alias',
                                         value => $alias);
}

# Method: NameserverHost
#
#   Return those host which is the nameserver for every domain.
#
# Returns:
#
#   String - the nameserver host name for every eBox defined domain
#
sub NameserverHost
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');

    return $sysinfo->hostName();
}

# Method: usedFiles
#
# Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
    my ($self) = @_;
    my $files = [
        {
            'file'   => BIND9DEFAULTFILE,
            'module' => 'dns',
            'reason' => __('Zentyal will set the required environment variables for bind9 daemon'),
        },
        {
            'file'   => BIND9CONFFILE,
            'module' => 'dns',
            'reason' => __('main bind9 configuration file'),
        },
        {
            'file'   => BIND9CONFOPTIONSFILE,
            'module' => 'dns',
            'reason' => __('bind9 options configuration file'),
        },
        {
            'file' => BIND9CONFLOCALFILE ,
            'module' => 'dns',
            'reason' => __('local bind9 configuration file'),
        },
        {
            'file'   => KEYSFILE,
            'module' => 'dns',
            'reason' => __('Keys configuration file'),
        },
    ];
}

# Method: actions
#
# Overrides:
#
#    <EBox::Module::Service::actions>
#
sub actions
{
    return [
        {
            'action' => __x('Change the permissions for {dir} to allow writing to bind group',
                            dir => BIND9CONFDIR),
            'reason' => __('Let the bind daemon to be dynamically updated'),
            'module' => 'dns'
        },
        {
            'action' => __('Remove bind9 init script link'),
            'reason' => __('Zentyal will take care of starting and stopping ' .
                        'the services.'),
            'module' => 'dns'
        },
        {
            'action' => __('Override named apparmor profile'),
            'reason' => __('To allow samba daemon load Active Directory zone'),
            'module' => 'dns',
        },

    ];
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'dns';
        unless ($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'printableName' => 'DNS',
                'description' => __('Domain Name Service'),
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setInternalService($serviceName, 'accept');
        $firewall->saveConfigRecursive();
    }

    # Execute initial-setup script to create SQL tables
    $self->SUPER::initialSetup($version);
}

sub _services
{
    my ($self) = @_;

    return [
             {
              'protocol' => 'udp',
              'sourcePort' => 'any',
              'destinationPort' => 53,
             },
             {
              'protocol' => 'tcp',
              'sourcePort' => 'any',
              'destinationPort' => 53,
             },
    ];
}

# Method: _daemons
#
#  Overrides <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'bind9',
            'type' => 'init.d'
        }
    ];
}

# Method: _daemonsToDisable
#
#  Overrides <EBox::Module::Service::_daemonsToDisable>
#
sub _daemonsToDisable
{
    return [
        {
            'name' => 'bind9',
            'type' => 'init.d'
        }
    ];
}

# Method: _preSetConf
#
#
sub _preSetConf
{
    my ($self) = @_;

    my $runResolvConf = 1;
    if ($self->global->modExists('samba')) {
        my $usersModule = $self->global->modInstance('samba');
    }
    my $array = [];
    push (@{$array}, runResolvConf => $runResolvConf);
    $self->writeConfFile(BIND9DEFAULTFILE, 'dns/bind9.mas', $array,
        {mode => '0644', uid => 0, gid => 0});
}

# Method: _setConf
#
# Overrides:
#
#  <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->_updateManagedDomainAddresses();

    my $keytabPath = undef;
    my $sambaZones = undef;
    if (EBox::Global->modExists('samba')) {
        my $sambaModule = EBox::Global->modInstance('samba');
        if ($sambaModule->isEnabled() and
            $sambaModule->getProvision->isProvisioned())
        {
            # Get the zones stored in the samba LDB
            my $ldap = $sambaModule->ldap();
            @{$sambaZones} = map { lc $_->name() } @{$ldap->dnsZones()};

            # Get the DNS keytab path used for GSSTSIG zone updates
            if (EBox::Sudo::fileTest('-f', $sambaModule->SAMBA_DNS_KEYTAB())) {
                $keytabPath = EBox::Samba::SAMBA_DNS_KEYTAB();
            }
        }
    }

    my @array = ();
    $self->writeConfFile(BIND9CONFFILE,
            "dns/named.conf.mas",
            \@array);

    push (@array, 'forwarders' => $self->_forwarders());
    push (@array, 'keytabPath' => $keytabPath);
    my @intnet = @{$self->_internalLocalNets()};
    push (@array, 'intnet' => \@intnet);
    $self->writeConfFile(BIND9CONFOPTIONSFILE,
            "dns/named.conf.options.mas",
            \@array);

    # Delete the already removed RR from dynamic and dlz zones
    $self->_removeDeletedRR();

    # Delete files from no longer used domains
    $self->_removeDomainsFiles();

    # Hash to store the keys indexed by name, storing the secret
    my %keys = ();
    my @domainData = ();
    my @domainIds = @{$self->_domainIds()};
    foreach my $domainId (@domainIds) {
        my $domdata = $self->_completeDomain($domainId);

        # Store the domain data to create the reverse zones
        push (@domainData, $domdata);

        # Add the updater key if the zone is dynamic
        if ($domdata->{dynamic}) {
            $keys{$domdata->{'name'}} = $domdata->{'tsigKey'};
        }

        my $file;
        if ($domdata->{'dynamic'}) {
            $file = BIND9_UPDATE_ZONES;
        } else {
            $file = BIND9CONFDIR;
        }
        $file .= '/db.' . $domdata->{'name'};

        # Prevent to write the file again if this is dynamic and the
        # journal file has been already created
        if ($domdata->{samba}) {
            my $sambaDomData = $self->_completeDomain($domainId);
            delete $sambaDomData->{'nameServers'};
            $self->_updateDynDirectZone($sambaDomData);
        } elsif ($domdata->{'dynamic'} and -e "${file}.jnl") {
            $self->_updateDynDirectZone($domdata);
        } else {
            @array = ();
            push (@array, 'domain' => $domdata);
            $self->writeConfFile($file, "dns/db.mas", \@array);
            EBox::Sudo::root("chown bind:bind '$file'");
        }
    }

    my @inaddrs;
    my $generateReverseZones = EBox::Config::boolean('generate_reverse_zones');
    if ($generateReverseZones) {
        @inaddrs = @{ $self->_writeReverseFiles() };
    }

    my @domains = @{$self->domains()};
    my @intnets = @{$self->_intnets()};

    @array = ();
    push(@array, 'confDir' => BIND9CONFDIR);
    push(@array, 'dynamicConfDir' => BIND9_UPDATE_ZONES);
    push(@array, 'domains' => \@domains);
    push(@array, 'generateReverseZones' => $generateReverseZones);
    push(@array, 'inaddrs' => \@inaddrs);
    push(@array, 'intnets' => \@intnets);
    push(@array, 'internalLocalNets' => $self->_internalLocalNets());
    push(@array, 'sambaZones' => $sambaZones);

    $self->writeConfFile(BIND9CONFLOCALFILE,
            "dns/named.conf.local.mas",
            \@array);

    @array = ();
    push (@array, keys => \%keys);
    $self->writeConfFile(KEYSFILE, 'dns/keys.mas', \@array,
                         {'uid' => 'root', 'gid' => 'bind', mode => '640'});
    if (EBox::Global->modExists('dhcp')) {
        my $mod = EBox::Global->modInstance('dhcp');
        my $file = $mod->KEYS_FILE();
        $self->writeConfFile($file, 'dns/keys.mas', \@array,
            {uid => 'root', 'gid' => 'dhcpd', mode => '640'});
    }
}

sub _writeReverseFiles
{
    my ($self) = @_;

    my $reversedData = $self->_reverseData();

    # Remove the unused reverse files
    $self->_removeUnusedReverseFiles($reversedData);

    my @inaddrs = ();
    foreach my $group (keys %{ $reversedData }) {
        my $reversedDataItem = $reversedData->{$group};
        my $file;
        if ($reversedDataItem->{dynamic}) {
            $file = BIND9_UPDATE_ZONES;
        } else {
            $file = BIND9CONFDIR;
        }
        $file .= "/db." . $group;
        EBox::debug("reverse zone data : $file");
        if ($reversedDataItem->{dynamic} and -e "${file}.jnl" ) {
            $self->_updateDynReverseZone($reversedDataItem);
        } else {
            my @params = ();
            push (@params, 'groupip' => $group);
            push (@params, 'rdata' => $reversedDataItem);
            $self->writeConfFile($file, "dns/dbrev.mas", \@params);
            EBox::Sudo::root("chown bind:bind '$file'");
        }
        # Store to write the zone in named.conf.local
        push (@inaddrs, { ip       => $group,
                          file     => $file,
                          keyNames => [ $reversedDataItem->{'tsigKeyName'} ] } );
    }

    return \@inaddrs;
}

sub _reverseData
{
    my ($self) = @_;

    my $reverseData = {};
    my $domainModel = $self->model('DomainTable');
    foreach my $domainRowId (@{$domainModel->ids()}) {
        my $domainRow = $domainModel->row($domainRowId);
        my $domainName = $domainRow->valueByName('domain');
        my $dynamic = ($domainRow->valueByName('dynamic') or
                       $domainRow->valueByName('samba'));

        my $domainNameservers = [];
        my $nsModel = $domainRow->subModel('nameServers');
        foreach my $nsRowId (@{$nsModel->ids()}) {
            my $nsRow = $nsModel->row($nsRowId);
            my $name = $nsRow->printableValueByName('hostName');
            push (@{$domainNameservers}, $name);
        }

        my $hostnamesModel = $domainRow->subModel('hostnames');
        foreach my $hostnameRowId (@{$hostnamesModel->ids()}) {
            my $hostRow = $hostnamesModel->row($hostnameRowId);
            my $hostName = $hostRow->valueByName('hostname');
            if ( $hostName =~ /^\*/ ) {
                next;
            }
            my $hostIpAddrsModel = $hostRow->subModel('ipAddresses');
            foreach my $hostIpRowId (@{$hostIpAddrsModel->ids()}) {
                my $hostIpRow = $hostIpAddrsModel->row($hostIpRowId);
                my $ip = $hostIpRow->valueByName('ip');
                my @reverseIp = reverse split (/\./, $ip);
                my $hostPart = shift @reverseIp;
                my $groupPart = join ('.', @reverseIp);

                $reverseData->{$groupPart} = {}
                    unless exists $reverseData->{$groupPart};
                if (exists $reverseData->{$groupPart}->{domain} and
                    $domainName ne $reverseData->{$groupPart}->{domain}) {
                    my $warn = "Inconsistent DNS configuration detected. " .
                               "IP group $groupPart is already mapped to domain " .
                               $reverseData->{$groupPart}->{domain} . ". " .
                               "The host $hostName.$domainName with IP $ip is not going " .
                               "to be added to that group";
                    EBox::warn($warn);
                    next;
                }

                $reverseData->{$groupPart}->{dynamic} = $dynamic;
                $reverseData->{$groupPart}->{tsigKeyName} = $domainName;
                $reverseData->{$groupPart}->{group} = $groupPart;
                $reverseData->{$groupPart}->{domain} = $domainName;
                $reverseData->{$groupPart}->{soa} = $self->NameserverHost();
                $reverseData->{$groupPart}->{ns} = $domainNameservers;
                $reverseData->{$groupPart}->{hosts} = []
                    unless exists $reverseData->{$groupPart}->{hosts};
                push (@{$reverseData->{$groupPart}->{hosts}},
                        { name => $hostName, ip => $hostPart });
            }
        }
    }
    return $reverseData;
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('text' => $self->printableName(),
                                    'icon' => 'dns',
                                    'url' => 'DNS/Composite/Global',
                                    'tag' => 'main',
                                    'order' => 5));
}

# Method: keysFile
#
#     Get the keys file path
#
# Returns:
#
#     String - the keys file path
#
sub keysFile
{
    return KEYSFILE;
}

# Group: Protected methods

# Method: _postServiceHook
#
#   Override this method to try to update the dynamic and dlz zones
#   from static definition if the daemon was stopped on configuration
#   regeneration
#
# Overrides:
#
#   <EBox::Module::Service::_postServiceHook>
#
sub _postServiceHook
{
    my ($self, $enabled) = @_;

    if ($enabled) {
        my $nTry = 0;
        do {
            sleep(1);
        } while ( $nTry < 5 and (not $self->_isNamedListening()));
        if ( $nTry < 5 ) {
            foreach my $cmd (@{$self->{nsupdateCmds}}) {
                EBox::Sudo::root($cmd);
                my ($filename) = $cmd =~ m:\s(.*?)$:;
                # Remove the temporary file
                unlink ($filename) if -f $filename;
            }
            delete $self->{nsupdateCmds};
        }
    }

    return $self->SUPER::_postServiceHook($enabled);
}

# Group: Private methods

sub _intnets
{
    my ($self) = @_;

    my $intnets_string = EBox::Config::configkeyFromFile(DNS_INTNETS,
                                                         DNS_CONF_FILE);
    my @intnets;
    if (length $intnets_string) {
        $intnets_string =~ s/\s//g;
        @intnets = split (/,/, $intnets_string);
        my $cidrName = __x("key '{key}' in configuration file {value}",
                           key => DNS_INTNETS,
                           value => DNS_CONF_FILE,
                          );
        foreach my $net (@intnets) {
            EBox::Validate::checkCIDR($net, $cidrName);
        }
    }

    return \@intnets;
}

sub _internalLocalNets
{
    my ($self) = @_;
    my $network = $self->global()->modInstance('network');
    return $network->internalNetworks();
}

# Method: _domainIpAddresses
#
#   Returns an array ref with all domain ip addresses
#
# Parameters:
#
#   model to iterate over
#
# Returns:
#
#  array ref
#
sub _domainIpAddresses
{
    my ($self, $model) = @_;

    my @array;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push (@array, $row->valueByName('ip'));
    }
    return \@array;
}

# Method: _hostnames
#
#   Returns an array with all hostname structure
#
# Parameters:
#   model to iterate over
#
# Returns:
#  array ref with this structure data:
#
#  'name': hostname
#  'ip': an array ref containing the IP addresses of the host
#  'aliases': an array ref returned by <EBox::DNS::aliases> method.
#
sub _hostnames
{
    my ($self, $model) = @_;
    my @array;

    foreach my $id (@{$model->ids()}) {
        my $hostname = $model->row($id);
        my $hostdata = {};

        $hostdata->{'name'} = $hostname->valueByName('hostname');
        $hostdata->{'ip'} = $self->hostIpAddresses($hostname->subModel('ipAddresses'));
        $hostdata->{'aliases'} = $self->aliases($hostname->subModel('alias'));

        push(@array, $hostdata);
    }

    return \@array;
}

# Method: _serviceRecords
#
#   Returns an array with all SRV records of a domain
#
# Parameters:
#
#   model - Model to iterate over
#
# Returns:
#
#   array ref with this structure data:
#   name      - Service name
#   protocol  - Service protocol
#   priority  - Service priority
#   weight    - Service weight
#   port      - Service port
#   target    - Service target host
#
sub _serviceRecords
{
    my ($self, $model) = @_;

    my $array = [];
    foreach my $id (@{$model->ids()}) {
        my $service = $model->row($id);
        my $data = {};
        $data->{name}      = $service->valueByName('service_name');
        $data->{protocol}  = $service->valueByName('protocol');
        $data->{priority}  = $service->valueByName('priority');
        $data->{weight}    = $service->valueByName('weight');
        $data->{port}      = $service->valueByName('port');

        my $selected = $service->elementByName('hostName')->selectedType();
        if ($selected eq 'custom') {
            $data->{target} = $service->valueByName('custom');
        } elsif ($selected eq 'ownerDomain') {
            my $rowId = $service->valueByName('ownerDomain');
            $data->{target} = $service->parentRow()
                ->subModel('hostnames')
                ->row($rowId)
                ->valueByName('hostname');
        }
        push @{$array}, $data;
    }

    return $array;
}

# Method: _textRecords
#
#   Returns an array with all TXT records of a domain
#
# Parameters:
#
#   model - Model to iterate over
#
# Returns:
#
#   array ref with this structure data:
#   name
#   data
#
sub _textRecords
{
    my ($self, $model) = @_;

    my $array = [];
    foreach my $id (@{$model->ids()}) {
        my $txt = $model->row($id);
        my $data = {};
        $data->{data} = $txt->valueByName('txt_data');
        my $selected = $txt->elementByName('hostName')->selectedType();
        if ($selected eq 'custom') {
            $data->{target} = $txt->valueByName('custom');
        } elsif ($selected eq 'ownerDomain') {
            my $rowId = $txt->valueByName('ownerDomain');
            $data->{target} = $txt->parentRow()
                ->subModel('hostnames')
                ->row($rowId)
                ->valueByName('hostname');
        } elsif ($selected eq 'domain') {
            $data->{target} = $txt->valueByName('domain');
        }

        push @{$array}, $data;
    }

    return $array;
}

# Method: _formatMailExchangers
#
#       Format the mail exchangers to write configuration settings
#       properly. That is, custom MX records appends a full stop after
#       the type value.
#
# Parameters:
#
#       mailExchangers - model to iterate over
#
#            hostName - String the host's name
#            id - String the row identifier
#            preference - Int the preference attribute
#            ownerDomain - if the hostname owns to the same domain.
#            custom - if the hostname is a foreign one
#
# Returns:
#
#   Array ref of hashes containing the following keys:
#
#      hostName
#       preference
sub _formatMailExchangers
{
    my ($self, $mailExchangers) = @_;

    my @mailExchangers;
    foreach my $id (@{$mailExchangers->ids()}) {
        my $mx = $mailExchangers->row($id);
        my $hostName = $mx->valueByName('hostName');
        if ($mx->elementByName('hostName')->selectedType() eq 'custom') {
            unless ( $hostName =~ m:\.$: ) {
                $hostName .= '.';
            }
        } else {
            $hostName = $mx->parentRow()
               ->subModel('hostnames')
               ->row($hostName)
               ->valueByName('hostname');
        }
        push (@mailExchangers, {
                hostName => $hostName,
                preference => $mx->valueByName('preference')
                });
    }
    return \@mailExchangers;
}

# Method: _formatNameServers
#
#       Format the name servers to write configuration settings
#       properly. That is, custom NS records appends a full stop after
#       the type value.
#
#       If it has none configured, it will configure the following:
#
#       @ NS 127.0.0.1 # If there is no hostname named NS
#       @ NS ns        # If there is a hostname whose name is 'ns'
#
# Parameters:
#
#       nameServers - model to iterate over
#
#            hostName - String the host's name
#            id - String the row identifier
#            ownerDomain - if the hostname owns to the same domain.
#            custom - if the hostname is a foreign one
#
#       hostnames   - model with hostnames for that domain
#
# Returns:
#
#   Array ref of the name servers to set on
#
sub _formatNameServers
{
    my ($self, $nameServers, $hostnames) = @_;

    my @nameservers;
    foreach my $id (@{$nameServers->ids()}) {
        my $ns = $nameServers->row($id);
        my $hostName = $ns->valueByName('hostName');
        if ($ns->elementByName('hostName')->selectedType() eq 'custom') {
            unless ( $hostName =~ m:\.$: ) {
                $hostName .= '.';
            }
        } else {
            $hostName = $ns->printableValueByName('hostName');
        }
        push (@nameservers, $hostName);
    }
    if ( @nameservers == 0 ) {
        # Look for any hostname whose name is 'ns'
        my $matchedId = $hostnames->findId(hostname => $self->NameserverHost());
        if ( defined($matchedId) ) {
            push(@nameservers, $self->NameserverHost());
        }
    }

    return \@nameservers;
}

# Method: _formatTXT
#
#       Format the TXT records to write configuration settings
#       properly
#
# Parameters:
#
#       text - model to iterate over
#
#            hostName - String the host's name
#            id - String the row identifier
#            txt_data - String the TXT record data
#
# Returns:
#
#   Array ref of hashes containing the following keys:
#
#      hostName
#      txt_data
sub _formatTXT
{
    my ($self, $txt) = @_;

    my @txtRecords;
    foreach my $id (@{$txt->ids()}) {
        my $row = $txt->row($id);
        my $hostName = $row->valueByName('hostName');
        if ($row->elementByName('hostName')->selectedType() eq 'domain') {
            $hostName = $row->parentRow()->valueByName('domain') . '.';
        } elsif ($row->elementByName('hostName')->selectedType() eq 'ownerDomain') {
            $hostName = $row->parentRow()
               ->subModel('hostnames')
               ->row($hostName)
               ->valueByName('hostname');
        } else {
            $hostName = $row->valueByName('hostName');
        }
        push (@txtRecords, {
                hostName => $hostName,
                txt_data => $row->valueByName('txt_data'),
                readOnly => $row->readOnly(),
               });
    }
    return \@txtRecords;
}

# Method: _formatSRV
#
#       Format the SRV records to write configuration settings
#       properly
#
# Parameters:
#
#       srv - model to iterate over
#
#            service_name - String the service's name
#            protocol - String the protocol
#            name - The domain name for which this record is valid.
#            priority - Int the priority
#            weight - Int the weight
#            port - Int the target port
#            id - String the row identifier
#            hostName - String the target host name
#
# Returns:
#
#   Array ref of hashes containing the following keys:
#
#      service_name
#      protocol
#      name
#      priority
#      weight
#      target_port
#      target_host
#
sub _formatSRV
{
    my ($self, $srv) = @_;

    my @srvRecords;
    foreach my $id (@{$srv->ids()}) {
        my $row = $srv->row($id);
        my $targetHost = $row->valueByName('hostName');
        if ($row->elementByName('hostName')->selectedType() eq 'custom') {
            unless ( $targetHost =~ m:\.$: ) {
                $targetHost = $targetHost . '.';
            }
        } else {
            $targetHost = $row->printableValueByName('hostName');
        }
        push (@srvRecords, {
                service_name => $row->valueByName('service_name'),
                protocol => $row->valueByName('protocol'),
                priority => $row->valueByName('priority'),
                weight => $row->valueByName('weight'),
                target_port => $row->valueByName('port'),
                target_host => $targetHost,
                readOnly => $row->readOnly(),
               });
    }
    return \@srvRecords;
}

# Method: _completeDomain
#
#  Return a structure with all required data to build bind db config files
#
# Parameters:
#
#  domain - String the domain's identifier
#
# Returns:
#
# hash ref - structure data with:
#
#  'name': domain name
#  'ipAddresses': array ref containing domain ip addresses
#  'dynamic' :
#  'tsigKey' : the TSIG key if the domain is dynamic
#  'hosts': an array ref returned by <EBox::DNS::_hostnames> method.
#  'mailExchangers' : an array ref returned by <EBox::DNS::_formatMailExchangers>
#  'nameServers' : an array ref returned by <EBox::DNS::_formatNameServers>
#  'txt' : an array ref returned by <EBox::DNS::_formatTXT>
#  'srv' : an array ref returned by <EBox::DNS::_formatSRV>
#
sub _completeDomain # (domainId)
{
    my ($self, $domainId) = @_;

    my $model = $self->model('DomainTable');
    my $row = $model->row($domainId);

    my $domdata;
    $domdata->{'name'} = $row->valueByName('domain');
    $domdata->{dynamic} = $row->valueByName('dynamic');
    $domdata->{samba} = $row->valueByName('samba');
    $domdata->{'tsigKey'} = $row->valueByName('tsigKey');

    $domdata->{'ipAddresses'} = $self->_domainIpAddresses(
        $row->subModel('ipAddresses'));

    $domdata->{'hosts'} = $self->_hostnames(
        $row->subModel('hostnames'));

    $domdata->{'mailExchangers'} = $self->_formatMailExchangers(
        $row->subModel('mailExchangers'));

    $domdata->{'nameServers'} = $self->_formatNameServers($row->subModel('nameServers'),
                                                          $row->subModel('hostnames'));

    $domdata->{'txt'} = $self->_formatTXT($row->subModel('txt'));
    $domdata->{'srv'} = $self->_formatSRV($row->subModel('srv'));

    # The primary name server
    $domdata->{'primaryNameServer'} = $self->NameserverHost();

    return $domdata;
}

# Return the forwarders, if any
sub _forwarders
{
    my ($self) = @_;

    my $fwdModel = $self->model('Forwarder');
    my $forwarders = [];
    foreach my $id (@{$fwdModel->ids()}) {
        push (@{$forwarders}, $fwdModel->row($id)->valueByName('forwarder'));
    }

    return $forwarders;
}

# Return the domain row ids in an array ref
sub _domainIds
{
    my ($self) = @_;

    my $model = $self->model('DomainTable');
    return $model->ids();
}

# Update an already created dynamic reverse zone using nsupdate
sub _updateDynReverseZone
{
    my ($self, $rdata) = @_;

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $zone = $rdata->{'group'} . ".in-addr.arpa";
    foreach my $host (@{$rdata->{'hosts'}}) {
        print $fh 'update delete ' . $host->{'ip'} . ".$zone. PTR\n";
        my $prefix = "";
        $prefix = $host->{'name'} . '.' if ( $host->{'name'} );
        print $fh 'update add ' . $host->{'ip'} . ".$zone. 259200 PTR $prefix" . $rdata->{'domain'} . ".\n";
    }
    # Send the previous commands in batch
    if ( $fh->tell() > 0 ) {
        close($fh);
        tie my @file, 'Tie::File', $fh->filename();
        unshift(@file, "zone $zone");
        push(@file, "send");
        untie(@file);
        $self->_launchNSupdate($fh);
    }
}

# Update the dynamic direct zone
sub _updateDynDirectZone
{
    my ($self, $domData) = @_;

    my $zone = $domData->{'name'};
    my $fh = new File::Temp(DIR => EBox::Config::tmp());

    print $fh "zone $zone\n";
    # Delete everything to make sure the RRs are deleted
    # Likewise, MX applies
    # We cannot do it with dhcpd like records
    print $fh "update delete $zone A\n";

    foreach my $ip (@{$domData->{'ipAddresses'}}) {
        print $fh "update add $zone 259200 A " . $ip . "\n";
    }

    # print $fh "update delete $zone NS\n";
    foreach my $ns (@{$domData->{'nameServers'}}) {
        if ($ns !~ m:\.:g) {
            $ns .= ".$zone";
        }
        print $fh "update add $zone 259200 NS $ns\n";
    }

    my %seen = ();
    foreach my $host (@{$domData->{'hosts'}}) {
        unless ($seen{$host->{'name'}}) {
            # To avoid deleting same name records with different IP addresses
            print $fh 'update delete ' . $host->{'name'} . ".$zone A\n";
        }
        $seen{$host->{'name'}} = 1;
        foreach my $ip (@{$host->{ip}}) {
            print $fh 'update add ' . $host->{'name'} . ".$zone 259200 A $ip\n";
        }
        foreach my $alias (@{$host->{'aliases'}}) {
            print $fh 'update delete ' . $alias . ".$zone CNAME\n";
            print $fh 'update add ' . $alias . ".$zone 259200 CNAME " . $host->{'name'} . ".$zone\n";
        }
    }

    print $fh "update delete $zone MX\n";
    foreach my $mxRR ( @{$domData->{'mailExchangers'}} ) {
        my $mx = $mxRR->{'hostName'};
        if ( $mx !~ m:\.:g ) {
            $mx .= ".$zone";
        }
        print $fh "update add $zone 259200 MX " . $mxRR->{'preference'} . " $mx\n";
    }

    foreach my $txtRR ( @{$domData->{'txt'}} ) {
        my $txt = $txtRR->{'hostName'};
        if ( $txt !~ m:\.:g ) {
            $txt .= ".$zone";
        }
        print $fh qq{update add $txt 259200 TXT "} . $txtRR->{'txt_data'} . qq{"\n};
    }

    foreach my $srvRR ( @{$domData->{'srv'}} ) {
        if ( $srvRR->{'target_host'} !~ m:\.:g ) {
            $srvRR->{'target_host'} .= ".$zone";
        }
        print $fh 'update add _' . $srvRR->{'service_name'} . '._'
                  . $srvRR->{'protocol'} . ".${zone}. 259200 SRV " . $srvRR->{'priority'}
                  . ' ' . $srvRR->{'weight'} . ' ' . $srvRR->{'target_port'}
                  . ' ' . $srvRR->{'target_host'} . "\n";
    }

    print $fh "send\n";

    $self->_launchNSupdate($fh);
}

# Remove no longer available RR in dynamic zones
sub _removeDeletedRR
{
    my ($self) = @_;

    my $deletedRRs = $self->st_get_list(DELETED_RR_KEY);
    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    foreach my $rr (@{$deletedRRs}) {
        print $fh "update delete $rr\n";
    }

    if ( $fh->tell() > 0 ) {
        print $fh "send\n";
        $self->_launchNSupdate($fh);
        $self->st_unset(DELETED_RR_KEY);
    }
}

# Method: _launchNSupdate
#
#   Push deferred nsupdate command to the postservice hook
#
sub _launchNSupdate
{
    my ($self, $fh) = @_;

    my $cmd = NS_UPDATE_CMD . ' -l -t 10 ' . $fh->filename();
    $self->{nsupdateCmds} = [] unless exists $self->{nsupdateCmds};
    push (@{$self->{nsupdateCmds}}, $cmd);
    $fh->unlink_on_destroy(0);
}

# Check if named is listening
sub _isNamedListening
{
    my ($self) = @_;

    my $sock = new IO::Socket::INET(PeerAddr => '127.0.0.1',
                                    PeerPort => 53,
                                    Proto    => 'tcp');
    if ( $sock ) {
        close($sock);
        return 1;
    } else {
        return 0;
    }
}

# Remove no longer used domain files to avoid confusing the user
sub _removeDomainsFiles
{
    my ($self) = @_;

    my $oldList = $self->st_get_list('domain_files');
    my $newList = [];

    my $domainModel = $self->model('DomainTable');
    foreach my $id (@{$domainModel->ids()}) {
        my $row = $domainModel->row($id);
        my $file;
        if ($row->valueByName('dynamic')) {
            $file = BIND9_UPDATE_ZONES;
        } else {
            $file = BIND9CONFDIR;
        }
        $file .= "/db." . $row->valueByName('domain');
        push (@{$newList}, $file) unless $row->valueByName('samba');
    }

    $self->_removeDisjuncFiles($oldList, $newList);
    $self->st_set_list('domain_files', 'string', $newList);
}

# Remove no longer used reverse zone files
sub _removeUnusedReverseFiles
{
    my ($self, $reversedData) = @_;

    my $oldList = $self->st_get_list('inarpa_files');
    my $newList = [];
    foreach my $group (keys %{ $reversedData }) {
        my $reversedDataItem = $reversedData->{$group};
        my $file;
        if ($reversedDataItem->{dynamic}) {
            $file = BIND9_UPDATE_ZONES;
        } else {
            $file = BIND9CONFDIR;
        }
        $file .= "/db." . $group;
        push (@{$newList}, $file);
    }

    $self->_removeDisjuncFiles($oldList, $newList);
    $self->st_set_list('inarpa_files', 'string', $newList);
}

# Delete files from disjunction
sub _removeDisjuncFiles
{
    my ($self, $oldList, $newList) = @_;

    my %newSet = map { $_ => 1 } @{$newList};

    # Show the elements in @oldList which are not in %newSet
    my @disjunc = grep { not exists $newSet{$_} } @{$oldList};

    foreach my $file (@disjunc) {
        if (-f $file) {
            EBox::Sudo::root("rm -rf '$file'");
        }
        # Remove the jnl if exists as well (only applicable for dyn zones)
        if (-f "${file}.jnl") {
            EBox::Sudo::root("rm -rf '${file}.jnl'");
        }
    }
}

# Method: addAlias
#
# Parameters:
# - domain
# - hostname
# - alias: can be a string or a list of string to add more then one alias
#
# Warning:
# alias is added to the first found matching hostname
sub addAlias
{
    my ($self, $domain, $hostname, $alias) = @_;
    $domain or
        throw EBox::Exceptions::MissingArgument('domain');
    my $domainModel = $self->model('DomainTable');
    $domainModel->addHostAlias($domain, $hostname, $alias);
}

# Method: removeAlias
#
#  Remove alias for the doamin and hostname. If there are several hostnames the
#  alias is removed in all of them
#
# Parameters:
# - domain
# - hostname
# - alias
#
# Note:
#  we implement this because vhosttable does not allow exposed method
sub removeAlias
{
    my ($self, $domain, $hostname, $alias) = @_;
    $domain or
        throw EBox::Exceptions::MissingArgument('domain');
    $hostname or
        throw EBox::Exceptions::MissingArgument('hostname');
    $alias or
        throw EBox::Exceptions::MissingArgument('alias');

    my $domainModel = $self->model('DomainTable');
    my $domainRow;
    foreach my $id (@{  $domainModel->ids() }) {
        my $row = $domainModel->row($id);
        if ($row->valueByName('domain') eq $domain) {
            $domainRow = $row;
            last;
        }
    }
    if (not $domainRow) {
        throw EBox::Exceptions::DataNotFound(
            data => __('domain'),
            value => $domain
           );
    }

    my $hostnamesModel = $domainRow->subModel('hostnames');
    my $hostnameFound;
    my $aliasFound;
    foreach my $id (@{  $hostnamesModel->ids() }) {
        my $row = $hostnamesModel->row($id);
        if ($row->valueByName('hostname') eq $hostname) {
            $hostnameFound = 1;
            my $aliasModel = $row->subModel('alias');
            foreach my $aliasId  (@{ $aliasModel->ids() } ) {
                my $row = $aliasModel->row($aliasId);
                if ($row->valueByName('alias') eq $alias) {
                    $aliasFound = 1;
                    $aliasModel->removeRow($aliasId);
                    last;
                }
            }
        }
    }

    if (not $hostnameFound) {
        throw EBox::Exceptions::DataNotFound(
            data => __('hostname'),
            value => $hostname
           );
    }elsif (not $aliasFound) {
        throw EBox::Exceptions::DataNotFound(
            data => __('alias'),
            value => $alias
           );
    }
}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return EBox::DNS::FirewallHelper->new();
    }

    return undef;
}

sub _updateManagedDomainIPsModel
{
    my ($self, $model) = @_;

    my $networkModule = EBox::Global->modInstance('network');
    my $ifaces = $networkModule->allIfaces();
    my %seenAddrs;
    foreach my $iface (@{$ifaces}) {
        if ($networkModule->ifaceMethod($iface) eq 'notset') {
            foreach my $id (@{$model->ids()}) {
                my $row = $model->row($id);
                next unless defined $row;

                my $ifaceElement = $row->elementByName('iface');
                my $ifaceValue = $ifaceElement->value();
                next unless (defined $ifaceValue and length $ifaceValue);

                if ($ifaceValue eq $iface) {
                    $model->removeRow($id);
                }
            }
        } else {
            my $addrs = $networkModule->ifaceAddresses($iface);
            foreach my $addr (@{$addrs}) {
                next if $seenAddrs{$addr};
                $seenAddrs{$addr} = 1;

                my $ifaceName = $iface;
                $ifaceName .= ":$addr->{name}" if exists $addr->{name};
                my $ipRow = $model->find(iface => $ifaceName);
                next unless defined $ipRow;

                my $ipElement = $ipRow->elementByName('ip');
                $ipElement->setValue($addr->{address});
                $ipRow->store();
            }
        }
    }
}

# Method: _updateManagedDomainAddresses
#
#   Updates the managed domain (kerberos or samba) ip addresses
#
sub _updateManagedDomainAddresses
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $domainsModel = $self->model('DomainTable');
    my $managedRows = $domainsModel->findAllValue(managed => 1);

    foreach my $id (@{$managedRows}) {
        my $domainRow = $domainsModel->row($id);

        # Update domain IP addresses
        my $domainIpModel = $domainRow->subModel('ipAddresses');
        $self->_updateManagedDomainIPsModel($domainIpModel);

        # Update hostname IP addresses
        my $hostsModel = $domainRow->subModel('hostnames');
        my $hostRow = $hostsModel->find(hostname => $hostname);
        return unless defined $hostRow;
        my $hostIpModel = $hostRow->subModel('ipAddresses');
        $self->_updateManagedDomainIPsModel($hostIpModel);
    }
}

sub restoreDependencies
{
    return [];
}

sub _checkIfaceUsed
{
    my ($self, $iface) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();

    my $domainsModel = $self->model('DomainTable');
    my $managedRows = $domainsModel->findAllValue(managed => 1);

    foreach my $id (@{$managedRows}) {
        my $domainRow = $domainsModel->row($id);
        next unless defined $domainRow;

        # Check if used in domain IP addresses
        my $domainIpModel = $domainRow->subModel('ipAddresses');
        foreach my $domainIpRowId (@{$domainIpModel->ids()}) {
            my $domainIpRow = $domainIpModel->row($domainIpRowId);
            next unless defined $domainIpRow;

            my $ifaceElement = $domainIpRow->elementByName('iface');
            my $ifaceValue = $ifaceElement->value();
            next unless (defined $ifaceValue and length $ifaceValue);

            if ($ifaceValue eq $iface) {
                return 1;
            }
        }

        # Check if used in hostname IP addresses
        my $hostsModel = $domainRow->subModel('hostnames');
        my $hostRow = $hostsModel->find(hostname => $hostname);
        next unless defined $hostRow;

        my $hostIpModel = $hostRow->subModel('ipAddresses');
        foreach my $hostIpRowId (@{$hostIpModel->ids()}) {
            my $hostIpRow = $hostIpModel->row($hostIpRowId);
            next unless defined $hostIpRow;

            my $ifaceElement = $hostIpRow->elementByName('iface');
            my $ifaceValue = $ifaceElement->value();
            next unless (defined $ifaceValue and length $ifaceValue);

            if ($ifaceValue eq $iface) {
                return 1;
            }
        }
    }

    return 0;
}

######################################
##  Network observer implementation ##
######################################

sub externalDhcpIfaceAddressChangedDone
{
    my ($self, $iface, $oldaddr, $oldmask, $newaddr, $newmask) = @_;
    $self->_updateManagedDomainAddresses();
    # TODO Save only if changes done
    $self->save();
}

sub internalDhcpIfaceAddressChangedDone
{
    my ($self, $iface, $oldaddr, $oldmask, $newaddr, $newmask) = @_;
    $self->_updateManagedDomainAddresses();
    # TODO Save only if changes done
    $self->save();
}

sub staticIfaceAddressChanged
{
    my ($self, $iface, $oldaddr, $oldmask, $newaddr, $newmask) = @_;

    return $self->_checkIfaceUsed($iface);
}

sub staticIfaceAddressChangedDone
{
    my ($self, $iface, $oldaddr, $oldmask, $newaddr, $newmask) = @_;

    $self->_updateManagedDomainAddresses();
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;

    return $self->_checkIfaceUsed($iface);
}

sub ifaceMethodChangeDone
{
    my ($self, $iface) = @_;

    $self->_updateManagedDomainAddresses();
}

######################################
##  SysInfo observer implementation ##
######################################

# Method: hostNameChanged
#
#   This method check that the introduced new hostname is not already
#   defined in any of the user created domains
#
sub hostNameChanged
{
    my ($self, $oldHostName, $newHostName) = @_;

    my $domainModel = $self->model('DomainTable');
    foreach my $domainRowId (@{$domainModel->ids()}) {
        my $domainRow = $domainModel->row($domainRowId);
        my $hostnamesModel = $domainRow->subModel('hostnames');
        foreach my $hostnameRowId (@{$hostnamesModel->ids()}) {
            my $row = $hostnamesModel->row($hostnameRowId);
            my $field = $row->elementByName('hostname');
            if (lc ($field->value('hostname')) eq lc ($newHostName)) {
                my $domainRow = $row->parentRow();
                my $domain = $domainRow->valueByName('domain');
                throw EBox::Exceptions::UnwillingToPerform(
                    reason => __x('The host name {x} is already defined in the domain {y}',
                                  x => $newHostName,
                                  y => $domain ));
            }
        }
    }
}

# Method: hostNameChangedDone
#
#   This method update the hostname in all existant domains
#
sub hostNameChangedDone
{
    my ($self, $oldHostName, $newHostName) = @_;

    my $domainModel = $self->model('DomainTable');
    foreach my $domainRowId (@{$domainModel->ids()}) {
        my $domainRow = $domainModel->row($domainRowId);
        my $hostnamesModel = $domainRow->subModel('hostnames');
        foreach my $hostnameRowId (@{$hostnamesModel->ids()}) {
            my $row = $hostnamesModel->row($hostnameRowId);
            my $field = $row->elementByName('hostname');
            if (lc ($field->value('hostname')) eq lc ($oldHostName)) {
                $field->setValue($newHostName);
                $row->store();
                last;
            }
        }
    }
}

# Method: hostDomainChangedDone
#
#   This method updates the domain name if it is already created
#
sub hostDomainChangedDone
{
    my ($self, $oldDomainName, $newDomainName) = @_;

    my $domainModel = $self->model('DomainTable');
    my $row = $domainModel->find(domain => $oldDomainName);
    if (defined $row) {
        $row->elementByName('domain')->setValue($newDomainName);
        $row->store();
        my $txtModel = $row->subModel('txt');
        foreach my $id (@{$txtModel->ids()}) {
            my $txtRow = $txtModel->row($id);
            my $hostNameElement = $txtRow->elementByName('hostName');
            if (defined $hostNameElement and $hostNameElement->value() eq '_kerberos') {
                my $dataElement = $txtRow->elementByName('txt_data');
                $dataElement->setValue($newDomainName);
                $txtRow->store();
                $self->st_unset(DELETED_RR_KEY);
                last;
            }
        }
    }
}

1;
