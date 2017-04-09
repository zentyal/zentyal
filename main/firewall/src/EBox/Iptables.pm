# Copyright (C) 2004-2007 Warp Networks S.L.
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

package EBox::Iptables;

# Package to manage iptables command utility

# private functions will return references to sets of commands to be run
# instead of running the commands themselves

use EBox;
use EBox::Firewall;
use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Network;
use EBox::Firewall::IptablesHelper;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Sudo;

use Perl6::Junction qw( any );
use Socket;
use TryCatch;

my $statenew = " -m state --state NEW ";

use constant IPT_MODULES => ('ip_conntrack_ftp', 'ip_nat_ftp', 'ip_conntrack_tftp');
use constant SYSLOG_LEVEL => 7;

# Constructor: new
#
#      Create a new EBox::Iptables object
#
# Returns:
#
#      A recently created EBox::Iptables object
sub new
{
    my $class = shift;
    my $self = {};
    $self->{firewall} = EBox::Global->modInstance('firewall');
    $self->{net} = EBox::Global->modInstance('network');
    $self->{objects} = $self->{net};

    bless($self, $class);
    return $self;
}

# Method: pf
#
#       Execute iptables command with options
#
# Parameters:
#
#       opts - options passed to iptables
#
# Returns:
#
#       array ref - the output of iptables command in an array
#
sub pf # (options)
{
    my ($opts) = @_;
    return "/sbin/iptables $opts";
}

# Method: _startIPForward
#
#       Change kernel to do IPv4 forwarding (default)
#
# Returns:
#
#       array ref - the output of sysctl command in an array
#
sub _startIPForward
{
    return [ '/sbin/sysctl -q -w net.ipv4.ip_forward="1"' ];
}

# Method: _stopIPForward
#
#       Change kernel to stop doing IPv4 forwarding
#
# Returns:
#
#       array ref - the output of sysctl command in an array
#
sub _stopIPForward
{
    return [ '/sbin/sysctl -q -w net.ipv4.ip_forward="0"' ];
}

# Method: _setKernelParameters
#
#       Set kernel parameters for increased security
#
# Returns:
#
#       array ref - the output of sysctl command in an array
#
sub _setKernelParameters
{
    my @commands;
    # enable TCP SYN cookie protection
    push(@commands, '/sbin/sysctl -q -w net.ipv4.tcp_syncookies="1"');
    # don't log spoofed, source-routed, or redirect packets
    push(@commands, '/sbin/sysctl -q -w net.ipv4.conf.all.log_martians="0"');
    # disable ICMP redirects
    push(@commands, '/sbin/sysctl -q -w net.ipv4.conf.all.accept_redirects="0"');
    push(@commands, '/sbin/sysctl -q -w net.ipv4.conf.all.send_redirects="0"');
    # drop source-routed packets
    push(@commands, '/sbin/sysctl -q -w net.ipv4.conf.all.accept_source_route="0"');
    # enable bad error message protection
    push(@commands, '/sbin/sysctl -q -w net.ipv4.icmp_ignore_bogus_error_responses="1"');
    # enable ICMP broadcast echo protection
    push(@commands, '/sbin/sysctl -q -w net.ipv4.icmp_echo_ignore_broadcasts="1"');
    return \@commands;
}

# Method: _clearTables
#
#       Clear all tables (user defined and nat), set a policy to
#       OUTPUT, INPUT and FORWARD chains and allow always traffic
#       from/to loopback interface.
#
# Parameters:
#
#       policy - It can be a target
#       (ACCEPT|DROP|REJECT|QUEUE|RETURN|user-defined chain)
#       See iptables TARGETS section
#
sub _clearTables # (policy)
{
    my $self = shift;
    my $policy = shift;
    my @commands;
    push(@commands,
            pf("-F"),
            pf("-X"),
            pf("-t nat -F"),
            pf("-t nat -X"),
        );
    # Allow loopback
    if (($policy eq 'DROP') or ($policy eq 'REJECT')) {
        push(@commands,
                pf('-A INPUT -i lo -j ACCEPT'),
                pf('-A OUTPUT -o lo -j ACCEPT'),
            );
    }
    push(@commands,
            pf("-P OUTPUT $policy"),
            pf("-P INPUT $policy"),
            pf("-P FORWARD $policy"),
        );
    return \@commands;
}

