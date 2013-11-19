# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EBox::SysInfo::Types::DomainName
#
#      A specialised domain type that not allow single labels
#
use strict;
use warnings;

package EBox::SysInfo::Types::DomainName;

use base 'EBox::Types::DomainName';

use EBox::Gettext;
use EBox::Exceptions::InvalidData;

use Data::Validate::Domain qw(is_domain);

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::Types::DomainName>
#
# Returns:
#
#      the recently created <EBox::Types::DomainName> object
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{'type'} = 'domainname';
    bless ($self, $class);
    return $self;
}

# Method: _paramIsValid
#
#     Check if the params has a correct domain name
#
# Overrides:
#
#     <EBox::Types::Text::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is a correct domainName
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       host IP address
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};
    $value =~ s/\.$//;

    if (defined ($value)) {
        # According to RFC underscores are forbidden in "hostnames" but not "domainnames"
        my $options = {
            domain_allow_underscore => 1,
            domain_allow_single_label => 0,
            domain_private_tld => qr /^[a-zA-Z]+$/,
        };

        unless (is_domain($value, $options)) {
            throw EBox::Exceptions::InvalidData('data' => __('domain name'), 'value' => $value);
        }

        my $seemsIp = EBox::Validate::checkIP($value);
        if ($seemsIp) {
            throw EBox::Exceptions::InvalidData
                ('data' => $self->printableName(),
                 'value' => $value,
                 'advice' => __('IP addresses are not allowed'),
                );
        }
    }

    return 1;
}

1;
