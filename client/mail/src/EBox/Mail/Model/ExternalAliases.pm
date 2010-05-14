# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::Mail::Model::ExternalAliases;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

# Class: EBox::Mail::Model::ExternalAliases
#
#       This a class used it as a proxy for the extermla cooutns alaises stored in LDAP.
#
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;

use EBox::Types::MailAddress;
use EBox::Types::Text;



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
          new EBox::Types::Text(
                                       'fieldName' => 'alias',
                                       'printableName' => __('Alias'),
                                       'size' => '30',
                                       'editable' => 1,
                                       'unique' => 1,
                                       'filter' => \&_fullAlias,
                                       'help' =>
        __('The mail domain is appended automatically'),
                                      ),
          new EBox::Types::MailAddress(
                                       'fieldName' => 'externalAccount',
                                       'printableName' => __('External account'),
                                       'size' => '30',
                                       'editable' => 1,
#                                       'unique' => 1,
                                      ),


         );

        my $dataTable =
                {
                        'tableName' => 'ExternalAliases',
                        'printableTableName' => __('External Aliases'),
                        'defaultController' =>
            '/ebox/Mail/Controller/ExternalAliases',
                        'defaultActions' =>
                                ['add', 'del', 'changeView'],
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


sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (exists $changedFields->{alias}) {
        my $alias = $changedFields->{alias}->value();
        $alias = $self->_completeAliasAddress($alias);
        $self->_checkAliasIsNotAccount($alias);
        $self->_checkAliasIsInternal($alias);
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
    my $vdomains = EBox::Global->modInstance('mail')->model('VDomains');
    if ($vdomains->existsVDomain($vdomain)) {
        # correct!
        return 1;
    }

    if ($vdomains->existsVDomainAlias($vdomain)) {
        throw EBox::Exceptions::External(
__x('Cannot add alias because domain {vd} is a alias and aliases belonging to virtual domain aliases are not supported. Please add the alias belonging to a real domain',
   vd => $vdomain)
);
    }

    # neither local vdomain nor alias domain
    throw EBox::Exceptions::External(
__x('Cannot add alias because domain {vd} is not a virtual domain managed by this server',
   vd => $vdomain)
);
}


sub _checkAliasIsNotAccount
{
    my ($self, $alias) = @_;
    my $mailAlias = EBox::Global->modInstance('mail')->{malias};
    if ($mailAlias->accountExists($alias)) {
        throw EBox::Exceptions::External(
      __x('They already exists an account or alias called {al}',
          al => $alias
         )
                                        );
    }

}


sub _checkExternalAccountIsExternal
{
    my ($self, $external) = @_;
    my ($left, $vdomain) = split '@', $external, 2;
}

sub _completeAliasAddress
{
    my ($self, $alias) = @_;

    if ($alias =~ m/\@/) {
        throw EBox::Exceptions::External(
__('The alias account should be provided without domain portion. It will be appended automatically')
                                        );
    }

    my $vdomain = $self->_vdomain();
    return $alias . '@' . $vdomain;


}

sub _vdomain
{
    my ($self) = @_;
    my $parentRow = $self->parentRow();
    my $vdomain =$parentRow->valueByName('vdomain');
    return $vdomain;
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
            my $right = $self->_vdomain();
            return "$left\@$right";
        }

    }

    return undef;
}


sub aliasesAndExternalAccounts
{
    my ($self) = @_;

    my $vdomain = $self->_vdomain();
    my @aliases;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $alias     = $row->valueByName('alias');
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
        my $mail = EBox::Global->modInstance('mail');
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

    return $self->parentRow()->printableValueByName('vdomain');

}

sub _fullAlias
{
    my ($type) = @_;
    my $value = $type->value();
    my $row = $type->row();
    if (not $row) {
        return $value;
    }

    my $model = $row->model();
    my $domain = $model->_vdomain();

    return $value . '@' . $domain;
    

}


1;

