# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Mail::Model::RetrievalServices;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Boolean;
use EBox::Types::Select;
use EBox::Exceptions::External;

# XXX TODO: disable ssl options when no service is enabled
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
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)
#   enabled (EBox::Types::Boolean>)
#
# The only avaiable action is edit and only makes sense for 'enabled'.
#
sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Boolean(
                                  fieldName => 'pop3',
                                  printableName => __('POP3 service enabled'),
                                  editable => 1,
                                  defaultValue => 1,
                                 ),
         new EBox::Types::Boolean(
                                  fieldName => 'pop3s',
                                  printableName => __('Secure POP3S service enabled'),
                                  editable => 1,
                                  defaultValue => 1,
                                 ),
         new EBox::Types::Boolean(
                                  fieldName => 'imap',
                                  printableName => __('IMAP service enabled'),
                                  editable => 1,
                                  defaultValue => 1,
                                 ),
         new EBox::Types::Boolean(
                                  fieldName => 'imaps',
                                  printableName => __('Secure IMAPS service enabled'),
                                  editable => 1,
                                  defaultValue => 1,
                                 ),
         new EBox::Types::Boolean(
                                  fieldName => 'fetchmail',
                                  printableName => __('Retrieve mail for external accounts'),
                                  help =>
                                      __(q{This allow users to retrieve mail for external accounts, the mail would be delivered to their local account. External accounts must be configured for each user.} ),
                                  editable => 1,
                                 ),
         new EBox::Types::Boolean(
                                  fieldName => 'managesieve',
                                  printableName => __('Manage Sieve scripts'),
                                  help =>
 __(q{This service allows to a user to manage his Sieve mail filtering scripts from a local client which speaks the ManageSieve protocol} ),
                                  editable => 1,
                                  defaultValue => 1,
                                 ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Mail retrieval services'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };

    return $dataForm;
}

sub activeProtocols
{
    my ($self) = @_;
    my %protocols;

    if ($self->pop3Value()) {
        $protocols{'pop3'} = 1;
    }

    if ($self->pop3sValue()) {
        $protocols{'pop3s'} = 1;
    }

    if ($self->imapValue()) {
        $protocols{'imap'} = 1;
    }

    if ($self->imapsValue()) {
        $protocols{'imaps'} = 1;
    }

    if ($self->managesieveValue()) {
        $protocols{'managesieve'} = 1;
    }

    return \%protocols;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $global = EBox::Global->getInstance();

    my $pop3 = exists $params_r->{pop3} ? $params_r->{pop3}->value() :
                                          $actual_r->{pop3}->value();
    my $pop3s = exists $params_r->{pop3s} ? $params_r->{pop3s}->value() :
                                          $actual_r->{pop3s}->value();
    my $imap = exists $params_r->{imap} ? $params_r->{imap}->value() :
                                          $actual_r->{imap}->value();
    my $imaps = exists $params_r->{imaps} ? $params_r->{imaps}->value() :
                                          $actual_r->{imaps}->value();

    # validate IMAP services changes
    if ((not exists $params_r->{imap}) and (not exists $params_r->{imaps})) {
        return;
    }

    foreach my $mod (@{ $global->modInstances() }) {
        if ($mod->can('validateIMAPChanges') and $mod->isEnabled()) {
            $mod->validateIMAPChanges($imap, $imaps);
        }
    }
}

1;
