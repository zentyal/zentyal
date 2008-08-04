# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::MailFilter::Types::MIMEType;

use strict;
use warnings;

use base 'EBox::Types::Text';

# eBox uses
use EBox;
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
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
{
    my ($self, $params) = @_;
    
    my $value = $params->{$self->fieldName()};
    
    my $portionRegex = '[a-zA-Z\d\-]+';
    
    unless ($value =~ m{^$portionRegex\/$portionRegex$}) {
        throw EBox::Exceptions::InvalidData (
                                             data => __x('MIME type'),
                                             value =>  $value,
                                            );    
    }
    
    return 1;
}



my $ESCAPED_MIME_SEPARATOR = '_';

sub _escapeMimeType
{
  my ($self, $mimeType) = @_;
  $mimeType =~ s{/}{$ESCAPED_MIME_SEPARATOR};

  return $mimeType;
}

sub _unescapeMimeType
{
  my ($self, $mimeType) = @_;
  $mimeType =~ s{$ESCAPED_MIME_SEPARATOR}{/};
  return $mimeType;
}


1;
