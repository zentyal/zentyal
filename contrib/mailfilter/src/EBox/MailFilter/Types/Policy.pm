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

package EBox::MailFilter::Types::Policy;

use base 'EBox::Types::Select';

use EBox::Gettext;
use EBox::Exceptions::InvalidData;

use Perl6::Junction qw(all);

my $passPolicy = { value => 'D_PASS',    printableValue => __('Pass') };
my $rejectPolicy = { value => 'D_REJECT',  printableValue => __('Notify sender server') };
my $bouncePolicy = { value => 'D_BOUNCE',  printableValue => __('Notify mail sender account') };
my $discardPolicy = { value => 'D_DISCARD', printableValue => __('Drop silently') };
my $allPolicies = all qw(D_PASS D_REJECT D_BOUNCE D_DISCARD);

sub new
{
    my ($class, %params) = @_;
    $params{editable} = 1;
    my $noBounce = $params{noBounce};

    if ($noBounce) {
        $params{populate} = \&_populateWithoutBounce;
    } else {
        $params{populate} = \&_populate;
    }

    my $self = $class->SUPER::new(%params);

    bless $self, $class;
    return $self;
}

sub _populate
{
    return [ $passPolicy, $rejectPolicy, $bouncePolicy, $discardPolicy ];
}

sub _populateWithoutBounce
{
    return [ $passPolicy, $rejectPolicy, $discardPolicy ];
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
    if ($policy ne $allPolicies) {
        throw EBox::Exceptions::InvalidData(
                                            data  => __(q{Mailfilter's policy}),
                                            value => $policy,
                                       );
    }
}

1;
