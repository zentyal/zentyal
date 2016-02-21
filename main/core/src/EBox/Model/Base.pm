# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Model::Base;

use base 'EBox::Model::Component';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Sudo;

use TryCatch;

# Method: modelName
#
#    Return the model name, to be overrided in subclasses
#
# Returns:
#
#    string containing the model name
#
sub modelName
{
    my ($self) = @_;
    # FIXME: throw NotImplemented
}

# Method: name
#
#       Return the same that <EBox::Model::Base::modelName>
#
sub name
{
    my ($self) = @_;
    return $self->modelName();
}

# Method: contextName
#
#      The context name which is used as a way to know exactly which
#      module this model belongs to
#
# Returns:
#
#      String - following this pattern:
#      '/moduleName/modelName
#
sub contextName
{
    my ($self) = @_;

    my $path = '/' . $self->{'confmodule'}->name() . '/' .  $self->name() . '/';

    return $path;
}

# Method: printableContextName
#
#       Localisated version of <EBox::Model::Base::contextName>
#       method to be shown on the user
#
# Returns:
#
#       String - the localisated version of context name
#
sub printableContextName
{
    my ($self) = @_;
    my $printableContextName = __x( '{model} in {module} module',
                                    model  => $self->printableName(),
                                    module => $self->{'confmodule'}->printableName());
    return $printableContextName;
}

# Method: precondition
#
#       Check if the model has enough data to be manipulated, that
#       is, this precondition constraint is accomplished.
#
#       This method must be override by those models which requires
#       any precondition to work correctly. Associated to the
#       precondition there is a fail message which displays what it is
#       required to make model work using method
#       <EBox::Model::Base::preconditionFailMsg>
#
# Returns:
#
#       Boolean - true if the precondition is accomplished, false
#       otherwise
#       Default value: true
sub precondition
{
    return 1;
}

# Method: preconditionFailMsg
#
#       Return the fail message to inform why the precondition to
#       manage this model is not accomplished. This method is related
#       to <EBox::Model::Base::precondition>.
#
# Returns:
#
#       String - the i18ned message to inform user why this model
#       cannot be handled
#
#       Default value: empty string
#
sub preconditionFailMsg
{
    return '';
}

# Method: printableModelName
#
#       Get the i18ned model name
#
# Returns:
#
#       String - the localisated model name
#
sub printableModelName
{
    my ($self) = @_;

    # FIXME throw NotImplemented
}

# Method: printableName
#
#       Get the i18ned name
#
# Returns:
#
#       What <EBox::Model::TreeView::printableModelName> returns
#
sub printableName
{
    my ($self) = @_;

    return $self->printableModelName();
}

sub headTitle
{
    my ($self) = @_;

    return $self->printableModelName();
}

# Method: menuNamespace
#
#    Fetch the menu namespace which this model belongs to
#
# Returns:
#
#        String - Containing namespace
#
sub menuNamespace
{
    #FIXME: throw NotImplemented
}


# Method: modelDomain
#
#     Get the domain where the model is handled. That is, the eBox
#     module which the model belongs to
#
# Returns:
#
#     String - the model domain, the first letter is upper-case
#
sub modelDomain
{
    my ($self) = @_;

    # FIXME: throw NotImplemented
}

# Method: _HTTPUrlView
#
#   Returns the HTTP URL base used to get the view for this model
#
sub _HTTPUrlView
{
    my ($self) = @_;

    # FIXME: throw NotImplemented
}

# Method: HTTPLink
#
#   The HTTP URL base + directory parameter to get the view for this
#   model
#
# Returns:
#
#   String - the URL to link
#
#   '' - if the _HTTPUrlView is not defined to a non-zero string
#
sub HTTPLink
{
    my ($self) = @_;

    #FIXME: throw NotImplemented
}

# Method: Viewer
#
#       Method to return the viewer from this model. This method
#       can be overriden
#
# Returns:
#
#       String - the path to the Mason template which acts as the
#       viewer from this kind of model.
#
sub Viewer
{
   # FIXME: throw notImplemented
}

# Group: Private helper functions

sub _mainController
{
    #FIXME: throw NotImplemented
}


sub permanentMessage
{
    return undef;
}

sub permanentMessageType
{
    return 'note';
}




1;
