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

package EBox::SquidFirewall;

use base 'EBox::FirewallHelper';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;

sub chains
{
    return {
        'filter' => ['isqfilter', 'fsqfilter']
    };
}

# Method: prerouting
#
#   To set transparent HTTP proxy if it is enabled
#
# Overrides:
#
#   <EBox::FirewallHelper::prerouting>
#
sub prerouting
{
    my ($self) = @_;

    my $sq = $self->_global()->modInstance('squid');
    if ( (not $sq->temporaryStopped()) and $sq->transproxy()) {
        return $self->_trans_prerouting();
    }

    return [];
}

# Method: restartOnTemporaryStop
#
# Overrides:
#
#   <EBox::FirewallHelper::restartOnTemporaryStop>
#
sub restartOnTemporaryStop
{
    return 1;
}

sub _trans_prerouting
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    my $net = $global->modInstance('network');
    my $sqport = $sq->port();

    my @rules = ();
    my $exceptions = $sq->model('TransparentExceptions');
    foreach my $id (@{$exceptions->enabledRows()}) {
        my $row = $exceptions->row($id);
        my $addr = $row->valueByName('domain');
        push (@rules, "-p tcp -d $addr --dport 80 -j ACCEPT");
    }

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $addrs = $net->ifaceAddresses($ifc);
        my $input = $self->_inputIface($ifc);

        foreach my $addr (map { $_->{address} } @{$addrs}) {
            (defined($addr) && $addr ne "") or next;
            my $rHttp = "$input ! -d $addr -p tcp --dport 80 -j REDIRECT --to-ports $sqport";
            push (@rules, $rHttp);
        }
    }

    return \@rules;
}

sub input
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    my $net = $global->modInstance('network');
    my $squidFrontPort = $sq->port();
    my $dansguardianPort = $sq->DGPORT();
    my $squidBackPort = $sq->SQUID_EXTERNAL_PORT();

    my @rules = ();
    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $input = $self->_inputIface($ifc);
        my $r = "-m state --state NEW $input -p tcp --dport $squidFrontPort -j iaccept";
        push (@rules, $r);
    }
    push (@rules, "-m state --state NEW -p tcp --dport $dansguardianPort -j DROP");
    push (@rules, "-m state --state NEW -p tcp --dport $squidBackPort -j DROP");

    return \@rules;
}

sub output
{
    my ($self) = @_;

    my @rules = ();
    push (@rules, "-m state --state NEW -p tcp --dport 80 -j oaccept");
    push (@rules, "-m state --state NEW -p tcp --dport 443 -j oaccept");

    return \@rules;
}

sub forward
{
    my ($self) = @_;

    my $sq = $self->_global()->modInstance('squid');
    if ( (not $sq->temporaryStopped()) and $sq->transproxy()) {
        return $self->_trans_forward();
    }

    return [];
}

sub _trans_forward
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    my $net = $global->modInstance('network');

    my @rules = ();
    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $input = $self->_inputIface($ifc);
        my $r = "$input -p tcp --dport 443 -j fsqfilter";
        push(@rules, { 'rule' => $r, 'chain' => 'preforward' });
    }

    foreach my $r (@{$self->_trans_forward_filter_rules()}) {
        push (@rules, $r);
    }

    return \@rules;
}

sub _trans_forward_filter_rules
{
    my ($self) = @_;

    my $global = $self->_global();
    my $sq = $global->modInstance('squid');
    my $net = $global->modInstance('network');
    my $obj = $global->modInstance('objects');

    my $accesRulesModel =  $sq->model('AccessRules');
    my $accessRules = $accesRulesModel->rules();

    my @rules = ();
    foreach my $rule (@{$accessRules}) {
        if (defined $rule->{object}) {
            my $members = $obj->objectMembers($rule->{object});
            my $policy = $rule->{policy};
            if ($policy eq 'allow') {
                my @r = map {
                            $_ . ' -p tcp -j faccept'
                        } @{$members->iptablesSrcParams(1)};
                push(@rules, map { { 'rule' => $_, 'chain' => 'fsqfilter' } } @r);
            } elsif ($policy eq 'deny') {
                my @r = map {
                            $_ . ' -p tcp -j fdrop'
                        } @{$members->iptablesSrcParams(1)};
                push(@rules, map { { 'rule' => $_, 'chain' => 'fsqfilter' } } @r);
            } elsif ($policy eq 'profile') {
                my $profile = $rule->{profile};
                my $domainFilter = $self->_getDomainFilter($profile);
                my $allowedDomains = $domainFilter->allowed();
                my $bannedDomains = $domainFilter->banned();
                foreach my $domain (@{$allowedDomains}) {
                    my @r = map {
                            $_ . " -m string --string $domain --algo bm -j faccept"
                        } @{$members->iptablesSrcParams(1)};
                    push(@rules, map { { 'rule' => $_, 'chain' => 'fsqfilter' } } @r);
                }
                foreach my $domain (@{$bannedDomains}) {
                    my @r = map {
                            $_ . " -m string --string $domain --algo bm -j fdrop"
                        } @{$members->iptablesSrcParams(1)};
                    push(@rules, map { { 'rule' => $_, 'chain' => 'fsqfilter' } } @r);
                }
            }
        } elsif (defined $rule->{any}) {
            my $policy = $rule->{policy};
            if ($policy eq 'allow') {
                my $r = '-p tcp -j faccept'; #XXX to avoid crash in EBox::Firewall::Model::EBoxServicesRuleTable::syncRows:+81
                push(@rules, { 'rule' => $r, 'chain' => 'fsqfilter' });
            } elsif ($policy eq 'deny') {
                my $r = '-p tcp -j fdrop'; #XXX idem
                push(@rules, { 'rule' => $r, 'chain' => 'fsqfilter' });
            } elsif ($policy eq 'profile') {
                my $profile = $rule->{profile};
                my $domainFilter = $self->_getDomainFilter($profile);
                my $allowedDomains = $domainFilter->allowed();
                my $bannedDomains = $domainFilter->banned();
                foreach my $domain (@{$allowedDomains}) {
                    my $r = "-m string --string $domain --algo bm -j faccept";
                    push(@rules, { 'rule' => $r, 'chain' => 'fsqfilter' });
                }
                foreach my $domain (@{$bannedDomains}) {
                    my $r = "-m string --string $domain --algo bm -j fdrop";
                    push(@rules, { 'rule' => $r, 'chain' => 'fsqfilter' });
                }
            }
        }
    }

    return \@rules;
}

sub _getDomainFilter
{
    my ($self, $ids) = @_;

    my $global = $self->_global();
    my $squid = $global->modInstance('squid');
    my $profilesModel = $squid->model('FilterProfiles');
    my $row = $profilesModel->row($ids);
    $row or return undef;
    my $policy = $row->elementByName('filterPolicy')->foreignModelInstance();
    my $domainComposite = $policy->componentByName('Domains', 1);
    my $domainFilter = $domainComposite->componentByName('DomainFilter', 1);
    return $domainFilter;
}

sub _global
{
    my ($self) = @_;
    my $ro = $self->{ro};

    return EBox::Global->getInstance($ro);
}

1;
