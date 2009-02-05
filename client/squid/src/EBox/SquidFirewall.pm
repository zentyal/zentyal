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

package EBox::SquidFirewall;
use strict;
use warnings;

use base 'EBox::FirewallHelper';

use EBox::Objects;
use EBox::Global;
use EBox::Config;
use EBox::Firewall;
use EBox::Gettext;

use Perl6::Junction qw(any);



sub new 
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}


sub _objectsPolicies
{
    my $sq = EBox::Global->modInstance('squid');
    my $objPolicy = $sq->model('ObjectPolicy');
    return $objPolicy->objectsPolicies();
}



sub _normal_prerouting
{
    my ($self) = @_;

    my $sq = EBox::Global->modInstance('squid');
    my $net = EBox::Global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->dansguardianPort();
    my @rules = ();

    my @objsPolicies = @{ $self->_objectsPolicies() };
    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $addr = $net->ifaceAddress($ifc);
        (defined($addr) && $addr ne "") or next;
        
        foreach my $obPolicy (@objsPolicies) {
            push @rules,
                @{ $self->_normal_prerouting_object_rules($obPolicy, $ifc, $addr) };
        }       
    

        if ($sq->globalPolicyUsesFilter()) {
            my $r = "-i $ifc -d $addr -p tcp --dport $sqport ".
                "-j REDIRECT --to-ports $dgport";
            push @rules, $r;
        }

    }

    return \@rules;
}


sub _normal_prerouting_object_rules
{
    my ($self, $obPolicy, $ifc, $addr) = @_;

    my $sq = EBox::Global->modInstance('squid');
    my $net = EBox::Global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->dansguardianPort();

    my @rules;

    if (not $obPolicy->{filter}) {
        foreach my $client ( @{ $obPolicy->{addresses}  }) {
            my $r = "-i $ifc -d $addr -s $client -p tcp " . 
                "--dport $sqport -j RETURN";
            push @rules, $r;
        }
    }
    else {
        foreach my $client ( @{ $obPolicy->{addresses}  } ) {
            my $r = "-i $ifc -d $addr -s $client -p tcp " . 
                "--dport $sqport -j REDIRECT --to-ports $dgport";
            push @rules, $r;
        }
    }

    return \@rules;
}

sub _trans_prerouting
{
    my ($self) = @_;
    my $sq = EBox::Global->modInstance('squid');
    my $net = EBox::Global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->dansguardianPort();
    my @rules = ();
    
    my $anyFilterPolicy = $self->_anyFilterPolicy();
    my $anySquidPolicy  = $self->_anySquidPolicy();

    my @objsPolicies = @{ $self->_objectsPolicies() };

    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        my $addr = $net->ifaceAddress($ifc);
        (defined($addr) && $addr ne "") or next;
        
        foreach my $obPolicy (@objsPolicies) {
            push @rules,
                @{ $self->_normal_trans_prerouting_object_rules(
                                                               $obPolicy,
                                                               $ifc,
                                                               $addr
                                                              ) };
        }

        if ($sq->globalPolicyUsesFilter()) {
            my $r = "-i $ifc -d ! $addr -p tcp --dport 80 ".
                "-j REDIRECT --to-ports $dgport";
                        push(@rules, $r);
        } else {
            my $r = "-i $ifc -d ! $addr -p tcp --dport 80 ".
                "-j REDIRECT --to-ports $sqport";
            push(@rules, $r);
        }
    }
    return \@rules;
}


sub _normal_trans_prerouting_object_rules
{
    my ($self, $obPolicy, $ifc, $addr) = @_;

    my $sq = EBox::Global->modInstance('squid');
    my $net = EBox::Global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->dansguardianPort();

    my @rules;

    my $policy = $obPolicy->{policy};
    if (not $obPolicy->{filter}) {
        foreach my $client ( @{ $obPolicy->{addresses}  }) {
            my $r = "-i $ifc -d ! $addr -s $client -p tcp " . 
                "--dport 80 -j REDIRECT --to-ports $sqport";
            push @rules, $r;
        }
    }
    else {
        foreach my $client ( @{ $obPolicy->{addresses}  } ) {
            my $r = "-i $ifc -d ! $addr -s $client -p tcp " . 
                "--dport 80 -j REDIRECT --to-ports $dgport";
            push @rules, $r;
        }
    }


    return \@rules;
}

sub prerouting
{
    my ($self) = @_;
    my $sq = EBox::Global->modInstance('squid');
    if ($sq->transproxy()) {
        return $self->_trans_prerouting();
    } else {
        return $self->_normal_prerouting();
    }
}

sub input
{
    my ($self) = @_;
    my $sq = EBox::Global->modInstance('squid');
    my $net = EBox::Global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->dansguardianPort();
    my @rules = ();

    my @objsPolicies = @{ $self->_objectsPolicies() };    
    my @ifaces = @{$net->InternalIfaces()};
    foreach my $ifc (@ifaces) {
        foreach my $obPolicy (@objsPolicies) {
            push @rules,
                @{ $self->_input_object_rules($obPolicy, $ifc ) };
        }
        
        if ($sq->globalPolicyUsesFilter()) {
            my $r = "-m state --state NEW -i $ifc ".
                "-p tcp --dport $dgport -j ACCEPT";
            push(@rules, $r);
        } else {
            my $r = "-m state --state NEW -i $ifc ".
                                "-p tcp --dport $sqport -j ACCEPT";
            push(@rules, $r);
        }
    }
    push(@rules, "-m state --state NEW -p tcp --dport $sqport -j DROP");
    return \@rules;
}


sub _input_object_rules
{
    my ($self, $obPolicy, $ifc, $addr) = @_;

    my $sq = EBox::Global->modInstance('squid');
    my $net = EBox::Global->modInstance('network');
    my $sqport = $sq->port();
    my $dgport = $sq->dansguardianPort();

    my @rules;


    if (not $obPolicy->{filter}) {
        foreach my $client ( @{ $obPolicy->{addresses}  } ) {
            my $r = "-m state --state NEW -i $ifc -s $client ".
                "-p tcp --dport $sqport -j ACCEPT";
            push @rules, $r;
            
            $r = "-m state --state NEW -i $ifc -s $client ".
                "-p tcp --dport $dgport -j DROP";
            push @rules, $r;
        }
    }
    else {
        foreach my $client ( @{ $obPolicy->{addresses}  } ) {
            my $r = "-m state --state NEW -i $ifc -s $client ".
                "-p tcp --dport $dgport -j ACCEPT";
            push @rules, $r;
            
            $r = "-m state --state NEW -i $ifc -s $client ".
                "-p tcp --dport $sqport -j DROP";
            push @rules, $r;
        }
    }


    return \@rules;
}



sub output
{
    my ($self) = @_;

    my $sq = EBox::Global->modInstance('squid');
    my @rules = ();
    push(@rules, "-m state --state NEW -p tcp --dport 80 -j ACCEPT");
    push(@rules, "-m state --state NEW -p tcp --dport 443 -j ACCEPT");
    return \@rules;
}

1;
