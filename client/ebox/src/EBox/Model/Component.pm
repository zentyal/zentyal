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

# Class: EBox::Model::Component
#
#   This class is intended to provide common methods which are used
#   by <EBox::Model::Composite> and <EBox::Model::DataTable>.
#

package EBox::Model::Component;

use strict;
use warnings;

# EBox uses
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::MissingArgument;

# Other modules uses
use Encode;
use Error qw(:try);


# Method: setParentComposite
#
#   Set the parent composite of this composite object
#
# Parameters:
#
#      component - an instance of <EBox::Model::Composite>
sub setParentComposite
{
    my ($self, $composite) = @_;

    defined ( $composite ) or
      throw EBox::Exceptions::MissingArgument('composite');

    unless ( $composite->isa('EBox::Model::Composite') ) {
        throw EBox::Exceptions::InvalidType( $composite,
                'EBox::Model::DataTable ' 
                );
    }

    $self->{'parentComposite'} = $composite;
}   

# Method: parentComposite
#
#   Return the parent composite of this composite object
#
# Returns:
#
#      component - an instance of <EBox::Model::Composite>
#      or undef if there's any
sub parentComposite
{
    my ($self) = @_;

    if (exists $self->{'parentComposite'}) {
        return $self->{'parentComposite'};
    } else {
        return undef;
    }
}

# Method: pageTitle
#
#   This method must be overriden by the component to show a page title
#
# Return:
#
#   string or undef
sub pageTitle
{
    my ($self) = @_;

    return undef;
}

# Method: headTitle
#
#   This method must be overriden by the component to show a headTitle
#
# Return:
#
#   string or undef
sub headTitle
{
    my ($self) = @_;

    return undef;
}

# Method: help
#
#     Get the help message from the model
#
# Returns:
#
#     string - containing the i18n help message
sub help
{
    return '';
}

# Method: keywords
#
#   Returns words related to the model, extracted from different sources such
#   as row names, help, ..., that can be used to make lookups from words to
#   models, menus, ...
#
# Return:
#
#   string array - the keywords
#
sub keywords
{
    my ($self) = @_;
    my $help = $self->help();
    Encode::_utf8_on($help);
    return [split('\W+', lc($help))];
}

1;
