# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::MailFilter::Types::AmavisSender;

use strict;
use warnings;

use base 'EBox::Types::Text';

# eBox uses
use EBox;
use EBox::Validate;
use EBox::Gettext;
use EBox::Exceptions::InvalidData;

# Group: Public methods

sub new
{
    my $class = shift;
    my %opts = @_;

    my $self = $class->SUPER::new(%opts);
    $self->{localizable} = 0;

    bless($self, $class);
    return $self;
}




# Method: _paramIsValid
#
#
# valid sender values :
#  address@domain
#  @domain
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;
    
    my $sender = $params->{$self->fieldName()};
    $self->validate($sender);

    return 1;
}

#  Method: validate
#
#    validates wether we have a valid sender either in the form 
#     user@domain or @domain 
#
sub validate
{
    my ($class, $sender) = @_;

    if ($sender =~ m/^@/) {
        # domain case
        my ($unused, $domainName,) = split '@', $sender, 2;
        EBox::Validate::checkDomainName($domainName, __('domain name'));
    }
    elsif ($sender =~ m/@/) {
        # sender addres
        EBox::Validate::checkEmailAddress($sender, __('email address'));
    }
    else {
        throw EBox::Exceptions::External(
                                         __(q{The sender ought be either an email address or a domain name prefixed with '@'})
                                        );
    }
}



1;
