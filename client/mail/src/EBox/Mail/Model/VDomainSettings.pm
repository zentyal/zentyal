# Copyright (C) 2009-2010 eBox Technologies S.L.
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


package EBox::Mail::Model::VDomainSettings;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::MailAddress;




# eBox exceptions used
use EBox::Exceptions::External;



sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


#
sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Union(
                              fieldName => 'alwaysBcc',
                              printableName =>
                                __('Send a copy of all mail domains'),
                              help => 
 __('The mail will be a Blind Carbon Copy (BCC).'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'disabled',
                                  'printableName' => __('Disabled'),
                                  ),
                              new EBox::Types::MailAddress(
                                  'fieldName' => 'bccAddress',
                                  'printableName' => __('Address to sent the copy'),
                                  'editable'  => 1,
                                  'min'       => 1,
                                      ),
                                  ],
             ),

        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Virtual domain settings'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}

#
sub bccAddress
{
    my ($self) = @_;

    my $alwaysBcc = $self->row()->elementByName('alwaysBcc');
    if ($alwaysBcc->selectedType eq 'disabled') {
        return undef;
    }

    my $address = $alwaysBcc->subtype()->value();
    return $address;
}
1;

