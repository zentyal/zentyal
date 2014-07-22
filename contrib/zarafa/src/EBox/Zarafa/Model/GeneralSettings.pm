# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Zarafa::Model::GeneralSettings;

use base 'EBox::Model::DataForm';

# Class: EBox::Zarafa::Model::GeneralSettings
#
#   Form to set the general configuration settings for the Zarafa server.
#

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;

# Group: Public methods

# Constructor: new
#
#       Create the new GeneralSettings model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Zarafa::Model::GeneralSettings> - the recently
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
#
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (exists($params_r->{jabber})) {
        if (EBox::Global->modExists('jabber')) {
            EBox::Global->modChange('jabber');
        }
    }
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
                                fieldName     => 'soap',
                                printableName => __('Enable Outlook Access'),
                                editable      => 1,
                                defaultValue => 0,
                                help => __('Enable SOAP connections for Outlook access.'),
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'jabber',
                                printableName => __('Enable Instant Messaging integration'),
                                editable      => 1,
                                defaultValue  => 0,
                                help => __('Enable Instant Messaging integration Zarafa Webapp.'),
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'spellChecking',
                                printableName => __('Enable Spell Checking'),
                                editable      => 1,
                                defaultValue  => 1,
                                help => __('Enable spell checking on Zarafa Webaccess.'),
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'activeSync',
                                printableName => __('Enable Active Sync'),
                                editable      => 1,
                                defaultValue  => 1,
                                help =>
__('Enable Active Sync (Microsoft Exchange syncronization protocol).'),
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'sso',
                                printableName => __('Enable Single Sign-On (Kerberos)'),
                                editable      => 1,
                                defaultValue  => 0,
                                help =>
                                  __('Enable only Single Sign-On on the Webaccess interface.'),
                               ),
       new EBox::Types::Select(
                                fieldName     => 'vHost',
                                printableName => __('Virtual host'),
                                editable      => 1,
                                populate => \&_virtualHosts,
                                disableCache => 1,
                                defaultValue => 'disabled',
                                help =>
__('Enable Zarafa access only on this virtual host under /webaccess and /webapp.'),
                               ),
      );

    my $dataTable =
      {
       tableName          => 'GeneralSettings',
       printableTableName => __('General configuration settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       messages           => {
                              update => __('General Zarafa server configuration settings updated.'),
                             },
       modelDomain        => 'Zarafa',
      };

    return $dataTable;
}

sub _virtualHosts
{
    my $webserver = EBox::Global->getInstance()->modInstance('webserver');
    my @options = (
                       { value => 'disabled' , printableValue => __('Disabled') },
                  );
    foreach my $vhost (@{$webserver->virtualHosts()}) {
        if ($vhost->{'enabled'}) {
            push(@options, { value => $vhost->{'name'} , printableValue => $vhost->{'name'} });
        }
    }
    return \@options;
}

# Method: notifyForeignModelAction
#
#      Called whenever an action is performed on VHostTable model
#      to check if our configured virtual host is going to disappear.
#
# Overrides:
#
#      <EBox::Model::DataTable::notifyForeignModelAction>
#
sub notifyForeignModelAction
{
    my ($self, $modelName, $action, $row) = @_;

    if ($action eq 'del') {
        my $vhost = $row->valueByName('name');
        my $myRow = $self->row();
        my $selected = $myRow->valueByName('vHost');
        if ($vhost eq $selected) {
            $myRow->elementByName('vHost')->setValue('disabled');
            $myRow->store();
            return __('The deleted virtual host was selected for ' .
                      'Zarafa. Maybe you want to select another one now.');
        }
    }
    return '';
}

1;
