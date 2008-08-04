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

package EBox::MailFilter::Model::AntispamACL;
use base 'EBox::Model::DataTable';


# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::MailFilter::Types::AmavisSender;

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
     new EBox::MailFilter::Types::AmavisSender(
                             fieldName     => 'sender',
                             printableName => __('Mail sender'),
                             unique        => 1,
                             editable      => 1,
                            ),
     new EBox::Types::Select(
                                    fieldName     => 'policy',
                                    printableName => __('Policy'),
                                    populate      => \&_populatePolicy,
                                    editable      => 1,
                                   ),
    );

  my $dataTable =
    {
     tableName          => __PACKAGE__->nameFromClass,
     printableTableName => __(q{Sender policy}),
     modelDomain        => 'mail',
     'defaultController' => '/ebox/MailFilter/Controller/AntispamACL',
     'defaultActions' => [      
                          'add', 'del',
                          'editField',
                          'changeView'
                         ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     rowUnique          => 1,
     printableRowName   => __("sender policy"),
    };

}


sub _populatePolicy
{
    return [
            { value => 'whitelist', printableValue => __('whitelist') },
            { value => 'blacklist', printableValue => __('blacklist') },
            { value => 'process',   printableValue => __('process') },
           ]

}


sub validateTypedRow
{


}


# Method: whitelist
#
# Returns:
#   - reference to a list of whitelisted extensions
# 
sub whitelist
{
    my ($self) = @_;
    return $self->_listByPolicy('whitelist');
}



# Method: blacklist
#
# Returns:
#   - reference to a list of blacklisted extensions
# 
sub blacklist
{
    my ($self) = @_;
    return $self->_listByPolicy('blacklist');
}



sub _listByPolicy
{
    my ($self, $policy) = @_;

    my @list = grep {
        $_->elementByName('policy')->value() eq $policy
    } @{  $self->rows() };

    @list = map {
        $_->elementByName('extension')->value()
    } @list;

    return \@list;
}


1;

