# Copyright (C) 2008-2012 Zentyal S.L.
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

# Class: EBox::Events::Model::Dispatcher::Jabber
#
#

package EBox::Events::Model::JabberDispatcherConfiguration;

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Port;
use EBox::Types::Text;
use EBox::Types::Host;
use EBox::Types::Select;
use EBox::Types::Password;
use EBox::Types::Select;

# Group: Public methods

# Constructor: new
#
#     Create the configure jabber dispatcher form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Event::Dispatcher::Model::Jabber>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Group: Protected methods

sub _populateSSL
{
    my @opts = ();
    push (@opts, { value => 'none', printableValue => __('None') });
    push (@opts, { value => 'ssl', printableValue => __('SSL') });
    push (@opts, { value => 'tls', printableValue => __('TLS') });
    return \@opts;
}

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my @tableDesc =
        (
        new EBox::Types::Host(
            fieldName     => 'server',
            printableName => __('Jabber Server'),
            size          => 12,
            editable      => 1,
        ),
        new EBox::Types::Port(
            fieldName     => 'port',
            printableName => __('Port'),
            size          => 4,
            editable      => 1,
            defaultValue  => 5222,
        ),
        new EBox::Types::Select(
            fieldName     => 'ssl',
            printableName => __('SSL'),
            editable      => 1,
            populate      => \&_populateSSL,
        ),
        new EBox::Types::Text(
            fieldName     => 'user',
            printableName => __('Username'),
            size          => 12,
            editable      => 1,
        ),
        new EBox::Types::Password(
            fieldName     => 'password',
            printableName => __('Password'),
            size          => 12,
            editable      => 1,
        ),
        new EBox::Types::Text(
            fieldName     => 'adminJID',
            printableName => __('Administrator Account'),
            size          => 18,
            editable      => 1,
            help          => __('Destination Jabber account to send the messages to.'),
        ),
        );

    my $dataForm =
        {
            tableName          => 'JabberDispatcherConfiguration',
            printableTableName => __('Configure Jabber Dispatcher'),
            modelDomain        => 'Events',
            defaultActions     => [ 'editField' ],
            tableDescription   => \@tableDesc,
            class              => 'dataForm',
            help               => __('This dispatcher will send ' .
                                  'events to a Jabber account.'),
            messages           => {
                                update => __('Jabber dispatcher configuration updated.'),
                                  },
        };

    return $dataForm;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to
#   provide a custom HTML title with breadcrumbs
#
sub viewCustomizer
{
    my ($self) = @_;

    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([
        {
            title => __('Events'),
            link  => '/Events/Composite/General#ConfigureDispatchers',
        },
        {
            title => __('Jabber Dispatcher'),
            link  => ''
        }
    ]);

    return $custom;
}

1;
