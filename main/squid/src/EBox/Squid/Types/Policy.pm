# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::Squid::Types::Policy;
use base 'EBox::Types::Select';

use strict;
use warnings;

use EBox::Gettext;

my %policies = (
                allow => {
                          allowAll => 1,
                          auth     => 0,
                          filter   => 0,
                         },
                deny => {
                          allowAll => 0,
                          auth     => 0,
                          filter   => 0,
                         },
                filter => {
                          allowAll => 1,
                          auth     => 0,
                          filter   => 1,
                         },
                auth => {
                          allowAll => 1,
                          auth     => 1,
                          filter   => 0,
                         },
                authAndDeny=> {
                          allowAll => 0,
                          auth     => 1,
                          filter   => 0,
                         },
                authAndFilter=> {
                          allowAll => 1,
                          auth     => 1,
                          filter   => 1,
                         },
               );


sub new
{
  my ($class, %params) = @_;

  if (not exists $params{defaultValue}) {
    $params{defaultValue} = 'allow';
  }

  $params{editable} = 1;
  $params{populate} = \&_populate;

  my $self = $class->SUPER::new(%params);

  bless $self, $class;
  return $self;
}


sub _populate
{
  my @elements = (
                  { value => 'allow',  printableValue => __('Always allow') },
                  { value => 'filter', printableValue => __('Filter') },
                  { value => 'deny',   printableValue => __('Always deny') },
                  { value => 'auth',   printableValue => __('Authorize and allow') },
                  { value => 'authAndFilter',   printableValue => __('Authorize and filter') },
                  { value => 'authAndDeny',   printableValue => __('Authorize and deny') },
                 );

  return \@elements;
}


sub _paramIsValid
{
  my ($self, $params) = @_;

  my $value = $params->{$self->fieldName()};
  $self->checkPolicy($value);
}

sub checkPolicy
{
  my ($class, $policy) = @_;
  if (not exists $policies{$policy}) {
    throw EBox::Exceptions::InvalidData(
                                        data  => __(q{Squid's policy}),
                                        value => $policy,
                                       );
  }
}

sub usesFilter
{
    my ($self) = @_;
    my $policy = $self->value();
    return $policies{$policy}->{filter};
}


sub usesAuth
{
    my ($self) = @_;
    my $policy = $self->value();
    return $policies{$policy}->{auth};
}


sub usesAllowAll
{
    my ($self) = @_;
    my $policy = $self->value();
    return $policies{$policy}->{allowAll};
}

1;
