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
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

package EBox::Model::Template;

# Class: EBox::Model::Template
#
#    Simple model to include whatever as Viewer. It must implemented by subclasses.
#
#    The context for that template is include in <context> sub
#

use base 'EBox::Model::Base';

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotImplemented;
use Perl6::Junction qw(any);

# Constructor: new
#
# Named parameters:
#
#     confmodule - <EBox::Module::Base> the module
#     parent     - <EBox::Model::Base> the parent model *(Optional)*
#
sub new
{
    my $class = shift;

    my %opts = @_;
    my $confmodule = delete $opts{'confmodule'};
    unless ($confmodule) {
        throw EBox::Exceptions::MissingArgument('confmodule');
    }

    my $self = {
        'confmodule' => $confmodule,
        'parent'  => $opts{'parent'},
    };

    bless ($self, $class);

    return $self;
}

# Method: modelName
#
# Overrides:
#
#    <EBox::Model::Base::modelName>
#
# Returns:
#
#    String - the model name always the package name
#
sub modelName
{
    my ($self) = @_;
    return _nameFromClass($self);
}

# Class method: Viewer
#
#       Method to return the viewer from this model. This method
#       can be overriden
#
# Overrides:
#
#       <EBox::Model::Base::Viewer>
#
# Returns:
#
#       String - the path to the Mason template which acts as the
#       viewer from this kind of model.
#
sub Viewer
{
    return '/ajax/templateModel.mas';
}

# Method: setDirectory
#
#
# Parameters:
#
#     directory - string containing the directory key
#
sub setDirectory
{
    my ($self, $dir) = @_;

    $self->{directory} = $dir;
}

# Method: directory
#
#     Get current directory
#
# Parameters:
#
#     String - Containing the directory key
#
sub directory
{
    my ($self) = @_;

    return $self->{directory};
}

# Method: action
#
#      Accessor to the URLs where the actions are published to
#      run. In a template type, two actions are possible:
#      - view - show the template within the whole Zentyal menu
#      - changeView - show the template type isolated. I.e. the HTML
#                     dumped from the composite Viewer
#
# Parameters:
#
#      actionName - String the action name
#
# Returns:
#
#      String - URL where the action will be called
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidData> - thrown if the action name
#       is not one of the allowed ones
#
#       <EBox::Exceptions::DataNotFound> - thrown if the action name
#       has not defined action
#
sub action
{
    my ($self, $actionName) = @_;

    unless ($actionName eq any('view', 'changeView')) {
        throw EBox::Exceptions::InvalidData(data => __('Action'),
                                            value => $actionName,
                                            advice => __x('Actions to be taken ' .
                                                          'allowed are: {view} and ' .
                                                          '{cView}',
                                                          view => 'view',
                                                          cView => 'changeView',
                                                         ));
    }

    unless (exists($self->{actions})) {
        $self->{actions} = $self->_setDefaultActions();
    }

    my $actionsRef = $self->{actions};

    if (exists ($actionsRef->{$actionName})) {
        return $actionsRef->{$actionName};
    } else {
        throw EBox::Exceptions::DataNotFound(data => __('Action'),
                                             value => $actionName);
    }

}

# Group: Methods to be overriden

# Method: templateName
#
#     Get the template name to render
#
#     It will only receive a %context hash as argument.
#
# Returns:
#
#     String - the template name
#
sub templateName
{
    throw EBox::Exceptions::NotImplemented();
}

# Method: templateContext
#
#     Get the context to render the template set by <templateName> method
#
# Returns:
#
#     Hash ref - the data to use in the HTML rendering. It will be available
#                as %context in the mason template
#
sub templateContext
{
    throw EBox::Exceptions::NotImplemented();
}

# Group: Private methods

sub _setDefaultActions
{
    my ($self) = @_;

    my $URL = '/' . _nameFromClass($self->{confmodule}) . '/Template/' . $self->name();
    return { changeView => $URL,
             view       => $URL };
}

sub _nameFromClass
{
    my ($obj) = @_;
    my $class = ref($obj);
    $class = $obj unless ($class);

    my @namespaces = split('::', $class);
    return pop(@namespaces);
}

1;
