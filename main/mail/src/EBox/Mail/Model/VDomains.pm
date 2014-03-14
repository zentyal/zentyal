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

package EBox::Mail::Model::VDomains;

use base 'EBox::Model::DataTable';

# Class: EBox::Mail::Model::VDomains
#
#       This a class used it as a proxy for the vodmains stored in LDAP.
#       It is meant to improve the user experience when managing vdomains,
#       but it's just a interim solution. An integral approach needs to
#       be done.
#
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;

use EBox::Mail::Types::WriteOnceDomain;
use EBox::Types::HasMany;

sub _table
{
    my @tableHead =
        (
         new EBox::Mail::Types::WriteOnceDomain(
             'fieldName' => 'vdomain',
             'printableName' => __('Name'),
             'size' => '20',
             'editable' => 1,
             'unique' => 1,
         ),
         new EBox::Types::HasMany(
             fieldName => 'aliases',
             printableName => __('Virtual domain aliases'),
             foreignModel => 'mail/VDomainAliases',
             'view' => '/Mail/View/VDomainAliases',
             'backView' => '/Mail/View/VDomains',
         ),
         new EBox::Types::HasMany(
             fieldName => 'externalAliases',
             printableName => __('External accounts aliases'),
             foreignModel => 'mail/ExternalAliases',
             'view' => '/Mail/View/ExternalAliases',
             'backView' => '/Mail/View/VDomains',
         ),
         new EBox::Types::HasMany(
                 fieldName => 'settings',
                 printableName => __('Settings'),
                 foreignModel => 'mail/VDomainSettings',
                 'view' => '/Mail/View/VDomainSettings',
                 'backView' => '/Mail/View/VDomains',
         ),
    );

    my $dataTable =
    {
        'tableName' => 'VDomains',
        'printableTableName' => __('List of Domains'),
        'pageTitle'         => __('Virtual Domains'),
        'HTTPUrlView'       => 'Mail/View/VDomains',
        'defaultController' => '/Mail/Controller/VDomains',
        'defaultActions' => ['add', 'del', 'changeView'],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'Mail/VDomains',
        'automaticRemove'  => 1,
        'help' => '',
        'printableRowName' => __('virtual domain'),
        'sortedBy' => 'vdomain',
        'messages' => { add => __('Virtual domain added. ' .
                'You must save changes to use this domain')
        },
    };

    return $dataTable;
}

sub alwaysBccByVDomain
{
    my ($self) = @_;
    my %alwaysBcc;

    my @ids = @{ $self->ids() };
    foreach my $id (@ids) {
        my $row = $self->row($id);
        my $settings = $row->elementByName('settings')->foreignModelInstance();
        my $address  = $settings->bccAddress();
        if ($address) {
            my $vdomain = $row->valueByName('vdomain');
            $alwaysBcc{$vdomain} = $address;
            # add vdomain alias too
            my $vdomainAlias = $row->elementByName('aliases')->foreignModelInstance();
            my @aliases = @{ $vdomainAlias->aliases() };
            foreach my $alias (@aliases) {
                $alwaysBcc{$alias} = $address;
            }
        }
    }

    return \%alwaysBcc;
}

sub alwaysBcc
{
    my ($self) = @_;
    my %alwaysBcc;

    my @ids = @{ $self->ids() };
    foreach my $id (@ids) {
        my $row = $self->row($id);
        my $settings = $row->elementByName('settings')->foreignModelInstance();
        my $address  = $settings->bccAddress();
        if ($address) {
            return 1;
        }
    }

    return 0;
}

sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (not exists $changedFields->{vdomain}) {
        return;
    }

    my $vdomain = $changedFields->{vdomain}->value();
    if ($self->existsVDomainAlias($vdomain)) {
        throw EBox::Exceptions::External(
__x(
'Cannot add virtual domain {vd} because is a virtual domain alias' .
    ' with the same name',
   vd => $vdomain)
                                        );
    }

    $self->_checkVDomainIsNotInExternalAliases($vdomain);

    if ($vdomain eq 'sieve') {
        throw EBox::Exceptions::External( __(
q{'sieve' is a reserved name in this context, please choose another name}
                                            ));
    }

    my $mailname = EBox::Global->modInstance('mail')->mailname;
    if ($vdomain eq $mailname) {
            throw EBox::Exceptions::InvalidData(
                               data => __('Mail virtual domain'),
                               value => $vdomain,
                               advice =>
__('The virtual domain name cannot be equal to the mailname')
                                           );
    }
}

sub validateRowRemoval
{
    my ($self, $row, $force) = @_;
    my $vdomain = $row->valueByName('vdomain');
    my $vdomainsLdap = $self->parentModule()->{vdomains};
    $vdomainsLdap->validateDelVDomain($vdomain);
}

sub existsVDomain
{
    my ($self, $vdomain) = @_;

    my $res = $self->findValue(vdomain => $vdomain);
    return defined $res;
}

sub existsVDomainAlias
{
    my ($self, $alias) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $vdomainAlias = $row->elementByName('aliases')->foreignModelInstance();
        if ($vdomainAlias->existsAlias($alias)) {
            return 1;
        }
    }

    return undef;
}

sub _checkVDomainIsNotInExternalAliases
{
    my ($self, $vdomain) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        my $externalAliases = $row->elementByName('externalAliases')->foreignModelInstance();
        my $alias = $externalAliases->firstAliasForExternalVDomain($vdomain);
        if ($alias) {
            throw EBox::Exceptions::External(
                                             __x(
'Cannot add virtual domain {vd} because it appears as external domain' .
' in the account referenced by the alias {al}',
vd => $vdomain, al => $alias
                                                )
                                            );

        }
    }
}

1;