# Method: _setStructure
#
#       Set structure to Firewall module to work
#
sub _setStructure
{
    my ($self) = @_;

    my @commands = ();
    push(@commands,
            @{$self->_clearTables("DROP")}
        );

    # state rules
    push(@commands,
            pf('-N preinput'),
            pf('-A INPUT -j preinput'),
            pf('-N preforward'),
            pf('-A FORWARD -j preforward'),
            pf('-N preoutput'),
            pf('-A OUTPUT -j preoutput'),

            pf('-N odrop'),
            pf('-N oaccept'),
            pf('-A OUTPUT -m state --state INVALID -j odrop'),
            pf('-A OUTPUT -m state --state ESTABLISHED,RELATED -j oaccept'),
            pf('-N idrop'),
            pf('-N iaccept'),
            pf('-A INPUT -m state --state INVALID -j idrop'),
            pf('-A INPUT -m state --state ESTABLISHED,RELATED -j iaccept'),
            pf('-N fdrop'),
            pf('-N faccept'),
            pf('-A FORWARD -m state --state INVALID -j fdrop'),
            pf('-A FORWARD -m state --state ESTABLISHED,RELATED -j faccept'),

            pf('-t nat -N premodules'),

            pf('-t nat -N postmodules'),

            pf('-N fnospoofmodules'),
            pf('-N fnospoof'),
            pf('-A fnospoof -j fnospoofmodules'),
            pf('-N fredirects'),
            pf('-N fmodules'),
            pf('-N ffwdrules'),
            pf('-N fnoexternal'),
            pf('-N fdns'),
            pf('-N fglobal'),
            pf('-N ftoexternalonly'),

            pf('-N inospoofmodules'),
            pf('-N inospoof'),
            pf('-A inospoof -j inospoofmodules'),
            pf('-N inointernal'),
            pf('-N iexternalmodules'),
            pf('-N iexternal'),
            pf('-N inoexternal'),
            pf('-N imodules'),
            pf('-N iglobal'),

            pf('-N drop'),

            pf('-N log'),

            pf('-N ointernal'),
            pf('-N omodules'),
            pf('-N oglobal'),

            pf('-t nat -A PREROUTING -j premodules'),

            pf('-t nat -A POSTROUTING -j postmodules'),

            pf('-A FORWARD -j fnospoof'),
            pf('-A FORWARD -j fredirects'),
            pf('-A FORWARD -j fmodules'),
            pf('-A FORWARD -j ffwdrules'),
            pf('-A FORWARD -j fnoexternal'),
            pf('-A FORWARD -j fdns'),
            pf('-A FORWARD -j fglobal'),
            pf("-A FORWARD -p icmp --icmp-type echo-request ! -f $statenew -j faccept"), # accept ping requests
            pf("-A FORWARD -p icmp --icmp-type echo-reply ! -f $statenew -j faccept"), # accept ping responses
            pf("-A FORWARD -p icmp --icmp-type destination-unreachable ! -f $statenew -j faccept"), # accept notifications of unreachable hosts
            pf("-A FORWARD -p icmp --icmp-type source-quench ! -f $statenew -j faccept"), # accept notifications to reduce sending speed
            pf("-A FORWARD -p icmp --icmp-type time-exceeded ! -f $statenew -j faccept"), # accept notifications of lost packets
            pf("-A FORWARD -p icmp --icmp-type parameter-problem ! -f $statenew -j faccept"), # accept notifications of protocol problems
            pf('-A FORWARD -j fdrop'),

            pf('-A INPUT -j inospoof'),
            pf('-A INPUT -j iexternalmodules'),
            pf('-A INPUT -j iexternal'),
            pf('-A INPUT -j inoexternal'),
            pf('-A INPUT -j imodules'),
            pf('-A INPUT -j iglobal'),
            pf("-A INPUT -p icmp --icmp-type echo-request ! -f $statenew -j iaccept"), # accept ping requests
            pf("-A INPUT -p icmp --icmp-type echo-reply ! -f $statenew -j iaccept"), # accept ping responses
            pf("-A INPUT -p icmp --icmp-type destination-unreachable ! -f $statenew -j iaccept"), # accept notifications of unreachable hosts
            pf("-A INPUT -p icmp --icmp-type source-quench ! -f $statenew -j iaccept"), # accept notifications to reduce sending speed
            pf("-A INPUT -p icmp --icmp-type time-exceeded ! -f $statenew -j iaccept"), # accept notifications of lost packets
            pf("-A INPUT -p icmp --icmp-type parameter-problem ! -f $statenew -j iaccept"), # accept notifications of protocol problems
            pf('-A INPUT -j idrop'),

            pf('-A OUTPUT -j ointernal'),
            pf('-A OUTPUT -j omodules'),
            pf('-A OUTPUT -j oglobal'),
            pf("-A OUTPUT -p icmp --icmp-type echo-request ! -f $statenew -j oaccept"), # accept ping requests
            pf("-A OUTPUT -p icmp --icmp-type echo-reply ! -f $statenew -j oaccept"), # accept ping responses
            pf("-A OUTPUT -p icmp --icmp-type destination-unreachable ! -f $statenew -j oaccept"), # accept notifications of unreachable hosts
            pf("-A OUTPUT -p icmp --icmp-type source-quench ! -f $statenew -j oaccept"), # accept notifications to reduce sending speed
            pf("-A OUTPUT -p icmp --icmp-type time-exceeded ! -f $statenew -j oaccept"), # accept notifications of lost packets
            pf("-A OUTPUT -p icmp --icmp-type parameter-problem ! -f $statenew -j oaccept"), # accept notifications of protocol problems
            pf('-A OUTPUT -j odrop'),

            pf("-A idrop -j drop"),
            pf("-A odrop -j drop"),
            pf("-A fdrop -j drop"),

            pf("-A iaccept -j ACCEPT"),
            pf("-A oaccept -j ACCEPT"),
            pf("-A faccept -j ACCEPT"),
            );
    return \@commands;
}

