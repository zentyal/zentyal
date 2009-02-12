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

package EBox::Squid::Model::DomainFilterCategoriesBase;
use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Validate;

use EBox::Sudo;

use Error qw(:try);
use File::Basename;



# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Squid::Model::DomainFilterFiles> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
}



# Method: _table
#

sub _tableHeader
  {

      my @tableHeader =
        (
         new EBox::Types::Text(
                               fieldName => 'category',
                               printableName => ('Category'),
                               unique   => 1,
                               editable => 0,
                              ),
         new EBox::Types::Select(
                               fieldName     => 'policy',
                               printableName => __('Policy'),
                               populate   => \&_populate,
                               editable => 1,
                              ),
         new EBox::Types::Text(
                               fieldName => 'dir',
                               printableName => 'categoryDir',
                               hidden => 1,
                               unique => 1,
                              )


        );

      return \@tableHeader;
  }


sub _populate
{
  my @elements = (
                  { value => 'default', printableValue => __(q{Default list's police}) },
                  { value => 'allow',  printableValue => __('Always allow') },
                  { value => 'filter', printableValue => __('Filter') },
                  { value => 'deny',   printableValue => __('Always deny') },
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
    return __('This list has not categories');
}


sub filesPerPolicy
{
    my ($self, $policy, $scope) = @_;

    my @files = ();

    my $defaultPolicy  = $self->parentRow()->valueByName('policy');

    foreach my $row ( @{ $self->rows() } ) {
        my $catPolicy = $row->valueByName('policy');
        if ($catPolicy eq 'default') {
            $catPolicy = $defaultPolicy;
        }

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

# # XXX ad-hack reimplementation until the bug in coposite's parent would be
# # solved 
# use EBox::Global;
sub parent
{
    my ($self) = @_;

    my $squid     = EBox::Global->modInstance('squid');

    if ($self->isa('EBox::Squid::Model::DomainFilterCategories')) {
        my $defaultFilterGroup = $squid->composite('FilterSettings');
    
        my $defaultParent =  $defaultFilterGroup->componentByName('DomainFilterFiles', 1);



        return $defaultParent;
   }


    my $filterProfiles = $squid->model('FilterGroup');
    my $dir = $self->directory();
    my @parts = split '/', $dir;
    my $rowId = $parts[-6]; # 8

    my $granparentRow = $filterProfiles->row($rowId);
    use Devel::StackTrace;
      my $trace = Devel::StackTrace->new;

    EBox::debug($trace->as_string);

    EBox::debug("grandparent id: $rowId dir: $dir row: $granparentRow");
    my $filterPolicy  = $granparentRow->elementByName('filterPolicy')->foreignModelInstance();

    
    my $parent =  $filterPolicy->componentByName('FilterGroupDomainFilterFiles', 1);

#    EBox::debug("PPARENT $parent");

    return $parent;
}


# sub parentRow
# {
#     my ($self) = @_;

#     my $parent = $self->parent();

#     my $dir = $self->directory();
#     my @parts = split '/', $dir;

#     my $rowId = $parts[-2];


#     EBox::debug("Categoreis ID $rowId\n\n");

#     return $parent->row($rowId);
# }


1;

