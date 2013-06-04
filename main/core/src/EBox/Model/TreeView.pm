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

package EBox::Model::TreeView;

use base 'EBox::Model::Component';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Sudo;

use Error qw(:try);

sub new
{
    my $class = shift;

    my %opts = @_;
    my $confmodule = delete $opts{'confmodule'};
    $confmodule or
        throw EBox::Exceptions::MissingArgument('confmodule');

    my $self =
    {
        'confmodule' => $confmodule,
        'parent'  => $opts{'parent'},
        'tree' => undef,
    };

    bless ($self, $class);

    return $self;
}

# Method: tree
#
#       Get the tree description. It must NOT be overrided.
#
# Returns:
#
#       hash ref with the tree description
#
sub tree
{
    my ($self) = @_;

    # It's a singleton method
    unless (defined($self->{'tree'}) and
            defined($self->{'tree'}->{'treeDescription'})) {
        $self->_setupTree();
    }

    return $self->{'tree'};
}

sub _setupTree
{
    my ($self) = @_;

    my $tree = $self->_tree();
    $self->{'tree'} = $tree;

    # Set the needed controller and undef setters
    $self->_setControllers();

    # Some default values
    unless (defined($self->{'tree'}->{'class'})) {
        $self->{'tree'}->{'class'} = 'treeView';
    }
}

# Method: _tree
#
#    Override this method to describe your tree.
#       This method is (PROTECTED)
#
# Returns:
#
#     tree description. See example on <EBox::Network::Model::GatewayTreeView::_tree>.
#
sub _tree
{
    throw EBox::Exceptions::NotImplemented('_tree');
}

# Method: rootNodes
#
#    Return the top-level nodes of the tree
#
#    This needs to be overrided and implemented on each model
#
# Returns:
#
#    list of hashes ref with the attributes of each root node
#
sub rootNodes
{
    throw EBox::Exceptions::NotImplemented('rootNodes');
}

# Method: childNodes
#
#    Return the child nodes of a given parent node
#
#    This needs to be overrided on each model except in
#    the case of a plain tree with only root nodes, but
#    in that case is probably better to be using a DataTable
#
# Parameters:
#
#    parent - string with the id of the parent node
#
# Returns:
#
#    list of hashes ref with the attributes of each child node
#
sub childNodes
{
    return [];
}

# Method: modelName
#
#    Return the model name which is set by the key 'treeName' when
#    a model tree is described
#
# Returns:
#
#    string containing the model name
#
sub modelName
{
    my ($self) = @_;
    return $self->tree()->{'treeName'};
}

# Method: name
#
#       Return the same that <EBox::Model::TreeView::modelName>
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
#       Localisated version of <EBox::Model::TreeView::contextName>
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

# FIXME: move to EBox::Model::Base ?

# Method: precondition
#
#       Check if the model has enough data to be manipulated, that
#       is, this precondition constraint is accomplished.
#
#       This method must be override by those models which requires
#       any precondition to work correctly. Associated to the
#       precondition there is a fail message which displays what it is
#       required to make model work using method
#       <EBox::Model::TreeView::preconditionFailMsg>
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
#       to <EBox::Model::TreeView::precondition>.
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

# Method: treeName
#
#        Get the tree name associated to this model
#
# Returns:
#
#        String - containing the tree name
#
sub treeName
{
    my ($self) = @_;

    return $self->tree()->{'treeName'};
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

    return $self->tree()->{'printableTreeName'};
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

# Method: pageTitle
#
#       Get the i18ned name of the page where the model is contained, if any
#
# Returns:
#
#   string
#
sub pageTitle
{
    my ($self) = @_;

    return $self->tree()->{'pageTitle'};
}

# Method: headTitle
#
#       Get the i18ned name of the page where the model is contained, if any
#
# Returns:
#
#   string
#
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
    my ($self) = @_;

    if (exists $self->tree()->{'menuNamespace'}) {
        return $self->tree()->{'menuNamespace'};
    } elsif ( defined ( $self->modelDomain() )) {
        # This is autogenerated menuNamespace got from the model
        # domain and the tree name
        my $menuNamespace = $self->modelDomain() . '/View/' . $self->treeName();
        return $menuNamespace;
    } else {
        return undef;
    }
}

# Method: help
#
#     Get the help message from the model
#
# Returns:
#
#     String - containing the i18n help message
#
sub help
{
    my ($self) = @_;

    return $self->tree()->{'help'};
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

    return $self->{'tree'}->{'modelDomain'};
}

# Method: _HTTPUrlView
#
#   Returns the HTTP URL base used to get the view for this model
#
sub _HTTPUrlView
{
    my ($self) = @_;

    return $self->tree()->{'HTTPUrlView'};
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

    if ( $self->_HTTPUrlView() ) {
        my $link = '/' . $self->_HTTPUrlView();
        my $parentRow = $self->parentRow();
        if ($parentRow) {
            $link .= '?directory=' . $self->directory();
        }
        return $link;
    } else {
        return "";
    }
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
    return '/ajax/treeView.mas';
}

# Group: Private helper functions

sub _mainController
{
    my ($self) = @_;

    my $tree = $self->{'tree'};

    my $defAction = $tree->{'defaultController'};
    if ( (not defined ( $defAction )) and defined ( $self->modelDomain() )) {
        # If it is not a defaultController, we try to guess it from
        # the model domain and its name
        $defAction = '/' . $self->modelDomain() . '/Controller/' .
            $self->{'tree'}->{'treeName'};
    }
    return $defAction;
}

# Set the default controller to that actions which do not have a
# custom controller
sub _setControllers
{
    my ($self) = @_;

    # Tree is already defined
    my $tree = $self->{'tree'};
    my $defAction = $self->_mainController();
    if ($defAction) {
        foreach my $action (@{$tree->{'defaultActions'}}) {
            # Do not overwrite existing actions
            unless ( exists ( $tree->{'actions'}->{$action} )) {
                $tree->{'actions'}->{$action} = $defAction;
            }
        }
    }
}

# Method: keywords
#
# Overrides:
#
#   <EBox::Model::Component::keywords>
#
sub keywords
{
    my ($self) = @_;

    my @words = ();

    push(@words, _parse_words($self->pageTitle()));
    push(@words, _parse_words($self->headTitle()));
    push(@words, _parse_words($self->printableName()));
    push(@words, _parse_words($self->printableModelName()));
    push(@words, _parse_words($self->printableRowName()));
    push(@words, _parse_words($self->help()));

    return \@words;
}

1;