# Method: _setDNS
#
#       Set DNS traffic for forwarding and output with destination dns
#
# Parameters:
#
#       dns - address/[mask] destination to accept DNS traffic
#
sub _setDNS # (dns)
{
    my ($self, $dns) = @_;

    my @commands = (
        pf("-A ointernal $statenew -p udp --dport 53 -d $dns -j oaccept || true"),
        pf("-A ointernal $statenew -p tcp --dport 53 -d $dns -j oaccept || true"),
        pf("-A fdns $statenew -p udp --dport 53 -d $dns -j faccept || true"),
        pf("-A fdns $statenew -p tcp --dport 53 -d $dns -j faccept || true"),
    );
    return \@commands;
}

# Method: _setDHCP
#
#       Set output DHCP traffic
#
# Parameters:
#
#       interface -
#
sub _setDHCP
{
    my ($self, $interface) = @_;

    $interface = $self->{net}->realIface($interface);
    return [ pf("-A ointernal $statenew -o $interface -p udp --dport 67 -j oaccept") ];
}

# Method: _nospoof
#
#       Set no IP spoofing (forged) for the given addresses to the
#       interface given
#
# Parameters:
#
# interface - the allowed interface for the addresses
# addresses - An array ref with the address to allow traffic from
#             the given interface. Each slot has the following
#             fields:
#                - address - the IP address
#                - netmask - the IP network mask

sub _nospoof # (interface, \@addresses)
{
    my ($self, $iface, $addresses) = @_;

    $iface = $self->{net}->realIface($iface);

    my @commands;
    foreach (@{$addresses}) {
        my $addr = $_->{address};
        my $mask = $_->{netmask};
        push(@commands,
                pf("-A fnospoof -s $addr/$mask ! -i $iface -j fdrop"),
                pf("-A inospoof -s $addr/$mask ! -i $iface -j idrop"),
               # pf("-A inospoof ! -i $iface -d $addr -j idrop"),
            );
    }
    return \@commands;
}

