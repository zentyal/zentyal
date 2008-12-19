# Copyright (C) 2008 Warp Networks S.L.
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



package EBox::MailFilter::Model::POPProxyConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;

use EBox::Types::Boolean;
use EBox::Types::Port;
use EBox::Types::Text;

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


# TODO
#  antivirus and antispam option must be disabled if those sub-services aren't enabled

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# 
sub _table
{
    my @tableDesc = 
        ( 
         new EBox::Types::Boolean(
                                  fieldName => 'enabled',
                                  printableName => __('Enabled'),
                                  defaultValue => 1,
                                  editable => 1
                                 ),
#        new EBox::Types::Port(
#                              fieldName => 'port',
#                                printableName => __('Proxy port'),
#                              defaultValue => 8110,
#                              editable     => 1,
#                             ),
         new EBox::Types::Boolean ( 
                                fieldName => 'antivirus', 
                                printableName => __('Filter virus'),
                                editable => 1,
                                defaultValue => 1,
                               ),
         new EBox::Types::Boolean ( 
                                fieldName => 'antispam', 
                                printableName => __('Filter spam'),
                                editable => 1,
                                defaultValue => 1,
                               ),
         new EBox::Types::Text(
                               fieldName => 'ispspam',
                               printableName => __('ISP spam subject'),
                               editable => 1,
                               optional => 1,

                               help => __('This option allows you to set the string your ISP uses if
it processes your email for SPAM.'),
                              ),
        );

      my $dataForm = {
                      tableName          => 'POPProxyConfiguration',
                      printableTableName => __('POP transparent proxy configuration'),
                      modelDomain        => 'MailFilter',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };


  
    return $dataForm;
}

sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;

  my $antivirus = _attrValue('antivirus', $params_r, $actual_r);
  my $antispam  = _attrValue('antispam', $params_r, $actual_r);
  if ((not $antivirus) and (not $antispam)) {
      throw EBox::Exceptions::External(
       __('The POP transparent proxy must scan for something to be useful. If you do not need either antivirus of spam scan we suggest you turn it off')
                                      );
  }


}

sub _attrValue
{
    my ($attr, $params_r, $actual_r) = @_;

    if (exists $params_r->{$attr}) {
        return $params_r->{$attr}->value();
    }  

    if (exists $actual_r->{$attr}) {
        return $actual_r->{$attr}->value();
    }  

    throw EBox::Exceptions::Internal("Bad attribute $attr");

}


1;

