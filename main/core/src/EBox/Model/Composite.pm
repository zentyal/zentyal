# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

# Class: EBox::Model::Composite
#
#      This class is intended to hold a number of models inside. This
#      composite class will have a defined layout. This layout will be
#      used to establish the output on the view.
#
#      The possible components should be subclasses of:
#
#      - <EBox::Model::DataTable>
#      - <EBox::Model::DataForm>
#      - <EBox::Model::Composite>
#      - <EBox::Model::Template>
#
#      The possible layout that it will implemented are the following:
#
#      - top-bottom - the components will be shown from top to the
#      bottom in the given order
#      - left-right - the components will be shown from left to
#      right in the given order
#      - tabbed     - the components will be shown in a tab way
#

use strict;
use warnings;

package EBox::Model::Composite;

use base 'EBox::Model::Component';

use EBox::Exceptions::Internal;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Model::Manager;

# Other modules uses
use TryCatch;

#################
# Dependencies
#################
use Perl6::Junction qw(any);

# Constants
use constant LAYOUTS => qw(top-bottom left-right tabbed);

# Group: Public methods

# Constructor: new
#
#       Constructor for the EBox::Model::Composite. In order to set
#       the attributes for the composite object, it is required to
#       override the <EBox::Model::Composite::_description> method
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidData> - thrown if layout parameter
#       has not any of the allowed values
#       <EBox::Exceptions::InvalidType> - thrown if any parameter has
#       not the correct type
#
sub new
{
    my ($class, %params) = @_;

    my $self = { %params };
    bless ($self, $class);

    my $description = $self->_description();
    $self->_setDescription($description);

    return $self;
}

# Method: components
#
#      Get the components which this composite consists of
#
# Returns:
#
#      array ref - containing the components which this composite
#      comprises. The elements are instances of classes which inherit
#      from <EBox::Model::Component> such as <EBox::Model::DataTable>
#      or <EBox::Model::Composite>.
#
sub components
{
    my ($self) = @_;

    return $self->{components};
}

#  Method: componentByName
#
#     get a specific component from the composite
#
#  Parameters:
#    name - the name of the component to fetch
#    recursive - searchs inside the components (default: false)
#
#  Returns:
#    the component or undef if there is not any component with the given name
sub componentByName
{
    my ($self, $name, $recursive) = @_;
    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $components = $self->components();
    foreach my $comp (@{ $components }) {
        if ($name eq $comp->name()) {
            return $comp;
        }

        if ($recursive) {
            if ($comp->can('componentByName')) {
                my $compFromChild;
                $compFromChild = $comp->componentByName($name, 1);
                if (defined $compFromChild) {
                    return $compFromChild;
                }
            }
        }

    }

    return undef;
}

# Method: componentNames
#
#      Override this to dynamically calculate which components should
#      be included in the composite
#
# Returns:
#
#      array ref - containing the names of the components
#
sub componentNames
{
    my ($self) = @_;

    return [];
}

# Method: models
#
#   get all Model objects inside the composite.
#
# Parameters:
#   recursive - searchs inside the nested composites (default: false)
#
# Returns:
#   an array of Model objects found.
#
sub models
{
    my ($self, $recursive) = @_;

    my @models = ();
    foreach my $component (@{$self->components()}) {
        if ($component->isa('EBox::Model::Base') and (ref($component) ne 'EBox::Model::Base')) {
            push (@models, $component);
            next;
        } elsif ($recursive and $component->isa('EBox::Model::Composite')) {
            push (@models, @{$component->models($recursive)});
        }
    }

    return \@models;
}

# Method: setLayout
#
#      Set the layout where the elements will be displayed.
#
# Parameters:
#
#      layout - String Set the element layout. The possible values
#      are:
#
#      - top-bottom - the elements will be shown sequentially
#
#      - left-right - the elements will be shown from left to right
#
#      - tabbed - every element will be shown in a tab
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> -
#       thrown if any mandatory parameter is missing
#       <EBox::Exceptions::InvalidData> - thrown if layout parameter
#       has not any of the allowed values
#
sub setLayout
{
    my ($self, $layout) = @_;

    defined ($layout) or
        throw EBox::Exceptions::MissingArgument('layout');

    unless ($layout eq any(LAYOUTS)) {
        throw EBox::Exceptions::InvalidData(
                data  => 'layout',
                value => $layout,
                advice => __x('It should be one of following values: {values}',
                    values => join(', ', LAYOUTS))
                );
    }

    $self->{layout} = $layout;
}

