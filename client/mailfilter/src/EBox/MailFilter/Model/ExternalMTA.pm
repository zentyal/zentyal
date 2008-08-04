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
use strict;
use warnings;

package EBox::MailFilter::Model::ExternalMTA;
use base 'EBox::Model::DataTable';
# Class:
#
#    EBox::Mail::Model::ObjectPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Host;

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
}

# Group: Protected methods

# Method: _table
#
#       The table description 
#
sub _table
{
  my @tableHeader =
    (
     new EBox::Types::Host(
                             fieldName     => 'mta',
                             printableName => __('External mail server'),
                             unique        => 1,
                             editable      => 1,
                            ),
     new EBox::Types::Boolean(
                                    fieldName     => 'allow',
                                    printableName => __('Allow connection'),
                                    editable      => 1,
                                   ),
    );

  my $dataTable =
    {
     tableName          => __PACKAGE__->nameFromClass,
     printableTableName => __(q{External mail servers}),
     modelDomain        => 'Mail',
     'defaultController' => '/ebox/MailFilter/Controller/ExternalMTA',
     'defaultActions' => [      
                          'add', 'del',
                          'editField',
                          'changeView'
                         ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
     printableRowName   => __("external mail server"),
     help               => __("Here you can specify which external mail servers can connect to the mail filter"),
    };

}



# Method: allowed
#
# Returns:
#   - reference to a list of MTA for which connection is allowed
# 
sub allowed
{
    my ($self) = @_;
    my @allowed = grep {
        $_->elementByName('allow')->value()
    } @{  $self->rows() };

    @allowed = map {
        $_->elementByName('mta')->value()
    } @allowed;

    return \@allowed;
}




sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;
  if (not exists $params_r->{mta}) {
      return;
  }

  my $mta = $params_r->{mta}->value();
  
  # check that mta sin't internal
  my $internal;
  if ( $mta =~ m/^[\d.]+$/ ) {
      $internal =  EBox::Validate::isIPInNetwork('127.0.0.0', '255.0.0.0', $mta);
  } else {
      $internal = $mta eq 'localhost';
  }
  
  if ($internal) {
      throw EBox::Exceptions::External(
                                       __x('Invalid external MTA {mta}. Local network addresses are not allowed', mta => $mta)
                                      );
  }

}


1;

