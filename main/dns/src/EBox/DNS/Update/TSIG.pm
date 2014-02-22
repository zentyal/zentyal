# Copyright (C) 2014 Zentyal S.L.
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

use strict;
use warnings;

package EBox::DNS::Update::TSIG;

use base 'EBox::DNS::Update';

use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Exceptions::MissingArgument;

sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless ($self, $class);

    unless (defined $params{keyName}) {
        throw EBox::Exceptions::MissingArgument('keyName');
    }
    $self->{keyName} = $params{keyName};

    unless (defined $params{key}) {
        throw EBox::Exceptions::MissingArgument('key');
    }
    $self->{key} = $params{key};

    return $self;
}

sub _sign
{
    my ($self) = @_;

    my $packet = $self->_packet();
    my $keyName = $self->{keyName};
    my $key = $self->{key};
    my $tsig = $packet->sign_tsig($keyName, $key);
    unless (defined $tsig) {
        throw EBox::Exceptions::External(__("Failed to sign DNS packet."));
    }
}

1;