# Method: layout
#
#      Get the components layout from this composite
#
# Returns:
#
#      String - with the current used layout
#
sub layout
{
    my ($self) = @_;

    return $self->{layout};
}

# Method: width
#
#      Get the component width from the composite
#
# Returns:
#
#      String - indicating the indicated component width
#       This value will be inserted this way: <... style='width=<% $width %>;'>
#
sub width
{
    my ($self, $name) = @_;

    if ($self->layout() eq 'left-right') {
        return $self->{widths}->{$name};
    }

    return '100%';
}

# Method: name
#
#      Get the composite's name
#
# Returns:
#
#      String - the composite's name
sub name
{
    my ($self) = @_;

    return $self->{name};
}

# Method: contextName
#
#      Get the composite's context name, that is, the composite's name
#      plus its index if any separated by a slash. If the composite
#      has no index, the return value is equal to the
#      <EBox::Model::Composite::name> return value.
#
# Returns:
#
#      String - the composite's context name
#
sub contextName
{
    my ($self) = @_;

    if ($self->index()) {
        return '/' . $self->{name} . '/' . $self->index();
    } else {
        return $self->{name};
    }
}

# XXX transitional method, this will be the future name() method
sub nameFromClass
{
    my ($self) = @_;
    my $class;
    if (ref $self) {
        $class = ref $self;
    }
    else {
        $class = $self;
    }

    my @parts = split '::', $class;
    my $name = pop @parts;

    return $name;
}

# Method: printableName
#
#      Get the composite's printable name
#
# Returns:
#
#      String - the composite's printable name
#
sub printableName
{
    my ($self) = @_;

    return $self->{printableName};
}

# Method: precondition
#
#       Check if the composite has enough data to be manipulated, that
#       is, this precondition constraint is accomplished.
#
#       This method must be override by those composites which requires
#       any precondition to work correctly. Associated to the
#       precondition there is a fail message which displays what it is
#       required to make composite work using method
#       <EBox::Model::Composite::preconditionFailMsg>
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
#       manage this composite is not accomplished. This method is related
#       to <EBox::Model::Composite::precondition>.
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

# Method: index
#
#     Get the composite's index if any to distinguish same composite
#     class with different instances. To be overridden by
#     subclasses. Default value: empty string
#
# Returns:
#
#     String - the index to distinguish instances if any
#
sub index
{
    return '';
}

# Method: printableIndex
#
#     Get the composite's printable index. Explanation about index
#     value on <EBox::Model::Composite::printableIndex> method
#     header. To be overridden by children classes which are
#     parameterised composites.
#
# Returns:
#
#     String - the i18ned index value
#
sub printableIndex
{
    return '';
}

# Method: help
#
#     Get the help string which may indicate the user how to use the
#     composite content
#
# Returns:
#
#     String - the i18ned string which contents the help if any
#
sub help
{
    my ($self) = @_;

    return $self->{help};
}

# Method: permanentMessage
#
#     Get the permanent message to be shown as a note within the
#     composite
#
# Returns:
#
#     String - the i18ned string which contents the permanent message
#
sub permanentMessage
{
    my ($self) = @_;

    return $self->{permanentMessage};
}

# Method: permanentMessageType
#
#   Return the type for the defined permanent message
#
# Returns:
#
#   string - note, ad or warning
#
sub permanentMessageType
{
    my ($self) = @_;

    return $self->{permanentMessageType};
}

# Method: compositeDomain
#
#     Get the domain where the model is handled. That is, the Zentyal
#     module which the composite belongs to
#
# Returns:
#
#     String - the composite domain, the first letter is upper-case
#
sub compositeDomain
{
    my ($self) = @_;

    return $self->{compositeDomain};
}

