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

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my @dirs = </var/lib/zentyal/files/squid/*>;
    my %categories;

    foreach my $dir (@dirs) {
        my @files =  @{ EBox::Sudo::root("find $dir") };
        foreach my $file (@files) {
            chomp $file;
            $file =~ m{^(.*)/(.*?)/(.*?)$};
            my $dirname  = $1 .'/' . $2;
            my $category = $2;
            my $basename = $3;

            if ($basename eq any(qw(domains urls))) {
                $categories{$category} = $dirname;
            }
        }
    }

    my %current =
        map { $self->row($_)->valueByName('category') => 1 } @{$currentRows};

    my $modified = 0;

    my @toAdd = grep { not exists $current{$_} } keys %categories;
    foreach my $category (@toAdd) {
        $self->add(category => $category, present => 1, dir => $categories{$category});
        $modified = 1;
    }

    # FIXME: instead of remove, set present to 0
    # Remove old rows
#    foreach my $id (@{$currentRows}) {
#        my $row = $self->row($id);
#        my $category = $row->valueByName('category');
#        unless (exists $new{$category}) {
#            $self->removeRow($id);
#            $modified = 1;
#        }
#    }

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
                printableName => ('Category'),
                unique   => 1,
                editable => 0,
            ),
            new EBox::Types::Boolean(
                fieldName => 'present',
                printableName => __('List Present'),
                editable => 0,
            ),
            new EBox::Types::Select(
                fieldName     => 'policy',
                printableName => __('Decision'),
                populate   => \&_populate,
                editable => 1,
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

sub filesPerPolicy
{
    my ($self, $policy, $scope) = @_;

    my @files = ();

    foreach my $id ( @{ $self->ids() } ) {
        my $row = $self->row($id);
        my $catPolicy = $row->valueByName('policy');

        if ($catPolicy ne $policy) {
            next;
        }

        my $dir = $row->valueByName('dir');
        my @dirFiles =  @{ EBox::Sudo::root("find $dir") };
        foreach my $file (@dirFiles) {
            chomp $file;
            my $basename = basename $file;

            if ($basename ne $scope) {
                next;
            }

            push @files, $file;
        }
    }

    return \@files;
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

    my @files = ();
    foreach my $id (@{$self->enabledRows()}) {
        my $row = $self->row($id);
        my $file = $row->elementByName('fileList');
        $file->exist() or
            next;

        my $path = $file->path();
        push @files, @{ $self->_archiveFiles($row, $policy, $scope) };
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

    my $squid = $self->parentModule();
    my $rowId = [split('/', $self->parentRow()->dir())]->[2];
    my $profile = $squid->model('FilterProfiles')->row($rowId)->valueByName('name');
    my $dir = "FilterProfiles/keys/$rowId/filterPolicy";
    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([
            {
                title => __('Filter Profiles'),
                link  => '/Squid/View/FilterProfiles',
            },
            {
                title => $profile,
                link  => "/Squid/Composite/ProfileConfiguration?directory=$dir#Domains",
            },
            {
                title => $self->parentRow()->valueByName('description'),
                link => ''
            }
    ]);

    return $custom;
}

1;