# Method: stop
#
#       Stop iptables service, stop forwarding from kernel
#       and free all tables
#
sub stop
{
    my ($self) = @_;

    my @commands;
    push(@commands, @{_stopIPForward()});
    push(@commands, @{$self->_clearTables("ACCEPT")});
    EBox::Sudo::root(@commands);
}

# Method: vifaceRealname
#
#       Return the real name from a virtual interface
#
# Parameters:
#
#       viface - Virtual interface
#
# Returns:
#
#       string - The real name from the given virtual interface
#
sub vifaceRealname # (viface)
{
    my $virtual = shift;
    $virtual =~ s/:.*$//;
    return $virtual;
}

# Method: start
#
#       Start firewall service setting up the structure and the rules
#       to work with iptables.
#
sub start
{
    my $self = shift;

    my @commands;

    push(@commands, @{$self->_loadIptModules()});

    push(@commands, @{$self->_setStructure()});

    my @dns = @{$self->{net}->nameservers()};
    foreach my $ns (@dns) {
        if ($ns ne '127.0.0.1') {
            push(@commands, @{$self->_setDNS($ns)});
        }
    }

    foreach my $object (@{$self->{objects}->objects}) {
        my $members = $self->{objects}->objectMembers($object->{id});
        foreach my $member (@{$members}) {
            my $mac = $member->{macaddr};
            defined($mac) or next;
            ($mac ne "") or next;
            my $address = $member->{ipaddr};
            push(@commands,
                    pf("-A inospoof -m mac -s $address " .
                        "! --mac-source $mac -j idrop"),
                    pf("-A fnospoof -m mac -s $address " .
                        "! --mac-source $mac -j fdrop"),
                );
        }
    }

    my @ifaces = @{$self->{net}->ifaces()};
    foreach my $ifc (@ifaces) {
        next if ($self->{net}->ifaceMethod($ifc) eq 'bridged');

        if ($self->{net}->ifaceMethod($ifc) eq any('dhcp', 'ppp')) {
            push(@commands, @{$self->_setDHCP($ifc)});
        } else {
            # Anti-spoof rules only for static interfaces
            my $addrs = $self->{net}->ifaceAddresses($ifc);
            push(@commands, @{$self->_nospoof($ifc, $addrs)});
        }
    }

    push(@commands, @{$self->_redirects()});
    push (@commands, @{$self->_snat() });

    @ifaces = @{$self->{net}->ExternalIfaces()};
    foreach my $if (@ifaces) {
        my $method = $self->{net}->ifaceMethod($if);
        $if = $self->{net}->realIface($if);

        my $input = $self->_inputIface($if);
        my $output = $self->_outputIface($if);

        push(@commands,
            pf("-A fnoexternal $statenew $input -j fdrop"),
            pf("-A inoexternal $statenew $input -j idrop"),
            pf("-A ftoexternalonly $output -j faccept"),
        );

        next unless (_natEnabled());

        if ($method eq 'static') {
            my $addr = $self->{net}->ifaceAddress($if);
            my $src = $addr;

            # If it's a bridge SNAT traffic out of the network
            if ( $self->{net}->ifaceIsBridge($if) ) {
                my $mask = $self->{net}->ifaceNetmask($if);
                $src = "$addr/$mask";
            }
            push(@commands,
                pf("-t nat -A POSTROUTING ! -s $src $output " .
                   "-j SNAT --to $addr")
            );
        } elsif (($method eq 'dhcp') or ($method eq 'ppp')) {
            if ( $self->{net}->ifaceIsBridge($if) ) {
                push(@commands,
                    pf("-t nat -A POSTROUTING $output -m physdev" .
                       " ! --physdev-is-bridged -j MASQUERADE")
                );
            }
            else {
                push(@commands,
                    pf("-t nat -A POSTROUTING $output -j MASQUERADE")
                );
            }
        }
    }

    push(@commands, @{$self->_drop()});

    push(@commands, @{$self->_log()});

    push(@commands, @{$self->_iexternal()});

    push(@commands, @{$self->_iglobal()});

    push(@commands, pf("-A ftoexternalonly -j fdrop"));

    push(@commands, @{$self->_fglobal()});

    push(@commands, @{$self->_ffwdrules()});

    push(@commands, @{$self->_oglobal()});

    push(@commands, @{_startIPForward()});

    push(@commands, @{_setKernelParameters()});

    EBox::Sudo::root(@commands);

    # Create rules by modules firewall helpers
    $self->_executeModuleRules();
}