# Method: menuNamespace
#
#      Get the composite's menu namespace
#
# Returns:
#
#      String - the composite's menu namespace
#
sub menuNamespace
{
    my ($self) = @_;

    if ($self->{menuNamespace}) {
        return $self->{menuNamespace};
    } elsif ( defined ( $self->compositeDomain() )) {
        # This is autogenerated menuNamespace got from the composite
        # domain and its name
        return $self->compositeDomain() . '/Composite/' . $self->name();
    } else {
        return undef;
    }
}

# Method: action
#
#      Accessor to the URLs where the actions are published to
#      run. In a composite type, two actions are possible:
#      - view - show the composite type within the whole Zentyal menu
#      - changeView - show the composite type isolated. I.e. the HTML
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

    my $actionsRef = $self->{actions};

    if (exists ($actionsRef->{$actionName})) {
        return $actionsRef->{$actionName};
    } else {
        throw EBox::Exceptions::DataNotFound(data => __('Action'),
                                             value => $actionName);
    }
}

# Group: Class methods

# Method: Viewer
#
#       Class method to return the viewer from this composite.
#
# Returns:
#
#       String - the path to the Mason template which acts as the
#       viewer from composite
#
sub Viewer
{
    return '/ajax/composite.mas';
}

# Group: Protected methods

# Method: _description
#
#      Describe the Composite content, that is, its components,
#      layout, and much more.
#
#
# Returns:
#
#      hash ref - the composite description containing the following
#      elements:
#
#       components - array ref containing the components that will
#       contain the composite. It can be a String which can refer
#       to a/some <EBox::Model::DataTable> or
#       <EBox::Model::Composite>. *(Optional)* Default value: empty array
#
#       layout - String define the layout of the corresponding views
#       of the models. It can be one of the following: 'top-bottom' or
#       or 'left-right' or 'tabbed' *(Optional)* Default value: 'top-bottom'
#
#       name - String the composite's name *(Optional)* Default value:
#       class name
#
#       printableName - String the composite's localisated name
#       *(Optional)* Default value: empty string
#
#       help - String the localisated help which may indicate the user
#       how to use the composite content. *(Optional)* Default value:
#       empty string
#
#       actions - array ref containing hash ref whose elements has a
#       String as a key which is the action name and the value is
#       another String which represents the URL which takes the
#       action. This is useful to know what to call when an action
#       should be taken. *(Optional)* Default values: default actions
#       are general done by generic CGIs if compositeDomain attribute
#       is set.
#
#       compositeDomain - String the composite's domain, that is, the
#       eBox module which composite belongs to. First letter must be
#       upper-case *(Optional)*
#
#       menuNamespace - String the menu namespace, this is used in
#       order to show the context within the eBox menu *(Optional)*
#
#       permanentMessage - String the permanent message to be shown
#       always as a side note in the composite *(Optional)*
#
#       permanentMessage - Type of permanent message: note (default),
#       ad, warning *(Optional)*
#
#
sub _description
{

}

# Group: Private methods

# Method: _setDescription
#
#      Check the composite description and stores the attributes in
#      composite instance
#
# Parameters:
#
#      description - hash ref the description to check and set
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidType> - thrown if any attribute has
#      not correct type
#
#      <EBox::Exceptions::InvalidData> - thrown if any attribute has
#      not correct data
#
sub _setDescription
{
    my ($self, $description) = @_;

    $self->{layout} = 'top-bottom';
    $self->{name} = ref( $self );
    $self->{printableName} = '';
    $self->{help} = '';
    $self->{permanentMessage} = '';
    $self->{permanentMessageType} = 'note';
    $self->{compositeDomain} = delete ( $description->{compositeDomain} );
    $self->{menuNamespace} = delete ($description->{menuNamespace});

    if (exists ($description->{layout})) {
        $self->setLayout( delete ( $description->{layout} ));
    }

    if (exists ($description->{name})) {
        $description->{name} or
        throw EBox::Exceptions::Internal('name for composite cannot be empty');

        $self->{name} = delete ( $description->{name} );
    }

    # String properties
    foreach my $property (qw(printableName help permanentMessage permanentMessageType)) {
        if (exists ($description->{$property})) {
            $self->{$property} = delete ( $description->{$property} );
        }
    }

    $self->{actions} = $description->{actions};

    if (exists($description->{widths})) {
        if ($self->{layout} ne 'left-right') {
            throw EBox::Exceptions::InvalidData(
                    data  => 'layout',
                    value => $self->{layout},
                    advice => __x('You cannot set the width property if the ' .
                                  'composite has not a: {left_right} layout',
                        left_right => 'left-right')
                    );
        }

        $self->{widths} = delete($description->{widths});
    }

    # Set the Composite actions, do not ovewrite the user-defined actions
    $self->_setDefaultActions();
}

