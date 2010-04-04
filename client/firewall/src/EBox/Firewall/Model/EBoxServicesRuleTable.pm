# Copyright (C) 2010 eBox Technologies S.L.
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
package EBox::Firewall::Model::EBoxServicesRuleTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Iptables;

use strict;
use warnings;

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

    my $gconf = $self->{'gconfmodule'};
    # If the GConf module is readonly, return current rows
    if ( $gconf->isReadOnly() ) {
        return undef;
    }

    my $modIsChanged = EBox::Global->getInstance()->modIsChanged('firewall');
    my $iptables = new EBox::Iptables();

    my %newRules = map { $_->{'rule'} => $_ } @{$iptables->moduleRules()};

    my %currentRules =
        map { $self->row($_)->valueByName('rule') => $_ } @{$currentRows};

    my $modified = 0;

    my @rulesToAdd = grep { not exists $currentRules{$_} } keys %newRules;
    my @rulesToDel = grep { not exists $newRules{$_} } keys %currentRules;

    foreach my $rule (@rulesToAdd) {
        my $module = $newRules{$rule}->{'module'}->{'printableName'};
        my ($table, $chain, $condition, $decision) =
            $rule =~ /-t ([a-z]+) -A ([a-z]+) (.*) -j (.*)/;
        my $type = $RULE_TYPES{$chain};
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

    if ($modified and not $modIsChanged) {
        $gconf->_saveConfig();
        EBox::Global->getInstance()->modRestarted('firewall');
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
          __('Rules added by eBox services (Advanced)'),
        'automaticRemove' => 1,
        'sortedBy' => 'type',
        'defaultController' =>
            '/ebox/Firewall/Controller/EBoxServicesRuleTable',
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
                title => __d('Packet Filter', 'ebox-firewall'),
                link  => '/ebox/Firewall/Filter',
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
    return __d('Configure Rules', 'ebox-firewall');
}

1;
