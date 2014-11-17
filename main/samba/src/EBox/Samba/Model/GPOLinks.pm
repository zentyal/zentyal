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
        defaultActions => [ 'add', 'delete' ],
        #TODO help =>  __(''),
    };
}

sub rootNodes
{
    my ($self) = @_;

    my $ldap = $self->parentModule->ldap();
    my $rootDSE = $ldap->rootDse();
    my $rootNC = $rootDSE->get_value('rootDomainNamingContext');
    my $rootDomain = join ('.', grep (/.+/, split (/[,]?DC=/, $rootNC)));

    return [ { printableName => __x('Forest: {x}', x => $rootDomain),
               type => 'forest' } ];
}

sub _domainList
{
    my ($self) = @_;

    my $domainList = [];
    my $ldap = $self->parentModule->ldap();
    my $rootDSE = $ldap->rootDse();
    my $configurationNC = $rootDSE->get_value('ConfigurationNamingContext');

    my $result = $ldap->search({
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
        push (@{$domainList}, { metadata => { dn => $domainNC },
                                printableName => $domainDnsRoot,
                                type => 'domain' });
    }
    return $domainList;
}

sub _siteList
{
    my ($self) = @_;

    my $siteList = [];
    my $ldap = $self->parentModule->ldap();
    my $rootDSE = $ldap->rootDse();
    my $configurationNC = $rootDSE->get_value('ConfigurationNamingContext');

    my $result = $ldap->search({
        base => "CN=Sites,$configurationNC",
        scope => 'one',
        filter => "(objectCategory=CN=Site,CN=Schema,$configurationNC)",
        attrs => ['name']});
    foreach my $entry ($result->entries()) {
        push (@{$siteList}, { metadata => { dn => $entry->dn() },
                              printableName => $entry->get_value('name'),
                              type => 'site' });
    }
    return $siteList;
}

sub _som
{
    my ($self, $dn) = @_;

    my $somList = [];
    my $ldap = $self->parentModule->ldap();
    my $rootDSE = $ldap->rootDse();
    my $configurationNC = $rootDSE->get_value('ConfigurationNamingContext');

    # Query domain OUs
    my $result = $ldap->search({
        base => $dn,
        scope => 'one',
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
        push (@{$somList}, { metadata => { dn => $dn },
                             printableName => $name,
                             type => 'ou' });
    }
    return $somList;
}

sub _gpLinks
{
    my ($self, $dn) = @_;

    my $gpLinks = [];

# TODO If GPO has been removed and there is a link to a non existant GPO do not die
    my $ldap = $self->parentModule->ldap();
    my $result = $ldap->search({
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
        my $index = 1;
        foreach my $link (reverse @gpLink) {
            my ($gpoDN, $gpLinkOptions) = split (/;/, $link);
            $gpoDN =~ s/ldap:\/\///ig;
            # Query GPO name
            my $gpo = new EBox::Samba::GPO(dn => $gpoDN);
            next unless ($gpo->exists());

            my $gpoDisplayName = $gpo->get('displayName');
            my $enforced = ($gpLinkOptions & EBox::Samba::GPO::LINK_ENFORCED());
            my $linkEnabled = not ($gpLinkOptions & EBox::Samba::GPO::LINK_DISABLED());
            push (@{$gpLinks}, { metadata => { containerDN => $dn,
                                               linkIndex => $index,
                                               gpoDisplayName => $gpoDisplayName,
                                               linkEnabled => $linkEnabled,
                                               enforced => $enforced,
                                               gpoDN => $gpoDN, },
                                 printableName => "$index: $gpoDisplayName",
                                 type => 'gpLink' });
            $index++;
        }
    }

    return $gpLinks;
}

sub defaultActionLabels
{
    return {
        'add' => __('Add new Group Policy Link'),
        'delete' => __('Delete Group Policy Link'),
        'edit' => __('Edit Group Policy Link'),
    };
}

sub childNodes
{
    my ($self, $parentType, $parentMetadata) = @_;

    my $childNodes = [];
    if ($parentType eq 'forest') {
        push (@{$childNodes}, { printableName => __('Domains'), type => 'domainList' });
        push (@{$childNodes}, { printableName => __('Sites'), type => 'siteList' });
    } elsif ($parentType eq 'domainList') {
        push (@{$childNodes}, @{$self->_domainList()});
    } elsif ($parentType eq 'siteList') {
        push (@{$childNodes}, @{$self->_siteList()});
    } elsif ($parentType eq 'domain') {
        my $domainDN = $parentMetadata->{dn};
        push (@{$childNodes}, @{$self->_gpLinks($domainDN)});
        push (@{$childNodes}, @{$self->_som($domainDN)});
    } elsif ($parentType eq 'ou') {
        my $containerDN = $parentMetadata->{dn};
        push (@{$childNodes}, @{$self->_gpLinks($containerDN)});
        push (@{$childNodes}, @{$self->_som($containerDN)});
    } elsif ($parentType eq 'site') {
        my $containerDN = $parentMetadata->{dn};
        push (@{$childNodes}, @{$self->_gpLinks($containerDN)});
    }
    return $childNodes;
}

sub nodeTypes
{
    return {
        forest      => { actions => { filter => 0, add => 0, edit => 0, delete => 0 }, actionObjects => {} },
        domainList  => { actions => { filter => 0, add => 0, edit => 0, delete => 0 }, actionObjects => {}, defaultIcon => 1 },
        siteList    => { actions => { filter => 0, add => 0, edit => 0, delete => 0 }, actionObjects => {}, defaultIcon => 1 },
        domain      => { actions => { filter => 0, add => 1, edit => 0, delete => 0 }, actionObjects => { add => 'GPLink' } },
        ou          => { actions => { filter => 0, add => 1, edit => 0, delete => 0 }, actionObjects => { add => 'GPLink' }, defaultIcon => 1 },
        site        => { actions => { filter => 0, add => 1, edit => 0, delete => 0 }, actionObjects => { add => 'GPLink' } },
        gpLink      => { actions => { filter => 0, add => 0, edit => 1, delete => 1 }, actionObjects => { edit => 'GPLink', delete => 'GPLink' } },
    };
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

    unless ($self->parentModule->configured()) {
        $self->{preconditionFail} = 'notConfigured';
        return undef;
    }

    unless ($self->parentModule->isEnabled()) {
        $self->{preconditionFail} = 'notEnabled';
        return undef;
    }

    unless ($self->parentModule->isProvisioned()) {
        $self->{preconditionFail} = 'notProvisioned';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Check if the module is configured
#
# Overrides:
#
#   <EBox::Model::Model::preconditionFailMsg>
#
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notConfigured' or
        $self->{preconditionFail} eq 'notEnabled') {
        return __('You must enable the File Sharing module in the module ' .
                'status section in order to use it.');
    }
    if ($self->{preconditionFail} eq 'notProvisioned') {
        return __('The domain has not been created yet.');
    }
}

1;
