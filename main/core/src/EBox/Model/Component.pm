# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Model::Component;

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;
use EBox::Exceptions::ComponentNotExists;

use Encode;
use TryCatch;
use POSIX qw(getuid);

# Method: parentModule
#
#        Get the parent confmodule for the model
#
# Returns:
#
#        <EBox::Module::Config> - the module
#
sub parentModule
{
    my ($self) = @_;

    return $self->{'confmodule'};
}

# Method: global
#
# returns a EBox::Global instance with the correct read-only status
#
sub global
{
    my ($self) = @_;

    return $self->{'confmodule'}->global();
}

# Method: modelGetter
#
# return a sub which is a getter of the specified model from the specified
# module. Useful for foreignModel attribute
#
#  If the module does not exist the getter will return undef
#
#  Parameters:
#    module
#    model
sub modelGetter
{
    my ($self, $module, $model) = @_;
    my $global = $self->global();
    my $modelInstance = undef;
    if ($global->modExists($module)) {
        $modelInstance = $global->modInstance($module)->model($model);
    }
    return sub{
        return $modelInstance;
    };
}

# Method: pageTitle
#
#   This method must be overriden by the component to show a page title
#
# Return:
#
#   string or undef
#
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
#
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
#
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
    if ($help) {
        return [ $self->_extract_keywords($help) ];
    } else {
        return [];
    }
}

# Method: parent
#
#   Return component's parent.
#   If the component is child of a composite the parent is the top's composite parent
#
# Returns:
#
#   An instance of a class implementing <EBox::Model::DataTable> or <EBox::Model::Composite>
#
sub parent
{
    my ($self) = @_;

    return $self->{'parent'};
}

sub directory
{
    my ($self) = @_;

    throw EBox::Exceptions::NotImplemented('directory');
}

# Method: parentRow
#
#    Is the component is a submodel of a DataTable return the row where the
#    parent model resides
#
# Returns:
#
#       row object or undef if there is not
#
sub parentRow
{
    my ($self) = @_;

    unless ($self->{parent}) {
        return undef;
    }

    my $dir = $self->directory();
    my @parts = split ('/', $dir);

    my $rowId = undef;
    for (my $i = scalar (@parts) - 1; $i > 0; $i--) {
        if (($parts[$i] eq 'form') or ($parts[$i - 1] eq 'keys')) {
            $rowId = $parts[$i];
            last;
        }
    }

    if (not defined $rowId) {
        return undef;
    }

    my $row = $self->{parent}->row($rowId);
    unless ($row) {
        throw EBox::Exceptions::ComponentNotExists("Cannot find row with rowId $rowId. Component directory: $dir.");
    }

    return $row;
}

# Method : executeOnBrothers
#
#  Execute the given sub in all brothers of the component. The sub receives the
#  brother as argument and is not executed on the component itself
#
#  Parameters:
#       toExecuteSub - reference to the sub  to execute
#
#  Named parameters:
#      subModelField - field name of the component's subfield in the parent rows (mandatory)
#      returnFirst   - cut execution and return the result on the first true result value  (default: false)
sub executeOnBrothers
{
    my ($self, $toExecuteSub, %options) = @_;
    my $returnFirst = $options{returnFirst};
    my $subModelField = $options{subModelField};
    $subModelField or
        throw EBox::Exceptions::MissingArgument('subModelField');

    my $parentRow = $self->parentRow();
    if (not $parentRow) {
        throw EBox::Exceptions::Internal('This component is not child of a table');
    }
    my $parentRowId = $parentRow->id();
    my $parent = $self->parent();

    my $res;
    my $dir  = $self->directory();
    try {
        foreach my $id (@{ $parent->ids()}) {
            if ($id eq $parentRowId) {
                # dont execute on itself
                next;
            }
            my $row = $parent->row($id);
            my $brother = $row->subModel($subModelField);
            $res = $toExecuteSub->($brother);
            if ($res and $returnFirst) {
                last;
            }
        }
    } catch ($e) {
        $self->setDirectory($dir);
        $e->throw();
    }
    $self->setDirectory($dir);

    return $res;
}

# Method: menuFolder
#
#   Override this function if you model is placed within a folder
#   from other module
#
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

    if ($self->isa('EBox::Model::DataTable')) {
        my $htmlTitle = @{$self->viewCustomizer()->HTMLTitle()};
        # Do not show warning on nested components
        return '' unless ($pageTitle or $htmlTitle);
    } elsif ($self->isa('EBox::Model::Composite')) {
        return '' unless ($pageTitle);
    } else {
        return '';
    }

    my $module = $self->parentModule();;
    unless (defined ($module) and $module->isa('EBox::Module::Service')) {
        return '';
    }

    return $module->disabledModuleWarning();
}

# Method: userCorner
#
# Whether this component can be used in the usercorner. Defualt implementation
# always return false
#
#  Returns:
#          boolean - whether this component can be used in usercorner
sub userCorner
{
    return 0;
}

# parse string to extract keywords
sub _extract_keywords
{
    my ($self, $str) = @_;

    my @w = ();
    if(defined($str)) {
        @w = split('\W+', lc($str));
        @w = grep { length($_) >= 3 } @w;
    }
    return @w;
}

1;