# Method: moduleRules
#
#       Get the rules added by the Zentyal modules through FirewallObserver
#
# Returns:
#
#      Reference to array of hashrefs { module, priority, rule }
#
sub moduleRules
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my @modNames = @{$global->modNames};
    my @mods = @{$global->modInstancesOfType('EBox::FirewallObserver')};
    my @modRules;
    foreach my $mod (@mods) {
        my $helper = $mod->firewallHelper();
        ($helper) or next;

        # add rules
        push(@modRules, @{$self->_modRules($mod, $helper)});
    }

    return \@modRules;
}

sub _loadIptModules
{
    my @commands;

    my @toLoad = IPT_MODULES;
    my $extraModules = EBox::Config::configkey("iptables_modules");
    if ($extraModules) {
        push @toLoad, split (',+', $extraModules);
    }

    foreach my $module (@toLoad) {
        push(@commands, "modprobe $module || true");
    }
    return \@commands;
}

# Method: executeModuleRules
#
#   executes the rules for the firewall helper of the given module
#
#   Parameters:
#      $mod - module instance
#      $enabledRules - hash to fitler out rules (Optional)
sub executeModuleRules
{
    my ($self, $mod, $enabledRules) = @_;
    my $helper = $mod->firewallHelper();
    ($helper) or return;

    my $modRules = $self->_modRules($mod, $helper);

    my @sortedRules = sort { $a->{'priority'} <=> $b->{'priority'} } @{$modRules};
    my @commands = map {
        my $r = $_->{'rule'};
        pf($r) if ((not $enabledRules) or $enabledRules->{$r})
    } @sortedRules;

    EBox::Sudo::root(@commands);
}

# Execute firewall helper rules for each module
sub _executeModuleRules
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $model = $self->{firewall}->{'EBoxServicesRuleTable'};
    my %enabledRules =
        map { $model->row($_)->valueByName('rule') => 1 } @{$model->enabledRows()};

    my @mods = @{$global->modInstancesOfType('EBox::FirewallObserver')};
    my @failedMods;
    foreach my $mod (@mods) {
        try {
            $self->executeModuleRules($mod, \%enabledRules);
        } catch {
            EBox::error('Error executing firewall rules for module ' . $mod->name());
            push(@failedMods, $mod->name());
        }
    }

    if (@failedMods) {
        my $message = __('Firewall failed to add rules for the following modules: ');
        $message .= join(', ', @failedMods) . '. ';

        $message .= __('Probably this is caused by a lack of connectivity, ' .
                       'check your configuration or disable those modules');
        $global->addSaveMessage($message);
    }
}


# Helper rules for one module
sub _modRules
{
    my ($self, $mod, $helper) = @_;
    my @modRules;

    push(@modRules, @{$self->_createChains($mod, $helper)});

    push(@modRules, @{$self->_doRuleset($mod, 'nat',    'premodules', $helper->prerouting())});
    push(@modRules, @{$self->_doRuleset($mod, 'nat',    'postmodules', $helper->postrouting())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'preinput', $helper->preInput())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'preoutput', $helper->preOutput())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'preforward', $helper->preForward())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'fnospoofmodules', $helper->forwardNoSpoof())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'inospoofmodules', $helper->inputNoSpoof())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'fmodules', $helper->forward())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'iexternalmodules', $helper->externalInput())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'imodules', $helper->input())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'omodules', $helper->output())});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'iaccept', $helper->inputAccept(), 'insert')});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'faccept', $helper->forwardAccept(), 'insert')});
    push(@modRules, @{$self->_doRuleset($mod, 'filter', 'oaccept', $helper->outputAccept(), 'insert')});

    return \@modRules;
}

