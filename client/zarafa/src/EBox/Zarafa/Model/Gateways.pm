# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::Zarafa::Model::Gateways;

# Class: EBox::Zarafa::Model::Gateways
#
#   Form to set the general configuration settings for the Zarafa server.
#
use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Exceptions::External;

# Group: Public methods

# Constructor: new
#
#       Create the new Gateways model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Zarafa::Model::Gateways> - the recently
#       created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: validateTypedRow
#
#   Check if mail services are disabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $pop3 = exists $params_r->{pop3} ? $params_r->{pop3}->value() :
                                          $actual_r->{pop3}->value();
    my $pop3s = exists $params_r->{pop3s} ? $params_r->{pop3s}->value() :
                                          $actual_r->{pop3s}->value();
    my $imap = exists $params_r->{imap} ? $params_r->{imap}->value() :
                                          $actual_r->{imap}->value();
    my $imaps = exists $params_r->{imaps} ? $params_r->{imaps}->value() :
                                          $actual_r->{imaps}->value();

    my $mail = EBox::Global->modInstance('mail');
    my $services = $mail->model('RetrievalServices');

    my $serviceConflict = undef;

    if ($pop3 and $services->pop3Value()) {
        $serviceConflict = 'POP3';
    } elsif ($pop3s and $services->pop3sValue()) {
        $serviceConflict = 'POP3S';
    } elsif ($imap and $services->imapValue()) {
        $serviceConflict = 'IMAP';
    } elsif ($imaps and $services->imapsValue()) {
        $serviceConflict = 'IMAPS';
    }

    if (defined $serviceConflict) {
        throw EBox::Exceptions::External(__x('To enable Zarafa {service} gateway you must disable {service} mail retrieval service. You can do it at {ohref}Mail General Configuration{chref}.',
service => $serviceConflict,
ohref => q{<a href='/ebox/Mail/Composite/General/'>},
chref => q{</a>}));
    }
}

# Method: precondition
#
#   Check if there is at least one vdomain.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');
    my $model = $mail->model('VDomains');

    return (scalar ($model->ids()) > 0);
}

# Method: preconditionFailMsg
#
#   Returns message to be shown on precondition fail
#
sub preconditionFailMsg
{
    my ($self) = @_;

    return __x(
'To enable Zarafa POP3 and IMAP gateways you need at least one virtual domain. You can do it at {ohref}Virtual Mail Domains{chref}.',
ohref => q{<a href='/ebox/Mail/View/VDomains/'>},
chref => q{</a>},
        );
}

# Group: Protected methods

# Method: _table
#
#       The table description.
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
      (
       new EBox::Types::Boolean(
                                fieldName     => 'pop3',
                                printableName => __('Enable POP3 gateway'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'pop3s',
                                printableName => __('Enable POP3S gateway'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'imap',
                                printableName => __('Enable IMAP gateway'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'imaps',
                                printableName => __('Enable IMAPS gateway'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'ical',
                                printableName => __('Enable iCAL gateway'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'icals',
                                printableName => __('Enable iCAL SSL gateway'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       # FIXME update firewall based on this
      );

    my $dataTable =
      {
       tableName          => 'Gateways',
       printableTableName => __('Zarafa gateways configuration settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       messages           => {
                              update => __('Zarafa gateways configuration settings updated.'),
                             },
       modelDomain        => 'Zarafa',
       help               => __('Zarafa gateways allow access to users mailboxes using POP3 and IMAP protocols.'),
      };

    return $dataTable;
}

1;
