# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Samba::Model::GPOLinks;

use base 'EBox::Model::TreeView';

use EBox::Gettext;
use EBox::Types::Action;
use Encode qw(encode decode);

sub _tree
{
    my ($self) = @_;

    return {
        treeName => 'GPOLinks',
        modelDomain => 'Samba',
        pageTitle => __('Group Policy Links'),
        defaultActions => [ 'add', 'edit', 'delete' ],
        idParam => 'dn',
        #TODO help =>  __(''),
    };
}

sub rootNodes
{
    my ($self) = @_;

    my $ldb = $self->parentModule->ldb();
    my $rootDSE = $ldb->rootDse();
    my $rootNC = $rootDSE->get_value('rootDomainNamingContext');
    my $rootDomain = join ('.', grep (/.+/, split (/[,]?DC=/, $rootNC)));

    return [ { id => 'root',
               printableName => __x('Forest: {x}', x => $rootDomain),
               type => 'forest' } ];
}

sub _domainList
{
    my ($self) = @_;

    my $domainList = [];
    my $ldb = $self->parentModule->ldb();
    my $rootDSE = $ldb->rootDse();
    my $configurationNC = $rootDSE->get_value('ConfigurationNamingContext');

    my $result = $ldb->search({
        base => "CN=Partitions,$configurationNC",
        scope => 'one',
        filter => '(NETBIOSName=*)',
        attrs => ['dnsRoot', 'nCName']});
    foreach my $entry ($result->entries()) {
        my $domainNC = $entry->get_value('nCName');
        my $dn = $entry->dn();
        unless (defined $domainNC) {
            EBox::error("Can not retrieve domain naming context from $dn");
            next;
        }
        my $domainDnsRoot = $entry->get_value('dnsRoot');
        unless (defined $domainDnsRoot) {
            EBox::error("Can not retrieve domain dns root from $dn");
            next;
        }
        push (@{$domainList}, { id => $domainNC,
                                printableName => $domainDnsRoot,
                                type => 'domain' });
    }
    return $domainList;
}

sub _siteList
{
    my ($self) = @_;

    my $siteList = [];
    my $ldb = $self->parentModule->ldb();
    my $rootDSE = $ldb->rootDse();
    my $configurationNC = $rootDSE->get_value('ConfigurationNamingContext');

    my $result = $ldb->search({
        base => "CN=Sites,$configurationNC",
        scope => 'one',
        filter => "(objectCategory=CN=Site,CN=Schema,$configurationNC)",
        attrs => ['name']});
    foreach my $entry ($result->entries()) {
        push (@{$siteList}, { id => $entry->dn(),
                                printableName => $entry->get_value('name'),
                                type => 'site' });
    }
    return $siteList;
}

sub _som
{
    my ($self, $dn) = @_;

    my $somList = [];
    my $ldb = $self->parentModule->ldb();
    my $rootDSE = $ldb->rootDse();
    my $configurationNC = $rootDSE->get_value('ConfigurationNamingContext');

    # Query domain OUs
    my $result = $ldb->search({
        base => $dn,
        scope => 'sub',
        filter => "(objectCategory=CN=Organizational-Unit," .
                  "CN=Schema,$configurationNC)",
        attrs => ['name']});
    foreach my $entry ($result->entries()) {
        my $name = $entry->get_value('name');
        my $dn = $entry->dn();
        unless (defined $name) {
            EBox::error("Can not retrieve OU name from $dn");
            next;
        }
        push (@{$somList}, { id => $dn,
                             printableName => $name,
                             type => 'ou' });
    }
    return $somList;
}

sub _gpLinks
{
    my ($self, $dn) = @_;

    my $gpLinks = [];

    my $ldb = $self->parentModule->ldb();
    my $result = $ldb->search({
        base => $dn,
        scope => 'base',
        filter => '(objectClass=*)',
        attrs => ['gpLink', 'gpOptions']});
    my $entry = $result->entry(0);
    my $gpLink = $entry->get_value('gpLink');
    my $gpOptions = $entry->get_value('gpOptions');
    if (defined $gpLink) {
        $gpLink = decode ('UTF-8', $gpLink);
        my @gpLink = ($gpLink =~ /\[([^\[\]]+)\]/g);
        foreach my $link (@gpLink) {
            my ($gpoDN, $gpLinkOptions) = split (/;/, $link);
            $gpoDN =~ s/ldap:\/\///ig;
            # Query GPO name
            my $gpoResult = $ldb->search({
                base => $gpoDN,
                scope => 'base',
                filter => '(objectClass=*)',
                attrs => ['displayName']});
            my $gpoEntry = $gpoResult->entry(0);
            my $gpoDisplayName = $gpoEntry->get_value('displayName');
            push (@{$gpLinks}, { id => $dn,
                                 printableName => $gpoDisplayName,
                                 type => 'gpLink'});
        }
    }

    return $gpLinks;
}

sub childNodes
{
    my ($self, $parent, $type) = @_;

    my $childNodes = [];
    if ($type eq 'forest') {
        push (@{$childNodes}, { id => 'domainList', printableName => __('Domains'), type => 'domainList' });
        push (@{$childNodes}, { id => 'siteList', printableName => __('Sites'), type => 'siteList' });
    } elsif ($type eq 'domainList') {
        push (@{$childNodes}, @{$self->_domainList()});
    } elsif ($type eq 'siteList') {
        push (@{$childNodes}, @{$self->_siteList()});
    } elsif ($type eq 'domain') {
        push (@{$childNodes}, @{$self->_gpLinks($parent)});
        push (@{$childNodes}, @{$self->_som($parent)});
    } elsif ($type eq 'ou') {
        push (@{$childNodes}, @{$self->_gpLinks($parent)});
    } elsif ($type eq 'site') {
        push (@{$childNodes}, @{$self->_gpLinks($parent)});
    }
    return $childNodes;
}

sub nodeTypes
{
    return {
        forest      => { actions => { filter => 0, add => 0, edit => 0, delete => 0 }, actionObjects => {} },
        domainList  => { actions => { filter => 0, add => 0, edit => 0, delete => 0 }, actionObjects => {} },
        siteList    => { actions => { filter => 0, add => 0, edit => 0, delete => 0 }, actionObjects => {} },
        domain      => { actions => { filter => 0, add => 1, edit => 0, delete => 0 }, actionObjects => { add => 'GPLink' } },
        ou          => { actions => { filter => 0, add => 1, edit => 0, delete => 0 }, actionObjects => { add => 'GPLink' } },
        site        => { actions => { filter => 0, add => 1, edit => 0, delete => 0 }, actionObjects => { add => 'GPLink' } },
        gpLink      => { actions => { filter => 0, add => 0, edit => 1, delete => 1 }, actionObjects => {} },
    };
}

sub doubleClickHandlerJS
{
    my ($self, $type, $id) = @_;

    $self->actionHandlerJS('edit', $type, $id);
}

# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::Base::precondition>
#
sub precondition
{
    my ($self) = @_;

    return $self->parentModule->configured();
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::Model::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    return __('You must enable the Samba module in the module status ' .
              'section in order to use it.');
}

1;
