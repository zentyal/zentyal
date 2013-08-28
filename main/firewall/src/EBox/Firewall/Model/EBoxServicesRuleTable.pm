# Copyright (C) 2010-2013 Zentyal S.L.
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

# Class: EBox::Firewall::Model::EBoxServicesRuleTable
#
# This class is used for enable or disable the rules automatically
# added by the eBox services implementing FirewallHelper.
#
use strict;
use warnings;

package EBox::Firewall::Model::EBoxServicesRuleTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Iptables;

use base 'EBox::Model::DataTable';

my %RULE_TYPES = ('imodules' => __('Input'),
                  'iexternalmodules' => __('External Input'),
                  'omodules' => __('Output'),
                  'fmodules' => __('Forward'),
                  'premodules' => __('NAT prerouting'),
                  'postmodules' => __('NAT postrouting'));

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $iptables = new EBox::Iptables();

    my %newRules = map { $_->{'rule'} => $_ } @{$iptables->moduleRules()};
    my %currentRules =
        map { $self->row($_)->valueByName('rule') => $_ } @{$currentRows};

    my $modified = 0;

    my @rulesToAdd = grep { not exists $currentRules{$_} } keys %newRules;
    my @rulesToDel = grep { not exists $newRules{$_} } keys %currentRules;

    foreach my $rule (@rulesToAdd) {
        my $module = $newRules{$rule}->{'module'}->{'printableName'};

        my ($table, $chain, $condition, $decision, $type);
        if ($rule =~ m/(-A|-I)/) {
            my ($action) = $rule =~ m/(-A|-I)/;
            # common firewall rule
            ($table, $chain, $condition, $decision) =
                $rule =~ /-t ([a-z]+) $action ([a-z]+) (.*) -j (.*)/;

            if (defined($RULE_TYPES{$chain})) {
                $type = $RULE_TYPES{$chain};
            } else {
                $type = $chain;
            }
        } else {
            ($table, $chain) = $rule =~ /-t ([a-z]+) -N ([a-z]+)/;
            $condition = '';
            $decision = $chain;
            $type = __('Chain creation');
        }

        $self->add(rule => $rule,
                   type => $type,
                   module => $module,
                   condition => $condition,
                   decision => $decision,
                   );
        $modified = 1;
    }

    foreach my $rule (@rulesToDel) {
        my $id = $currentRules{$rule};
        my $row = $self->row($id);
        $self->removeRow($id, 1);
        $modified = 1;
    }

    return $modified;
}

sub _table
{
    my ($self) = @_;

    my @tableHeader = (
        new EBox::Types::Text(
            'fieldName' => 'rule',
            'printableName' => __('Rule'),
            'hidden' => 1
        ),
        new EBox::Types::Boolean (
            'fieldName' => 'enabled',
            'printableName' => __('Enabled'),
            'defaultValue' => 1,
            'editable' => 1
        ),
        new EBox::Types::Text(
            'fieldName' => 'type',
            'printableName' => __('Type'),
            'editable' => 0
        ),
        new EBox::Types::Text(
            'fieldName' => 'module',
            'printableName' => __('Module'),
            'editable' => 0
        ),
        new EBox::Types::Text(
            'fieldName' => 'condition',
            'printableName' => __('Condition'),
            'editable' => 0
        ),
        new EBox::Types::Text(
            'fieldName' => 'decision',
            'printableName' => __('Decision'),
            'editable' => 0
        ),
    );

    my $dataTable =
    {
        'tableName' => 'EBoxServicesRuleTable',
        'printableTableName' =>
          __('Rules added by Zentyal services (Advanced)'),
        'automaticRemove' => 1,
        'sortedBy' => 'type',
        'defaultController' =>
            '/Firewall/Controller/EBoxServicesRuleTable',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHeader,
        'menuNamespace' => 'Firewall/View/EBoxServicesRuleTable',
        'printableRowName' => __('rule'),
    };

    return $dataTable;
}

# Method: viewCustomizer
#
#    Overrides <EBox::Model::DataTable::viewCustomizer>
#    to show breadcrumbs
#
sub viewCustomizer
{
        my ($self) = @_;

        my $custom =  $self->SUPER::viewCustomizer();
        $custom->setHTMLTitle([
                {
                title => __('Packet Filter'),
                link  => '/Firewall/Filter',
                },
                {
                title => $self->printableName(),
                link  => ''
                }
        ]);

        return $custom;
}

sub headTitle
{
    return __('Configure Rules');
}

sub permanentMessage
{
    return __('You can disable these rules, but make sure you know what you are doing or otherwise some services could stop working.');
}

sub permanentMessageType
{
    return 'warning';
}

1;