sub _createChains
{
    my ($self, $module, $helper) = @_;

    my @commands;
    my %chains = %{$helper->chains()};
    foreach my $table ( keys %chains ) {
        my @tchains = @{$chains{$table}};
        foreach my $chain (@tchains) {
            my $pfrule = "-t $table -N $chain";
            my $r = { 'module' => $module, 'priority' => 1, 'rule' => $pfrule };
            push(@commands, $r);
        }
    }
    return \@commands;
}

sub _doRuleset # (module, table, chain, \@rules, $action)
{
    my ($self, $module, $table, $chain, $rules, $action) = @_;

    $action = 'append' unless (defined($action));
    $action = ($action eq 'append') ? '-A' : '-I';
    my @commands;
    foreach my $r (@{$rules}) {
        my $priority = 50;
        my $pfrule;
        my $pfchain = $chain;
        if (ref($r) eq 'HASH') {
            if(defined($r->{'priority'})) {
                $priority = $r->{'priority'};
            }
            if(defined($r->{'chain'})) {
                $pfchain = $r->{'chain'};
            }
            $pfrule = $r->{'rule'};
        } else {
            $pfrule = $r;
        }
        $pfrule = "-t $table $action $pfchain $pfrule";
        my $r = { 'module' => $module, 'priority' => $priority, 'rule' => $pfrule };
        push(@commands, $r);
    }
    return \@commands;
}

# Method: _iexternalCheckInit
#
#	Add checks to iexternalmodules and iexternal to only affect
#	packates coming from external interfaces
sub _iexternalCheckInit
{
    my ($self) = @_;

    my @commands;

    my @internalIfaces = @{$self->{net}->InternalIfaces()};
    foreach my $if (@internalIfaces) {
        $if = $self->{net}->realIface($if);
        my $input = $self->_inputIface($if);

        push(@commands,
            pf("-A iexternalmodules $input -j RETURN"),
            pf("-A iexternal $input -j RETURN"),
        );
    }
    foreach my $if (@{_vpnIfaces()}) {
        my $input = $self->_inputIface($if);

        push(@commands,
            pf("-A iexternalmodules $input -j RETURN"),
            pf("-A iexternal $input -j RETURN"),
        );
    }
    return \@commands;
}

