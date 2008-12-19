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



package EBox::MailFilter::Model::AntispamConfiguration;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;

use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::MailFilter::Types::AntispamThreshold;


# eBox exceptions used 
use EBox::Exceptions::External;


# XX TODO:
#  disable autolearnSpamThreshold and autolearnHamThreshold when autolearn is off

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}


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
         new EBox::MailFilter::Types::AntispamThreshold  (
             fieldName     => 'spamThreshold',
             printableName => __('Spam threshold'),
             positive => 1,
             editable => 1,
             defaultValue => 5,
             help         => __('The score threshold to mark a message as spam'),
                               ),
         new EBox::Types::Text ( 
             fieldName => 'spamSubjectTag', 
             printableName => __('Spam subject tag'),
             editable => 1,
             optional => 1,
             help  => __('Tag which will be added to the spam mail subject'),
                               ),
         new EBox::Types::Boolean ( 
                                fieldName => 'bayes', 
                                printableName => __('Use bayesian classifier'),
                                editable => 1,
                                defaultValue => 1,
                               ),
         new EBox::Types::Boolean ( 
          fieldName => 'autoWhitelist', 
          printableName => __('Auto-whitelist'),
          editable => 1,
          defaultValue => 1,
          help => __('Change the score of mail according to the sender history'),
                               ),
         new EBox::Types::Boolean ( 
            fieldName => 'autolearn', 
            printableName => __('Auto-learn'),
            editable => 1,
            defaultValue => 1,
 help => __('Feedback the learning system with messages that reach the threshold'
 ),
                                  ),
         new EBox::MailFilter::Types::AntispamThreshold ( 
         fieldName => 'autolearnSpamThreshold', 
         printableName => __('Autolearn spam threshold'),
         positive => 1,
         editable => 1,
         defaultValue => 11,
         help  => __('Spam messages with a score equal or greater than this threshold will be added to the learning system '),
                               ),
         new EBox::MailFilter::Types::AntispamThreshold (
             fieldName => 'autolearnHamThreshold', 
             printableName => __('Autolearn ham threshold'),
             editable => 1,
             defaultValue => -1,
            help  => __('Ham messages with a score below this threshold will be added to the learning system'),
                              ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Antispam configuration'),
                      modelDomain        => 'MailFilter',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}


sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;

  $self->_checkThresholds( $action, $params_r, $actual_r);
}


sub _checkThresholds
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if ( not (
              (exists $params_r->{spamThreshold}) or
              (exists $params_r->{autolearn}) or
              (exists $params_r->{autolearnSpamThreshold}) or
              (exists $params_r->{autolearnHamThreshold}) 
             )
       ) {
        # no thresholds conflicts possibe
        return;
    }


    my $autolearn = _attrValue('autolearn', $params_r, $actual_r);
    if (not $autolearn) {
        # no threshold conflict possible
        return;
    }

    my $spamThreshold = _attrValue('spamThreshold', $params_r, $actual_r);
    my $autolearnSpamThreshold = _attrValue('autolearnSpamThreshold', $params_r, $actual_r);
    my $autolearnHamThreshold = _attrValue('autolearnHamThreshold', $params_r, $actual_r);
    
    EBox::debug("THTH $spamThreshold $autolearnSpamThreshold $autolearnHamThreshold");


    if (not $autolearnSpamThreshold) {
        throw EBox::Exceptions::External(
           __('You must define autolearn spam threshold when autolearn option is active')
                                        );
    }

    if (not $autolearnHamThreshold) {
        throw EBox::Exceptions::External(
           __('You must define autolearn ham threshold when autolearn option is active')
                                        );
    }

    if ($autolearnSpamThreshold < $spamThreshold) {
       throw EBox::Exceptions::External(
         __("The spam's autolearn threshold cannot be lower than the default spam's treshold ")
                                       );
    }

    if ($autolearnHamThreshold >= $spamThreshold) {
        throw EBox::Exceptions::External(
            __("The ham's autolearn threshold canot be higher or equal than the default spam level")
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

