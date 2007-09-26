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

# Class: EBox::Model::Composite
#
#      This class is intended to hold a number of models inside. This
#      composite class will have a defined layout. This layout will be
#      used to establish the output on the view.
#
#      The possible components should be subclasses of:
#
#      - <EBox::Model::DataTable>
#      - <EBox::Model::Composite>
#
#      The possible layout that it will implemented are the following:
#
#      - top-bottom - the components will be shown from top to the
#      bottom in the given order
#      - tabbed     - the components will be shown in a tab way
#

package EBox::Model::Composite;

use strict;
use warnings;

# EBox uses
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Model::CompositeManager;
use EBox::Model::ModelManager;

# Other modules uses
use Error qw(:try);

#################
# Dependencies
#################
use Perl6::Junction qw(any);

# Constants

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

      my ($class) = @_;

      my $self = {};
      bless ( $self, $class );

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
#      comprises. The elements are <EBox::Model::DataTable> or
#      <EBox::Model::Composite>.
#
sub components
  {

      my ($self) = @_;

      for (my $idx = 0; $idx < scalar (@{$self->{components}}); $idx++) {
          my $component = $self->{components}->[$idx];
          unless ( ref ( $component )) {
              my $componentName = $component;
              $component = $self->_lookupComponent($componentName);
              unless ( defined ( $component )) {
                  throw EBox::Exceptions::InvalidData(
                                                       data => 'component',
                                                       value => $componentName
                                                      );
              }
              $self->{components}->[$idx] = $component;
          }
      }

      return $self->{components};

  }

# Method: addComponent
#
#      Add a component to the composite. It must be a class of:
#      <EBox::Model::DataTable> or <EBox::Model::Composite>.
#
#      It does not check if the component is already in the
#      composite.
#
# Parameters:
#
#      component - an instance of <EBox::Model::DataTable> or
#      <EBox::Model::Composite> or String the name the component to add.
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidType> - thrown if any parameter has
#       not the correct type
#
#       <EBox::Exceptions::MissingArgument> -
#       thrown if any mandatory parameter is missing
#
#       <EBox::Exceptions::InvalidData> - thrown if the component name
#       given is not defined neither at the
#       <EBox::Model::ModelManager> nor at the <EBox::Model::CompositeManager>
#
sub addComponent
  {

      my ($self, $component) = @_;

      defined ( $component ) or
        throw EBox::Exceptions::MissingArgument('component');

      # Check if it a string
      unless ( ref ($component ) ) {
          # Delay the component instance search because of deep
          # recursion
          push ( @{$self->{components}}, $component);
          return;
      }

      unless ( $component->isa('EBox::Model::DataTable') or
               $component->isa('EBox::Model::Composite') ) {
          throw EBox::Exceptions::InvalidType( $component,
                                               'EBox::Model::DataTable ' .
                                               'or EBox::Model::Composite'
                                             );
      }

      push ( @{$self->{components}}, $component );

      return;

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

      my ($self, $layout ) = @_;

      defined ( $layout ) or
        throw EBox::Exceptions::MissingArgument('layout');

      unless (($layout eq 'top-bottom') or
              ($layout eq 'tabbed')) {
          throw EBox::Exceptions::InvalidData(
                       data  => 'layout',
                       value => $layout,
                       advice => __('It should be one of following values: ' .
                                    'top-bottom or tabbed')
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

# Method: name
#
#      Get the composite's name
#
# Returns:
#
#      String - the composite's name
#
sub name
  {

      my ($self) = @_;

      return $self->{name};

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

# Method: compositeDomain
#
#     Get the domain where the model is handled. That is, the eBox
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

      if ( exists ( $self->{menuNamespace} )) {
          return $self->{menuNamespace};
      } elsif ( defined ( $self->compositeDomain() )) {
          # This is autogenerated menuNamespace got from the composite
          # domain and its name
          return 'ebox/' . $self->compositeDomain() . '/Composite/' . $self->name();
      } else {
          return undef;
      }

  }

# Method: action
#
#      Accessor to the URLs where the actions are published to
#      run. In a composite type, two actions are possible:
#      - view - show the composite type within the whole eBox menu
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

      unless ( $actionName eq any('view', 'changeView') ) {
          throw EBox::Exceptions::InvalidData( data => __('Action'),
                                               value => $actionName,
                                               advice => __x('Actions to be taken ' .
                                                             'allowed are: {view} and ' .
                                                             '{cView}',
                                                             view => 'view',
                                                             cView => 'changeView',
                                                            ));
      }

      my $actionsRef = $self->{actions};

      if ( exists ($actionsRef->{$actionName}) ) {
          return $actionsRef->{$actionName};
      } else {
          throw EBox::Exceptions::DataNotFound( data => __('Action'),
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
#       to a <EBox::Model::DataTable> or
#       <EBox::Model::Composite>. *(Optional)* Default value: empty array
#
#       layout - String define the layout of the corresponding views
#       of the models. It can be one of the following: 'top-bottom' or
#       'tabbed' *(Optional)* Default value: 'top-bottom'
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

      $self->{components} = [];
      $self->{layout} = 'top-bottom';
      $self->{name} = ref( $self );
      $self->{printableName} = '';
      $self->{help} = '';
      $self->{compositeDomain} = delete ( $description->{compositeDomain} );
      $self->{menuNamespace} = delete ($description->{menuNamespace});

      if ( defined ( $description->{components} ) and
           not ( (ref ( $description->{components} ) eq 'ARRAY'))) {
          throw EBox::Exceptions::InvalidType( $description->{components}, 'array ref' );
      }


      if ( exists ($description->{components})) {
          foreach my $component (@{delete ( $description->{components} ) }) {
              $self->addComponent( $component );
          }
      }

      if ( exists ($description->{layout})) {
          $self->setLayout( delete ( $description->{layout} ));
      }

      if ( exists ($description->{name})) {
          $self->{name} = delete ( $description->{name} );
      }

      if ( exists ($description->{printableName})) {
          $self->{printableName} = delete ( $description->{printableName} );
      }

      if ( exists ($description->{help})) {
          $self->{help} = delete ( $description->{help} );
      }

      $self->{actions} = $description->{actions};

      # Set the Composite actions, do not ovewrite the user-defined actions
      $self->_setDefaultActions();


  }

# Method: _lookupComponent
#
#    Search for the component instance in the model manager or in the
#    composite manager.
#
# Parameters:
#
#    componentName - String the component's name
#
# Returns:
#
#    <EBox::Model::DataTable> - if the component refers to a model
#    <EBox::Model::Composite> - if the component refers to a composite
#
sub _lookupComponent
  {

      my ($self, $componentName) = @_;

      my $component;

      my $compManager = EBox::Model::CompositeManager->Instance();
      try {
          $component = $compManager->composite($componentName);
      } catch EBox::Exceptions::DataNotFound with {
          # Look up the model manager
          $component = undef;
      };

      unless ( defined ( $component )) {
          my $modelManager = EBox::Model::ModelManager->instance();
          # FIXME when the manager launches an exception
          $component = $modelManager->model($componentName);
      }

      return $component;

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
      if ( defined ( $self->compositeDomain() )) {
          unless ( exists $actionsRef->{view} ) {
              $actionsRef->{view} = '/ebox/' . $self->compositeDomain() .
                '/Composite/' . $self->name();
          }
          unless ( exists $actionsRef->{changeView} ) {
              $actionsRef->{changeView} = '/ebox/' . $self->compositeDomain() .
                '/Composite/' . $self->name() . '/changeView';
          }
      }

      $self->{actions} = $actionsRef;

  }

1;
