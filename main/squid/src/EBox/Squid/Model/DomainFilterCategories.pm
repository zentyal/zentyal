# Copyright (C) 2009-2012 eBox Technologies S.L.
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

package EBox::Squid::Model::DomainFilterCategories;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Validate;
use EBox::Sudo;

use Error qw(:try);
use File::Basename;
use Perl6::Junction qw(any);

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my @dirs = </var/lib/zentyal/files/squid/*>;

    my $lists;

    foreach my $dir (@dirs) {
        my @files =  @{ EBox::Sudo::root("find $dir") };
        foreach my $file (@files) {
            chomp $file;
            my ($dirname, $listname, $category, $basename) = $file =~ m{^(.*)/(.*?)/BL/(.*)/(.*?)$};
            my $dir = "$dirname/$listname/BL/$category";

            if ($basename eq any(qw(domains urls))) {
                unless (exists $lists->{$listname}) {
                    $lists->{$listname} = {};
                }
                $lists->{$listname}->{$category} = $dir;
            }
        }
    }

    my $modified = 0;

    foreach my $list (keys %{$lists}) {

        my @currentRows = grep { $self->row($_)->valueByName('list') eq $list } @{$currentRows};
        my %current =
            map { $self->row($_)->valueByName('category') => 1 } @currentRows;

        my %categories = %{$lists->{$list}};
        my @toAdd = grep { not exists $current{$_} } keys %categories;
        foreach my $category (@toAdd) {
            my $dir = $categories{$category};
            $self->add(category => $category, list => $list, present => 1, dir => $dir, policy => 'ignore');
            $modified = 1;
        }

        # FIXME: instead of remove, set present to 0
        # Remove old rows
#       foreach my $id (@{$currentRows}) {
#           my $row = $self->row($id);
#           my $category = $row->valueByName('category');
#           unless (exists $new{$category}) {
#               $self->removeRow($id);
#               $modified = 1;
#           }
#       }
    }

    return $modified;
}

# Method: _table
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
            new EBox::Types::Text(
                fieldName => 'category',
                printableName => __('Category'),
                unique   => 0,
                editable => 0,
            ),
            new EBox::Types::Text(
                fieldName => 'list',
                printableName => __('List File'),
                unique   => 0,
                editable => 0,
            ),
            new EBox::Types::Boolean(
                fieldName => 'present',
                printableName => __('File Present'),
                editable => 0,
            ),
            new EBox::Types::Select(
                fieldName     => 'policy',
                printableName => __('Decision'),
                populate   => \&_populate,
                editable => 1,
            ),
            new EBox::Types::Text(
                fieldName => 'dir',
                hidden   => 1,
                unique   => 1,
                editable => 0,
            ),
    );

    my $dataTable = {
        tableName          => 'DomainFilterCategories',
        printableTableName => __('Domain categories'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __('category'),
        sortedBy           => 'category',
    };
}

sub _populate
{
    my @elements = (
                    { value => 'ignore', printableValue => __('None') },
                    { value => 'deny',   printableValue => __('Deny All') },
                    { value => 'allow',  printableValue => __('Allow All') },
                   );

    return \@elements;
}

sub precondition
{
    my ($self) = @_;

    $self->size() > 0;
}

sub preconditionFailMsg
{
    return __('There are no categories defined. You need to add categorized lists files if you want to filter by category.');
}

# Function: banned
#
#       Fetch the banned domains files
#
# Returns:
#
#       Array ref - containing the files
sub banned
{
    my ($self) = @_;
    return $self->_filesByPolicy('deny', 'domains');
}

# Function: allowed
#
#       Fetch the allowed domains files
#
# Returns:
#
#       Array ref - containing the files
sub allowed
{
    my ($self) = @_;
    return $self->_filesByPolicy('allow', 'domains');
}


# Function: bannedUrls
#
#       Fetch the banned urls files
#
# Returns:
#
#       Array ref - containing the files
#
sub bannedUrls
{
    my ($self) = @_;
    return $self->_filesByPolicy('deny', 'urls');
}

# Function: allowedUrls
#
#       Fetch the allowed urls files
#
# Returns:
#
#       Array ref - containing the files
#
sub allowedUrls
{
    my ($self) = @_;
    return $self->_filesByPolicy('allow', 'urls');
}

sub _filesByPolicy
{
    my ($self, $policy, $scope) = @_;

    my @files;
    foreach my $id (@{$self->enabledRows()}) {
        my $row = $self->row($id);
        my $present = $row->valueByName('present');
        next unless $present;

        my $thisPolicy = $row->valueByName('policy');
        if ($thisPolicy eq $policy) {
            my $dir = $row->valueByName('dir');
            if (-f "$dir/$scope") {
                push (@files, "$dir/$scope");
            }
        }
    }

    return \@files;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
sub viewCustomizer
{
    my ($self) = @_;

    my $custom = $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([]);

    return $custom;
}

1;
