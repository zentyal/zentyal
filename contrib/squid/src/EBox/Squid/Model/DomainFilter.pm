# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Squid::Model::DomainFilter;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Validate;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;

sub _tableHeader
{
    my @tableHeader = (
            new EBox::Types::Text(
                fieldName     => 'domain',
                printableName => __('Domain or URL'),
                unique        => 1,
                editable      => 1,
                optional      => 0,
            ),
            new EBox::Types::Select(
                fieldName     => 'policy',
                printableName => __('Decision'),
                populate      => \&_populate,
                editable      => 1,
            ),
    );

    return \@tableHeader;
}

sub _populate
{
    my @elements = (
                    { value => 'allow',  printableValue => __('Allow') },
                    { value => 'deny',   printableValue => __('Deny') },
                   );

    return \@elements;
}

sub validateTypedRow
{
    my ($self, $action, $params_r) = @_;

    return unless (exists $params_r->{domain});

    my $domain = $params_r->{domain}->value();
    if ($domain =~ m{/}) {
        # treat as url
        $self->_validateUrl($domain);
    } else {
        $self->_validateDomain($domain);
    }
}

sub _validateUrl
{
    my ($self, $url) = @_;
    my ($domain, $dir) = split '/', $url, 2;
    $dir = '/' . $dir;

    EBox::Validate::checkDomainName($domain,
                                    __('Domain or IP address part of URL')
                                   );
}

sub _validateDomain
{
    my ($self, $domain) = @_;

    if ($domain =~ m{^www\.}) {
        throw EBox::Exceptions::InvalidData(
                data => __('Domain'),
                value => $domain,
                advice => __('You must not prefix the domain with www.'),
         );
    }

    EBox::Validate::checkDomainName($domain, __('Domain or IP address'));
}

# Function: banned
#
#       Fetch the banned domains
#
# Returns:
#
#       Array ref - containing the domains
sub banned
{
    my ($self) = @_;
    return $self->_domainsByPolicy('deny');
}

# Function: allowed
#
#       Fetch the allowed domains
#
# Returns:
#
#       Array ref - containing the domains
sub allowed
{
    my ($self) = @_;
    return $self->_domainsByPolicy('allow');
}

# Function: filtered
#
#       Fetch the filtered domains
#
# Returns:
#
#       Array ref - containing the domains
sub filtered
{
    my ($self) = @_;
    return $self->_domainsByPolicy('filter');
}

# Function: bannedUrls
#
#       Fetch the banned urls
#
# Returns:
#
#       Array ref - containing the urls
sub bannedUrls
{
    my ($self) = @_;
    return $self->_urlsByPolicy('deny');
}

# Function: allowedUrls
#
#       Fetch the allowed urls
#
# Returns:
#
#       Array ref - containing the urls
sub allowedUrls
{
    my ($self) = @_;
    return $self->_urlsByPolicy('allow');
}

# Function: filteredUrls
#
#       Fetch the filtered urls
#
# Returns:
#
#       Array ref - containing the urls
sub filteredUrls
{
    my ($self) = @_;
    return $self->_urlsByPolicy('filter');
}

sub _domainsByPolicy
{
    my ($self, $policy) = @_;

    my @domains;
    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $domain = $row->valueByName('domain');
        if ($domain =~ m{/}) {
            next;
        }

        if ($row->valueByName('policy') eq $policy) {
            push (@domains,  $domain);
        }
    }

    return \@domains;
}

sub _urlsByPolicy
{
    my ($self, $policy) = @_;

    my @urls;
    for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        my $url = $row->valueByName('domain');
        if (not $url =~ m{/}) {
            next;
        }

        if ($row->valueByName('policy') eq $policy) {
            push (@urls, $url);
        }
    }

    return \@urls;
}

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my $dataTable =
        {
            tableName          => 'DomainFilter',
            printableTableName => __('Domains and URL rules'),
            modelDomain        => 'Squid',
            defaultController  => '/Squid/Controller/DomainFilter',
            defaultActions     => [ 'add', 'del', 'move', 'editField', 'changeView' ],
            tableDescription   => $self->_tableHeader(),
            class              => 'dataTable',
            order              => 1,
            rowUnique          => 1,
            printableRowName   => __('internet domain or URL'),
            help               => __('Allow/Deny the HTTP traffic from/to the listed internet domains and URLs.'),
            messages           => {
                add => __('Domain or URL added'),
                del => __('Domain or URL removed'),
                update => __('Domain or URL updated'),

            },
        };
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
sub viewCustomizer
{
    my ($self) = @_;

    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([]);

    return $custom;
}

sub _aclName
{
    my ($sef, $profileId, $row) = @_;
    my $aclName = $profileId . '~df~' . $row->id();
    return $aclName;
}

sub squidAcls
{
    my ($self, $profileId) = @_;
    my @acls;
    foreach my $id (@{ $self->ids()}) {
        my $row = $self->row($id);
        my $name = $self->_aclName($profileId, $row);
        $name or
            next;
        my $domain = $row->valueByName('domain');
        my $type;
        if ($domain =~ m{/}) {
            $type = 'url_regex';
            $domain = "-i $domain";
        } elsif ($domain =~ m/^\d+\.\d+.\d+\.\d+$/) {
            $type = 'dst';
        } else {
            $type = 'dstdomain';
            if (not $domain =~ m/^\./) {
                $domain = '.' . $domain;
            }
        }

        push @acls, "acl $name $type $domain";
    }
    return \@acls;
}

sub squidRulesStubs
{
    my ($self, $profileId) = @_;
    my @rules;
    foreach my $id (@{ $self->ids()}) {
        my $row = $self->row($id);
        my $aclName = $self->_aclName($profileId, $row);
        $aclName or
            next;
        my $policy = $row->valueByName('policy');
        my $rule = {
                     type => 'http_access',
                     acl => $aclName,
                     policy => $policy
                    };
        push @rules, $rule;
    }

    return \@rules;
}

1;