# Method: _iexternal
#
# Add checks to iexternalmodules and iexternal to only affect
# packates coming from external interfaces
sub _iexternal
{
    my ($self) = @_;

    my @commands;

    push (@commands, @{$self->_iexternalCheckInit()});
    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->ExternalToEBoxRuleTable()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

# Method: _iglobal
#
#	Add rules to iglobal, that is the chain to control access
#	from the internal networks to Zentyal
sub _iglobal
{
    my ($self) = @_;

    my @commands;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->InternalToEBoxRuleTable()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

# Method: _oglobal
#
#   Add rules to iglobal, that is the chain to control access
#   from Zentyal to external services
sub _oglobal
{
    my ($self) = @_;

    my @commands;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->EBoxOutputRuleTable()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

# Method: _fglobal
#
#   Add rules to fglobal, that is the chain to control access
#   from the internal networks to Internet
sub _fglobal
{
    my ($self) = @_;

    my @commands;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->ToInternetRuleTable()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

# Method: _ffwdrules
#
#   Add rules to ffwdrules, that is the chain to control access
#   from the external networks to Internet
sub _ffwdrules
{
    my ($self) = @_;

    my @commands;

    my @internalIfaces = @{$self->{net}->InternalIfaces()};
    foreach my $if (@internalIfaces) {
        $if = $self->{net}->realIface($if);
        my $input = $self->_inputIface($if);

        push(@commands, pf("-A ffwdrules $input -j RETURN"));
    }
    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->ExternalToInternalRuleTable()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

# Method: _redirects
#
#	Add redirects rules
sub _redirects
{
    my ($self) = @_;

    my @commands;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->RedirectsRuleTable()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

sub _snat
{
    my ($self) = @_;

    my @commands;

    my $iptHelper = new EBox::Firewall::IptablesHelper;
    for my $rule (@{$iptHelper->SNATRules()}) {
        push(@commands, pf("$rule"));
    }
    return \@commands;
}

# Method: _drop
#
#	Set up drop chain. Log rule and drop rule
#
sub _drop
{
    my ($self) = @_;

    my @commands;
    push(@commands, pf('-I drop -j DROP'));

    my $logDrops = EBox::Config::configkey('iptables_log_drops');
    defined($logDrops) or $logDrops = 'yes';

    # If logging is disabled or we don't want to log drops, then we are done
    if($self->{firewall}->logging() and ($logDrops eq 'yes')) {

        my $limit = EBox::Config::configkey('iptables_log_limit');
        my $burst = EBox::Config::configkey('iptables_log_burst');

        unless (defined($limit) and $limit =~ /^\d+$/) {
        throw EBox::Exceptions::External(__('You must set the ' .
            'iptables_log_limit variable in the ebox configuration file'));

        }

        unless (defined($burst) and $burst =~ /^\d+$/) {
        throw EBox::Exceptions::External(__('You must set the ' .
            'iptables_log_burst variable in the ebox configuration file'));

        }
        push(@commands,
            pf("-I drop -j LOG -m limit --limit $limit/min " .
            "--limit-burst $burst" .
            ' --log-level ' . SYSLOG_LEVEL .
            ' --log-prefix "zentyal-firewall drop "')
        );
    }
    return \@commands;
}

# Method: _log
#
#	Set up log chain. Log rule and return rule
#
sub _log
{
    my ($self) = @_;

    my @commands;
    push(@commands, pf('-I log -j RETURN'));

    # If logging is disabled we are done
    if ($self->{firewall}->logging()) {
        my $limit = EBox::Config::configkey('iptables_log_limit');
        my $burst = EBox::Config::configkey('iptables_log_burst');

        unless (defined($limit) and $limit =~ /^\d+$/) {
        throw EBox::Exceptions::External(__('You must set the ' .
            'iptables_log_limit variable in the ebox configuration file'));

        }

        unless (defined($burst) and $burst =~ /^\d+$/) {
        throw EBox::Exceptions::External(__('You must set the ' .
            'iptables_log_burst variable in the ebox configuration file'));

        }
        push(@commands,
            pf("-I log -j LOG -m limit --limit $limit/min " .
            "--limit-burst $burst" .
            ' --log-level ' . SYSLOG_LEVEL .
            ' --log-prefix "zentyal-firewall log "')
        );
    }
    return \@commands;
}

# Method: _outputIface
#
#   Returns iptables rule part for output interface selection
#   Takes into account if the iface is part of a bridge
#
# Parameters:
#
#   Iface - Iface name
#
sub _outputIface # (iface)
{
    my ($self, $iface) = @_;

    if ( $self->{net}->ifaceExists($iface) and
         $self->{net}->ifaceMethod($iface) eq 'bridged' ) {
        return  "-m physdev --physdev-out $iface";
    } else {
        return "-o $iface";
    }
}

# Method: _inputIface
#
#   Returns iptables rule part for input interface selection
#   Takes into account if the iface is part of a bridge
#
# Parameters:
#
#   Iface - Iface name
#
sub _inputIface # (iface)
{
    my ($self, $iface) = @_;

    if ( $self->{net}->ifaceExists($iface) and
         $self->{net}->ifaceMethod($iface) eq 'bridged' ) {
        return  "-m physdev --physdev-in $iface";
    } else {
        return "-i $iface";
    }
}

# Method: _natEnabled
#
#   Fetch value to enable NAT
#
sub _natEnabled
{
    my $nat =  EBox::Config::configkey('nat_enabled');

    return 1 unless (defined($nat));

    if ($nat =~ /no/) {
        return undef;
    } else {
        return 1;
    }
}

# Method: _vpnIfaces
#
#   Fetch vpn interfaces
sub _vpnIfaces
{
    my $gl = EBox::Global->getInstance();
    if ($gl->modExists('openvpn')) {
        my $vpn = $gl->modInstance('openvpn');
        $vpn->initializeInterfaces();
        return [map {$_->iface() } $vpn->activeDaemons()];
    } else {
        return [];
    }
}

1;
