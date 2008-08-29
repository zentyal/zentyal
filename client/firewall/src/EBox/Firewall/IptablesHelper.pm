# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Firewall::IptablesHelper
#
#	This class is used to build iptables rules based on the data
#	stored in the firewall models, namely:
#
#	<EBox::Firewall::Model::ToInternetRule>
#
#	It uses <EBox::Firewall::IptablesRule> to assit with rules creation
#

package EBox::Firewall::IptablesHelper;

use warnings;
use strict;

use EBox::Model::ModelManager;
use EBox::Firewall::IptablesRule;

use EBox::Exceptions::Internal;

sub new 
{
    my $class = shift;
    my %opts = @_;
    my $self = {}; 
    $self->{'manager'} = EBox::Model::ModelManager->instance();
    bless($self, $class);
    return $self;
}

# Method: ToInternetRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::ToInternetRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub ToInternetRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('ToInternetRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get ToInternetRuleTableModel");

    my @rules;
    for my $row (@{$model->rows()}) {
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => 'fglobal');
        $self->_addAdddressToRule($rule, $row, 'source');
        $self->_addAdddressToRule($rule, $row, 'destination');
        $self->_addServiceToRule($rule, $row);  
        $self->_addDecisionToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: ExternalToInternalRuleTable
#
#   Return iptables rules from 
#   <EBox::Firewall::Model::ExternalToInternalRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub ExternalToInternalRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('ExternalToInternalRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get ExternalToInternalRuleTableModel");

    my @rules;
    for my $row (@{$model->rows()}) {
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => 'ffwdrules');
        $self->_addAdddressToRule($rule, $row, 'source');
        $self->_addAdddressToRule($rule, $row, 'destination');
        $self->_addServiceToRule($rule, $row);  
        $self->_addDecisionToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: InternalToEBoxRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::InternalToEBoxRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub InternalToEBoxRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('InternalToEBoxRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get InternalToEBoxRuleTableModel");

    my @rules;
    for my $row (@{$model->rows()}) {
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => 'iglobal');
        $rule->setState('new' => 1);
        $self->_addAdddressToRule($rule, $row, 'source');
        $self->_addServiceToRule($rule, $row);  
        $self->_addDecisionToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: ExternalToEBoxRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::ExternalToEBoxRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub ExternalToEBoxRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('ExternalToEBoxRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get ExternalToEBoxRuleTableModel");

    my @rules;
    for my $row (@{$model->rows()}) {
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => 'iexternal');
        $rule->setState('new' => 1);
        $self->_addAdddressToRule($rule, $row, 'source');
        $self->_addServiceToRule($rule, $row);  
        $self->_addDecisionToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

# Method: EBoxOutputRuleTable
#
#   Return iptables rules from <EBox::Firewall::Model::EBoxOutputRuleTable>
#
# Returns:
#
#   Array ref of strings containing iptables rules
sub EBoxOutputRuleTable
{
    my ($self) = @_;

    my $model = $self->{'manager'}->model('EBoxOutputRuleTable');
    defined($model) or throw EBox::Exceptions::Internal(
            "Cant' get EBoxOutputRuleTableModel");

    my @rules;
    for my $row (@{$model->rows()}) {
        my $rule = new EBox::Firewall::IptablesRule(
                'table' => 'filter', 'chain' => 'oglobal');
        $rule->setState('new' => 1);
        $self->_addAdddressToRule($rule, $row, 'destination');
        $self->_addServiceToRule($rule, $row);  
        $self->_addDecisionToRule($rule, $row);
        push (@rules, @{$rule->strings()});
    }

    return \@rules;
}

sub _addAdddressToRule
{
    my ($self, $rule, $row, $address) = @_;

    my $addr = $row->elementByName($address);
    my $type = $addr->selectedType();

    my %params;
    if ($type eq $address . '_ipaddr') {
        $params{$address .'Address'} = $addr->subtype();
    } elsif ($type eq $address . '_object') {
        $params{$address . 'Object'} = $addr->value();
    }
    $params{'inverseMatch'} = $addr->inverseMatch();

    if ($address eq 'source') {
        $rule->setSourceAddress(%params);
    } else {
        $rule->setDestinationAddress(%params);
    }
}

sub _addServiceToRule
{
    my ($self, $rule, $row) = @_;

    my $service = $row->elementByName('service');
    $rule->setService($service->value(), $service->inverseMatch());    
}

sub _addDecisionToRule
{
    my ($self, $rule, $row) = @_;

    my $decision = $row->valueByName('decision');
    if ($decision eq 'accept') {
        $rule->setDecision('ACCEPT');    
    } elsif ($decision eq 'deny') {
        $rule->setDecision('drop');    
    } elsif ($decision eq 'log') {
        $rule->setDecision('log');    
    }

}

1;
