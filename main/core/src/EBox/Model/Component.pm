# Copyright (C) 2008-2010 eBox Technologies S.L.
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


use EBox::Config::Redis;
# XXX maybe we should move this to another place
my $redis = EBox::Config::Redis->new();

use constant ORDER_PREFIX => '/ebox/componentOrder';

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
    my $path = $self->contextName();
    my $parentInfo = $self->_parentInfoSkippingComposite($path);
    if (not $parentInfo) {
        return undef;
    }

    if (EBox::Model::ModelManager->uninitialized()) {
        return undef;
    }    

    # since we have skipped composites it could only be a DataTable
    my $manager = EBox::Model::ModelManager->instance();
    return $manager->model($parentInfo->{path});
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
    my $path = $self->contextName();
    my $parentInfo = $self->_parentInfo($path);
    if ((not $parentInfo) or
        (not $parentInfo->{composite})) {
        return undef;
    }

    if (EBox::Model::CompositeManager->uninitialized()) {
        return undef;
    }    

    my $manager = EBox::Model::CompositeManager->Instance();
    return $manager->composite($parentInfo->{path});
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

    my $newParent;
    while ($newParent = $parentComposite->parentComposite() ) {
        $parentComposite = $newParent;
    }

    return $parentComposite;
}

sub parentComponent
{
    my ($self) = @_;
    my $path = $self->contextName();
    my $parentInfo = $self->_parentInfo($path);
    if (not $parentInfo) {
        return undef;
    }

    if ($parentInfo->{composite}) {
        my $manager = EBox::Model::CompositeManager->instance();
        return $manager->composite($parentInfo->{path});
    } else {
        my $manager = EBox::Model::ModelManager->instance();
        return $manager->model($parentInfo->{path});
    }
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

    if (defined($parent) and (not $parent->isa('EBox::Model::Component'))) {
        throw EBox::Exceptions::InvalidType( 'argument' => 'parent',
                                             'type' => ref $parent);
    }

    my $path = $self->contextName();
    my $key = $self->_orderKey($path);

    my $parentPath = $parent->contextName();
    my $parentComposite = $parent->isa('EBox::Model::Composite');

    $redis->set_string("$key/parent", $parentPath);
    $redis->set_bool("$key/parentComposite", $parentComposite);
}

sub _parentInfo
{
    my ($self, $path) = @_;
    my $key = $self->_orderKey($path);
    my $parentPath = $redis->get_string("$key/parent");
    defined $parentPath or
        return undef;
    my $composite =  $redis->get_bool("$key/parentComposite");
    return {
            path => $parentPath,
            composite => $composite,
           };
}

sub parentRow
{
    my ($self) = @_;

    my $parentInfo = $self->_parentInfo($self->contextName());
    if (not $parentInfo) {
        return undef;
    }

    my $dirsToRowId;
    if ($parentInfo->{composite}) {
        $dirsToRowId = 3;
    }
    else {
        $dirsToRowId = 2;
    }

    my $dir = $self->directory();
    my @parts = split '/', $dir;
    my $rowId = $parts[-$dirsToRowId];

    my $parent = $self->parent();
    $parent or
        return undef;
    my $row =  $parent->row($rowId);
    $row or
        throw EBox::Exceptions::Internal("Cannot find row with rowId $rowId. Component directory: $dir. Parent composite:" . $parentInfo->{composite});

    return $row;
}

sub _parentInfoSkippingComposite
{
    my ($self, $key) = @_;

    my $parentInfo;
    while ($parentInfo = $self->_parentInfo($key)) {
        if ($parentInfo->{composite} ) {
            $key = $self->_orderKey($parentInfo->{path});
        } else {
            return $parentInfo;
        }
    }

    return undef;
}

sub _orderKey
{
    my ($self, $name) = @_;
    if (not $name) {
        EBox::error("Component has not context name");
        return undef;
    }

    if (not $name =~ m{^/}) {
        $name = '/' . $name;
    }

    return ORDER_PREFIX . $name;
}

# Method: menuFolder
#
#       Override this function if you model is placed within a folder
#       from other module
sub menuFolder
{
    return undef;
}

1;
