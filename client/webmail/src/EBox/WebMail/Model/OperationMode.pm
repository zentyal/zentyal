# Copyright (C) 2009 eBox Technologies
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


package EBox::WebMail::Model::OperationMode;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;


# eBox exceptions used
use EBox::Exceptions::External;

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}



sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Select(
                               fieldName => 'mode',
                               printableName => __('Mode'),
                               editable => 1,
                               populate => \&_populateMode,
                              ),
 
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Operation mode'),
                      modelDomain        => 'WebMail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}



sub _populateMode
{
    my ($self) = @_;
    my @options;

    my $mailEnabled = 0;
    my $mail = EBox::Global->modInstance('mail');
    if (defined $mail) {
        $mailEnabled = $mail->isEnabled();
    }

    my $eboxOption = {
                      value => 'ebox',
                      printableValue => __(q{eBox's mail service}),
                     };
    if (not $mailEnabled) {
        $eboxOption->{disabled} = 'disabled';
    }

    push @options, $eboxOption;


    push @options, {
                     value => 'remote',
                     printableValue => __('Remote server'),
                    };

    return \@options;
}


sub usesEBoxMail
{
    my ($self) = @_;
    my $mode = $self->row()->elementByName('mode')->value();
    return $mode eq 'ebox';
}





1;

