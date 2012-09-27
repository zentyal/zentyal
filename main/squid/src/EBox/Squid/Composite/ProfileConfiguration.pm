# Copyright (C) 2009-2012 eBox Technologies S.L.
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

package EBox::Squid::Composite::ProfileConfiguration;
use base 'EBox::Model::Composite';

use EBox::Gettext;

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
    my $description = {
        layout          => 'tabbed',
        name            => 'ProfileConfiguration',
        compositeDomain => 'Squid',
    };

    return $description;
}

sub HTMLTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    my $profile = $parentRow->elementByName('name')->printableValue();

    return ([
            {
                title => __('Filter Profiles'),
                link  => '/Squid/View/FilterProfiles',
            },
            {
                title => $profile,
                link => '',
            },
            ]);
}

sub _profileId
{
    my ($self) = @_;
    return $self->parentRow()->id();
}

# XXX MIME
# XXX extension
sub squidAcls
{
    my ($self) = @_;
    my @acls;
    my $profileId = $self->_profileId();
    push @acls, @{ $self->componentByName('DomainFilter', 1)->squidAcls($profileId) };
    push @acls, @{ $self->componentByName('DomainFilterCategories', 1)->squidAcls($profileId) };
    return \@acls;
}

sub squidRulesStubs
{
    my ($self) = @_;
    my @rules;
    my $profileId = $self->_profileId();
    push @rules, @{ $self->componentByName('DomainFilter', 1)->squidRulesStubs($profileId) };
    push @rules, @{ $self->componentByName('DomainFilterCategories', 1)->squidRulesStubs($profileId) };
    push @rules, @{ $self->componentByName('DomainFilterSettings', 1)->squidRulesStubs($profileId) };
    return \@rules;
}


1;