# Method: _setDefaultActions
#
#    Set the default actions if no user defined previously
#
sub _setDefaultActions
{
    my ($self) = @_;

    my $actionsRef = $self->{actions};
    $actionsRef = {} unless defined ($actionsRef);
    if (defined ($self->compositeDomain())) {
        unless (exists $actionsRef->{view}) {
            $actionsRef->{view} = '/' . $self->compositeDomain() .
              '/Composite/' . $self->name();
            if ( $self->index() ) {
                # Append the index
                $actionsRef->{view} .= '/' . $self->index();
            }
        }
        unless (exists $actionsRef->{changeView}) {
            $actionsRef->{changeView} = '/' . $self->compositeDomain() .
              '/Composite/' . $self->name();
            if ( $self->index() ) {
                $actionsRef->{changeView} .= '/' . $self->index();
            }
            $actionsRef->{changeView} .= '/changeView';
        }
    }

    $self->{actions} = $actionsRef;
}

sub keywords
{
    my ($self) = @_;
    #get the keywords from every component plus own ones and flatten them into
    #an array
    return [@{$self->SUPER::keywords()}, map { @{$_->keywords()} } @{$self->components()}];
}

# Method: setDirectory
#
#    Sets directory on its child components
#
# Parameters:
#
#     directory - string containing the directory key
#
sub setDirectory
{
    my ($self, $dir, $force) = @_;

    unless (defined $dir) {
        throw EBox::Exceptions::MissingArgument('dir');
    }

    $self->{directory} = $dir;

    foreach my $component (@{$self->components()}) {
        $self->_setComponentDirectory($component, $dir);
    }
}

# Method: directory
#
#        Get the current directory.
#
# Returns:
#
#        String - Containing the directory
#
sub directory
{
    my ($self) = @_;

    return $self->{directory};
}

sub _setComponentDirectory
{
    my ($self, $comp, $dir) = @_;

    $comp->{parent} = $self->{parent};

    if ($comp->isa('EBox::Model::DataTable')) {
        $dir .= '/' if $dir;
        $dir .=  $comp->name();
    }

    $comp->setDirectory($dir);
}

sub pageTitle
{
    my ($self) = @_;

    my $desc = $self->_description();
    if (exists $desc->{pageTitle}) {
        return $desc->{pageTitle};
    } else {
        return undef;
    }
}

sub headTitle
{
    my ($self) = @_;

    my $desc = $self->_description();
    if (exists $desc->{headTitle}) {
        return $desc->{headTitle};
    } else {
        return undef;
    }
}

sub HTMLTitle
{
    my ($self) = @_;

    my $pageTitle = $self->pageTitle();
    return undef unless ($pageTitle);

    return [
             {
               title => $pageTitle,
               link  => undef
             }
           ];
}

# Method: clone
#
#  This works as the EBox::DataTable::clone method it does the operation in all
#  composite's component
sub clone
{
    my ($self, $srcDir, $dstDir) = @_;
    my $origDir = $self->directory();

    try {
        # we need to do this operation in each component with the correct
        # directories for src and dst component
        my @components = @{ $self->components()  };
        foreach my $comp (@components) {
            $self->setDirectory($srcDir, 1);
            my $compSrcDir = $comp->directory();

            $self->setDirectory($dstDir, 1);
            my $compDstDir = $comp->directory();

            $comp->clone($compSrcDir, $compDstDir);
        }
    } catch ($e) {
        $self->setDirectory($origDir, 1);
        $e->throw();
    }
    $self->setDirectory($origDir, 1);
}

1;
