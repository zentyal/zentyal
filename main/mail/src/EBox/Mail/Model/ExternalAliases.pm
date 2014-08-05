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
use strict;
use warnings;

package EBox::Mail::Model::ExternalAliases;

use base 'EBox::Model::DataTable';

# Class: EBox::Mail::Model::ExternalAliases
#
#       This a class used it as a proxy for the external acounts aliases stored in LDAP.
#
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::MailAddress;
use EBox::Types::Text;
use EBox::Types::Select;

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
    my ($self) = @_;

    my @tableHead =
         (
          new EBox::Types::Text(
                                       'fieldName' => 'alias',
                                       'printableName' => __('Alias'),
                                       'size' => '30',
                                       'editable' => 1,
                                       'unique' => 1,
                                      ),
          new EBox::Types::Select(
                                       'fieldName' => 'vdomain',
                                       'printableName' => __('Domain'),
                                       'editable' => 1,
                                       'populate' => $self->_vdomainOptionsSub(),
                                       'disableCache' => 1, # otherwise this will not reflect
                                                            # changes in vdomain aliases
                                 ),
          new EBox::Types::MailAddress(
                                       'fieldName' => 'externalAccount',
                                       'printableName' => __('External account'),
                                       'size' => '30',
                                       'editable' => 1,
                                      ),

         );

    my $dataTable =
                {
                        'tableName' => 'ExternalAliases',
                        'printableTableName' => __('External Aliases'),
                        'defaultController' =>
            '/Mail/Controller/ExternalAliases',
                        'defaultActions' =>
                                ['add', 'del', 'changeView', 'editField'],
                        'tableDescription' => \@tableHead,
#                        'menuNamespace' => 'Mail/ExternalAliases',
                        'automaticRemove'  => 1,
                        'help' => '',
                        'printableRowName' => __('External account alias'),
                        'sortedBy' => 'alias',
                        'messages' => { add => __('External account alias added. ' .
                                'You must save changes to use this alias')
                            },

                };

    return $dataTable;
}

sub _vdomainOptionsSub
{
    my ($self) = @_;
    return sub {
        my $vdomain = $self->_realVdomain();
        my @options;
        push @options, {
            value => $vdomain,
            printableValue => $vdomain,
        };

        my $aliasesModel = $self->parentModule()->model('VDomainAliases');
        push @options, map {
            my $alias = $_;
            {
                value => $alias,
                printableValue => __x('{alias} (alias)', alias => $alias)
            }
        } @{ $aliasesModel->aliases()  };

        return \@options;
    };
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (exists $changedFields->{alias} or exists $changedFields->{vdomain}) {
        my $alias = $allFields->{alias}->value();
        my $vdomain = $allFields->{vdomain}->value();
        my $fullAlias = $alias . '@' . $vdomain;

        $self->parentModule()->checkMailNotInUse($fullAlias);
        $self->_checkAliasIsInternal($fullAlias);
    }

    if (exists $changedFields->{externalAccount}) {
        $self->_checkExternalAccountIsExternal(
                       $changedFields->{externalAccount}->value()
                                              );
    }
}

sub _checkAliasIsInternal
{
    my ($self, $alias) = @_;
    my ($left, $vdomain) = split '@', $alias, 2;
    my $vdomains = $self->parentModule()->model('VDomains');
    if ($vdomains->existsVDomain($vdomain)) {
        return 1;
    }
    if ($vdomains->existsVDomainAlias($vdomain)) {
        return 1;
    }

    # neither local vdomain nor alias domain
    throw EBox::Exceptions::External(
__x('Cannot add alias because domain {vd} is not a virtual domain or virtual domain alias managed by this server',
   vd => $vdomain)
);
}

sub _checkExternalAccountIsExternal
{
    my ($self, $external) = @_;
    my ($left, $vdomain) = split '@', $external, 2;
    my $vdomains = $self->parentModule()->model('VDomains');
    if ($vdomains->existsVDomain($vdomain) or
        $vdomains->existsVDomainAlias($vdomain) ) {
        throw EBox::Exceptions::External(
            __x('{ac} is not an external account', ac => $external)
           );
    }
}

sub _realVdomain
{
    my ($self) = @_;
    my $parentRow = $self->parentRow();
    my $vdomain =$parentRow->valueByName('vdomain');
    return $vdomain;
}

# this do clenaup of all aliases with orphaned vdomain alias, not just those of
# the removed vdomain
sub vdomainAliasRemoved
{
    my ($self, $vdomainId) = @_;
    my @idsToRemove;
    my @ids = @{ $self->ids() };
    foreach my $id (@ids) {
        my $row = $self->row($id);
        if (not $row->elementByName('vdomain')->printableValue()) {
            push @idsToRemove, $id;
        }
    }

    foreach my $id (@idsToRemove) {
        $self->removeRow($id, 1);
    }
}

sub firstAliasForExternalVDomain
{
    my ($self, $vdomain) = @_;

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $externalAccount = $row->elementByName('externalAccount')->value();
        my ($left, $externalVDomain) = split '@', $externalAccount, 2;
        if ($vdomain eq $externalVDomain) {
            my $left =  $row->valueByName('alias');
            my $right = $row->valueByName('vdomain');
            return "$left\@$right";
        }

    }

    return undef;
}

sub aliasesAndExternalAccounts
{
    my ($self) = @_;

    my @aliases;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $alias     = $row->valueByName('alias');
        my $vdomain   = $row->valueByName('vdomain');
        my $account   = $row->valueByName('externalAccount');
        my $fullAlias = "$alias\@$vdomain";

        push @aliases, [  $fullAlias => $account ];
    }

    return \@aliases;
}

# Method: precondition
#
#       Check if the module is configured
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
sub precondition
{
    my ($self) = @_;
    my $mail = $self->parentModule();
    return $mail->configured();
}

# Method: preconditionFailMsg
#
#       Check if the module is configured
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
sub preconditionFailMsg
{
    return __('You must enable the mail module in module ' .
                  'status section in order to use it.');
}

# Method: pageTitle
#
# Overrides:
#
#      <EBox::Model::DataTable::pageTitle>
#
sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('vdomain');
}

sub aliasInUse
{
    my ($self, $addr) = @_;
    my ($alias, $vdomain) = split '@', $addr, 2;
    foreach my $id (@{ $self->ids()} ) {
        my $row = $self->row($id);
        if (($alias eq $row->valueByName('alias')) and ($vdomain eq $row->valueByName('vdomain')) ) {
            return 1;
        }
    }

    return 0;
}

1;

