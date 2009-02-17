# Copyright (C) 2009 Warp Networks S.L.
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

# eBox uses
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
            printableName => __('Domain'),
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



sub _domainsByPolicy
{
  my ($self, $policy) = @_;

  my @domains;
  for my $id (@{$self->ids()}) {
        my $row = $self->row($id);
        if ($row->valueByName('policy') eq $policy) {
            push (@domains, $row->valueByName('domain'));
        }
  }

  return \@domains;
}



1;

