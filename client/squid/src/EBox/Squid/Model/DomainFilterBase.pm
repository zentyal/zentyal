# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::Squid::Model::DomainFilterBase;
use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Squid::Types::DomainPolicy;
use EBox::Types::Text;
use EBox::Validate;

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
        new EBox::Squid::Types::DomainPolicy(
            fieldName     => 'policy',
            printableName => __('Policy'),
            defaultValue  => 'filter',
           ),
       );

    return \@tableHeader;
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

1;

