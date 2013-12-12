# Copyright (C) 2008-2011 Zentyal S.L.
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

use EBox::Gettext;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::MissingArgument;

use Encode;
use Error qw(:try);
use POSIX qw(getuid);

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
#   Return the parent composite of this component object
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

# Method: topParentComposite
#
#   Return the top parent of the composite hierarchy where this component is
#   containded
#
# Returns:
#
#      component - an instance of <EBox::Model::Composite>
#      or undef if there's any
sub topParentComposite
{
    my ($self) = @_;

    my $parentComposite = $self->parentComposite();
    if (not defined $parentComposite) {
        return undef;
    }

    while (1) {
        my $newParent = $parentComposite->parentComposite();
        if (not defined $newParent) {
            return $parentComposite;
        }
        $parentComposite = $newParent;
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

# Method: parent
#
#   Return component's parent.
#   If the component is child of a composite the parent is the top's composite parent
#
# Returns:
#
#   An instance of a class implementing <EBox::Model::DataTable>
#
#  Warning: there are bug with this method for composites which are submodel of
#  a DataTable. A workaround is to reimplement this method in the class in a
#  less-general fashion
sub parent
{
    my ($self) = @_;
    my $parentComposite = $self->parentComposite();
    if ($parentComposite) {
        return $parentComposite->parent();
    }

    return $self->{'parent'};
}


# Method: setParent
#
#   Set model's parent
#
# Parameters:
#
#   An instance of a class implementing <EBox::Model::DataTable>
#
# Exceptions:
#
#   <EBox::Exceptions::InvalidType>
sub setParent
{
    my ($self, $parent) = @_;

    if (defined($parent) and (not $parent->isa('EBox::Model::DataTable'))) {
        throw EBox::Exceptions::InvalidType( 'argument' => 'parent',
                                             'type' => ref $parent);
    }

    $self->{'parent'} = $parent;
}

# Method: menuFolder
#
#   Override this function if you model is placed within a folder
#   from other module
sub menuFolder
{
    return undef;
}

# Method: disabledModuleWarning
#
#       Return the warn message to inform if the parent module is disabled
#
# Returns:
#
#       String - The warn message if the module is disabled
#
#       Empty string - if module is enabled
#
sub disabledModuleWarning
{
    my ($self) = @_;

    # Avoid to show warning if running in usercorner's apache
    return '' unless (getuid() == getpwnam(EBox::Config::user()));

    my $pageTitle = $self->pageTitle();
    my $module;

    if ($self->isa('EBox::Model::DataTable')) {
        my $htmlTitle = @{$self->viewCustomizer()->HTMLTitle()};
        # Do not show warning on nested components
        unless ($pageTitle or $htmlTitle) {
            return '';
        }
        $module = $self->parentModule();
    } elsif ($self->isa('EBox::Model::Composite') and $pageTitle) {
        $module = EBox::Global->modInstance(lc($self->compositeDomain()));
    } else {
        return '';
    }

    unless (defined ($module) and $module->isa('EBox::Module::Service')) {
        return '';
    }

    if ($module->isEnabled()) {
        return '';
    } else {
        # TODO: If someday we implement the auto-enable for dependencies with one single click
        # we could replace the Module Status link with a "Click here to enable it" one
        return __x("{mod} module is disabled. Don't forget to enable it on the {oh}Module Status{ch} section, otherwise your changes won't have any effect.",
                   mod => $module->printableName(), oh => '<a href="/ServiceModule/StatusView">', ch => '</a>');
    }
}

1;
