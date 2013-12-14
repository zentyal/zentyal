# Copyright (C) 2009-2013 Zentyal S.L.
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

# Class: EBox::Mail::Model::VDomainAliases
#
#       This a class used it as a proxy for the vodmain aliases stored in LDAP.
#       It is meant to improve the user experience when managing vdomains,
#       but it's just a interim solution. An integral approach needs to
#       be done.
#
package EBox::Mail::Model::VDomainAliases;

use base 'EBox::Model::DataTable';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Mail::Types::WriteOnceDomain;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
        my @tableHead =
         (

                new EBox::Mail::Types::WriteOnceDomain(
                                        'fieldName' => 'alias',
                                        'printableName' => __('Aliases'),
                                        'size' => '20',
                                        'editable' => 1,
                                        'unique' => 1,
                                      ),

         );

        my $dataTable =
                {
                        'tableName' => 'VDomainAliases',
                        'printableTableName' => __('List of Aliases'),
                        'defaultController' =>
            '/Mail/Controller/VDomainAliases',
                        'defaultActions' =>
                                ['add', 'del', 'changeView'],
                        'tableDescription' => \@tableHead,
                        'automaticRemove'  => 1,
                        'help' => '',
                        'printableRowName' => __('virtual domain alias'),
                        'sortedBy' => 'alias',
                        'messages' => { add => __('Virtual domain alias added. ' .
                                'You must save changes to use this domain')
                            },
                };

        return $dataTable;
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (not exists $changedFields->{alias}) {
        return;
    }
    my $alias = $changedFields->{alias}->value();

    my $existsVDomain = $self->parent()->existsVDomain($alias);
    if ($existsVDomain) {
        throw EBox::Exceptions::External(
            __x('Cannot add {al} alias because there is already a virtual domain with the same name',
                al => $alias)
           );
    }

    my $existsAliasSub = sub {
        my ($brother) = @_;
        return $brother->existsAlias($alias);
    };
    my $existsAlias = $self->executeOnBrothers($existsAliasSub, subModelField => 'aliases', returnFirst => 1);
    if ($existsAlias) {
        throw EBox::Exceptions::External(
                __x('Cannot add alias {al} because it is already an identical alias for another virtual domain',
                    al => $alias)
               );
    }
}

sub deletedRowNotify
{
    my ($self, $row, $force) = @_;
    # remove vdomain alias external accoutn aliases
    my $vdomainAliasId = $row->id();
    $self->parentModule()->model('ExternalAliases')->vdomainAliasRemoved($vdomainAliasId);

}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
        my ($self) = @_;
        return $self->parentRow()->printableValueByName('vdomain');
}

sub existsAlias
{
    my ($self, $alias) = @_;
    my $res = $self->findValue(alias => $alias);
    return defined $res;
}

sub aliases
{
    my ($self) = @_;
    my @aliases;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $alias = $row->valueByName('alias');
        push @aliases, $alias;
    }

    return \@aliases;
}

1;

