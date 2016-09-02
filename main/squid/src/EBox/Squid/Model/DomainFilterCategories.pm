# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Squid::Model::DomainFilterCategories;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Validate;
use EBox::Sudo;
use EBox::Config;
use EBox::Squid::Types::ListArchive;

use TryCatch;
use File::Basename;

my $categoriesFileDir = '/var/lib/zentyal/files/squid';

my %validParentDirs = %{ EBox::Squid::Types::ListArchive::validParentDirs() };
my %validBasename = %{ EBox::Squid::Types::ListArchive::validBasename() };

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
#   If a category directory is present:
#    - adds its row if it is not already in the table
#    - turn the present flag to on if it was off
#
#   If a category directory is not present:
#     - removes its from table UNLESS its present flag is off
sub syncRows
{
    my ($self, $currentRows) = @_;
    my $modelConfDir = $self->directory();

    my @dirs = glob(EBox::Squid::Types::ListArchive::unpackPath() .  "/*");
    if (not exists $self->{seenListDirectories}) {
        $self->{seenListDirectories} = {};
    }
    if (not exists $self->{seenListDirectories}->{$modelConfDir}) {
        $self->{seenListDirectories}->{$modelConfDir} = {};
    }

    my %pathsToRemove = map { $_ => 1} @{ $self->parentModule()->pathsToRemove('save')  };
    my $lists;
    foreach my $dir (@dirs) {
        if (exists $pathsToRemove{$dir}) {
            next;
        }
        if ($self->{seenListDirectories}->{$modelConfDir}->{$dir}) {
            next;
        } else {
            $self->{seenListDirectories}->{$modelConfDir}->{$dir} = 1;
        }

        my @files =  @{ EBox::Sudo::root("find '$dir'") };

        my $filePathRe = qr{^$dir/(.*?)/(.*)/(.*?)$};
        my $listname = basename($dir);
        foreach my $file (@files) {
            chomp $file;
            my ($parentDir, $category, $basename) = $file =~ m{$filePathRe};
            next unless $basename;
            next unless exists $validParentDirs{$parentDir};
             if (exists $validBasename{$basename}) {
                 my $dir = "$dir/$parentDir/$category";
                 unless (exists $lists->{$listname}) {
                     $lists->{$listname} = {};
                 }
                 $lists->{$listname}->{$category} = $dir;
             }
        }
    }

    my $modified = 0;

    foreach my $list (keys %{$lists}) {
        my %categories = %{$lists->{$list}};
        my %current;
        foreach my $id (@{ $currentRows }) {
            my $row =  $self->row($id);
            next if $row->valueByName('list') ne $list;
            my $rowCategory = $row->valueByName('category');
            my $present = $row->valueByName('present');
            # remove if not file and present == true (present ==false we assume
            # thre is not file)
            if ($present and (not exists $categories{$rowCategory}) ) {
               $self->removeRow($id);
               $modified = 1;
           } else {
               $current{$rowCategory} =  $present ? undef : $row;
           }
        }

        foreach my $category (keys %categories) {
            if (not exists $current{$category}) {
                my $dir = $categories{$category};
                $self->add(category => $category, list => $list, present => 1, dir => $dir, policy => 'ignore');
                $modified = 1;
            } else {
                my $noPresentRow = $current{$category};
                if ($noPresentRow) {
                    $noPresentRow->elementByName('present')->setValue(1);
                    $noPresentRow->store();
                }
                $modified = 1;
            }
        }
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
                'HTMLViewer' => '/ajax/viewer/booleanViewer.mas',
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
        noDataMsg          => __('There are no categories defined. You need to add categorized lists files if you want to filter by category.'),
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

# Function: dgAllowed
#
#       Fetch the allowed domains files for dansguardian
#
# Returns:
#
#       Array ref - containing the files
sub dgAllowed
{
    my ($self) = @_;
    return $self->_filesByPolicy('allow', 'domains');
}

# Function: dgAllowedUrls
#
#       Fetch the allowed urls files for dansguardian
#
# Returns:
#
#       Array ref - containing the files
#
sub dgAllowedUrls
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

sub cleanSeenListDirectories
{
    my ($self) = @_;
    $self->{seenListDirectories} = {};
}

sub markCategoriesAsNoPresent
{
    my ($self, $list) = @_;
    # using _ids to not call syncRows
    # the rows which are really present we will marked as such
    # i nthe next call of ids()/syncRows()
    foreach my $id (@{ $self->_ids() }) {
        my $row = $self->row($id);
        if ($row->valueByName('list') ne $list) {
            next;
        }
        $row->elementByName('present')->setValue(0);
        $row->store();
    }
}

sub removeNoPresentCategories
{
    my ($self) = @_;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        if (not $row->valueByName('present')) {
            $self->removeRow($id, 1);
        }
    }
}

sub _aclBaseName
{
    my ($sef, $row) = @_;
    my $aclName = $row->valueByName('list') . '~dc~' . $row->valueByName('category');
    $aclName =~ s/\s/~~/g;
    return $aclName;
}

sub squidSharedAcls
{
    my ($self) = @_;
    my @acls;

    my $loadUrlLists =  $self->_loadUrlLists();
    foreach my $id (@{ $self->ids()}) {
        my $row = $self->row($id);
        if (not $row->valueByName('present')) {
            next;
        } elsif ($row->valueByName('policy') eq 'ignore') {
            next;
        }
        my $basename = $self->_aclBaseName($row);
        my $dir = $row->valueByName('dir');

        my $domainsFile = "$dir/domains.squid";
        if (-r $domainsFile) {
            my $name = $basename . '~dom';
            push @acls, [$name => qq{acl $name dstdomain "$domainsFile"}];
        }

        if ($loadUrlLists) {
            my $urlsFile = "$dir/urls";
            if (-r $urlsFile) {
                my $name = $basename . '~urls';
                push @acls, [$name => qq{acl $name url_regex -i "$urlsFile"}];
            }
        }
    }

    return \@acls;
}

sub squidRulesStubs
{
    my ($self, $profileId, %params) = @_;
    my $acls = $params{sharedAcls};
    $acls or return []; # no acls nothing to do..

    my @types = qw(dom);
    if ($self->_loadUrlLists) {
        push @types, 'urls';
    }

    my @rules;
    foreach my $id (@{ $self->ids()}) {
        my $row = $self->row($id);
        if (not $row->valueByName('present')) {
            next;
        }
        my $policy = $row->valueByName('policy');
        if ($policy eq 'ignore') {
            next;
        }
        my $basename = $self->_aclBaseName($row);
        foreach my $type (@types) {
            my $aclName = $basename . '~' . $type;
            exists $acls->{$aclName} or
                next;
            my $rule =  {
                     type => 'http_access',
                     acl => $aclName,
                     policy => $policy
                    };
            push @rules, $rule;
        }
    }

    return \@rules;
}

sub _loadUrlLists
{
    return  EBox::Config::boolean('load_url_lists');
}

1;
