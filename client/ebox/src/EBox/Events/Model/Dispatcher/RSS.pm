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

# Class: EBox::Events::Model::Dispatcher::RSS
#
# This class is the model to configurate RSS dispatcher. It
# inherits from <EBox::Model::DataForm> since it is not a table but a
# simple form with two fields:
#
#     - link
#     - allowed - the allowed readers
#

package EBox::Events::Model::Dispatcher::RSS;

use base 'EBox::Model::DataForm';

# eBox uses
use EBox::Event::Dispatcher::RSS;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::IPAddr;
use EBox::Types::Link;
use EBox::Types::Select;
use EBox::Types::Union;
use EBox::Types::Union::Text;

################
# Dependencies
################
use XML::RSS;

# Constants

# Group: Public methods

# Constructor: new
#
#     Create the configure RSS dispatcher form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Event::Dispatcher::Model::RSS>
#
sub new
  {
      my $class = shift;

      my $self = $class->SUPER::new(@_);
      bless ( $self, $class);

      return $self;

  }

# Method: validateTypedRow
#
#
# Overrides:
#
#     <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
  {

      my ($self, $action, $params) = @_;

  }

# Method: formSubmitted
#
#       When the form is submitted, the model must set up the jabber
#       dispatcher client service and sets the output rule in the
#       firewall
#
# Overrides:
#
#      <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
  {

      my ($self, $oldRow) = @_;

      my $newRow = $self->row();

      unless ( $newRow->{plainValueHash}->{link} eq $oldRow->{plainValueHash}->{link} ) {
          my $netMod = EBox::Global->modInstance('network');
          $self->_updateLinkInRSS($netMod->ifaceAddress($newRow->{plainValueHash}->{link}));
      }

  }

# Group: Protected methods

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
         new EBox::Types::Select(
                                 fieldName     => 'link',
                                 printableName => __('Channel link'),
                                 editable      => 1,
                                 populate      => \&populateLinks,
                                ),
         new EBox::Types::Union(
                                fieldName     => 'allowed',
                                printableName => __('Allowed readers'),
                                subtypes      =>
                                [
                                 new EBox::Types::Union::Text(
                                                              fieldName => 'allowedNobody',
                                                              printableName => __('Nobody'),
                                                             ),
                                 new EBox::Types::IPAddr(
                                                         fieldname => 'allowedIP',
                                                         printableName => __('IP address'),
                                                         editable  => 1,
                                                        ),
                                 new EBox::Types::Select(
                                                         fieldName     => 'allowedObject',
                                                         printableName => __('Object'),
                                                         editable      => 1,
                                                         foreignModel  => \&objectModel,
                                                         foreignField  => 'name',
                                                        ),
                                 new EBox::Types::Union::Text(
                                                              fieldName => 'allowedAll',
                                                              printableName => __('Public'),
                                                             ),
                                ],
                               ),
         new EBox::Types::Link(
                               fieldName      => 'linkToRSS',
                               printableName  => __('Syndicate this RSS'),
                               volatile       => 1,
                               acquirer       => \&setLinkToRSS,
                               HTMLViewer     => '/ajax/viewer/linkRSS.mas',
                               HTMLSetter     => '/ajax/viewer/linkRSS.mas',
                              ),
        );

      my $dataForm = {
                      tableName          => 'RSSDispatcherConfiguration',
                      printableTableName => __('Configure RSS dispatcher'),
                      modelDomain        => 'Events',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('The channel link is the link which is used to '
                                               . 'syndicate the content to your favourite RSS. '),
                      messages           => {
                                             update => __('RSS dispatcher configuration updated'),
                                            },
                     };

      return $dataForm;

  }

# Group: Callback functions

# Function: populateLinks
#
#     Populate the available channel links
#
# Returns:
#
#     array ref - the array reference containing the value and
#     printable value for each link to use as a channel link
#
sub populateLinks
{

    my $net = EBox::Global->modInstance('network');

    my @options;
    foreach my $iface (@{$net->ifaces()}) {
        push ( @options,
               {
                value => $net->ifaceAddress($iface),
                printableValue => $iface,
               });
    }

    return \@options;

}

# Function: objectModel
#
#     Getter for the object model using model manager
#
# Returns:
#
#     <EBox::Objects::Model::ObjectTable> - an instance of the object
#     model
#
sub objectModel
{

    my $obj = EBox::Global->modInstance('objects');

    return $obj->models()->[0];

}

# Function: setLinkToRSS
#
#      Acquirer for the link to RSS which is displayed on
#      configuration to syndicate the eBox alerts
#
# Returns:
#
#      String - the url to the RSS to syndicate
#
sub setLinkToRSS
{

    my ($row) = @_;

    EBox::Event::Dispatcher::RSS::LockRSSFile(0);

    my $rss = new XML::RSS(version => '2.0');
    $rss->parsefile(EBox::Event::Dispatcher::RSS::RSSFilePath());

    EBox::Event::Dispatcher::RSS::UnlockRSSFile();

    return $rss->channel('link');

}


# Group: Private methods

# Update link shown at the RSS channel
sub _updateLinkInRSS # (ip)
{

    my ($self, $ip) = @_;

    my $rss = new XML::RSS(version => '2.0');

    # Locking exclusively
    EBox::Event::Dispatcher::RSS::LockRSSFile(1);

    $rss->parsefile(EBox::Event::Dispatcher::RSS::RSSFilePath());

    # Update link
    my $channeLink = $rss->channel('link');

    $channelLink =~ s{https://.*?/}{https://$ip/}g;

    $rss->channel(link => $channelLink);

    $rss->save();

    EBox::Event::Dispatcher::RSS::UnlockRSSFile();

}

1;
