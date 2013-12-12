# Copyright (C) 2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

# Class: EBox::Events::Model::Dispatcher::Mail
#
#

package EBox::Mail::Model::Dispatcher::Mail;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::Password;
use EBox::Validate;
use EBox::Exceptions::InvalidData;

use Sys::Hostname;

# Group: Public methods

# Constructor: new
#
#     Create the configure mail dispatcher form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::Event::Dispatcher::Model::Mail>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

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
    my ($self, $action, $changedFields) = @_;

    if ( exists ( $changedFields->{to} )) {
        EBox::Validate::checkEmailAddress( $changedFields->{to}->value(),
                                           $changedFields->{to}->printableName() );
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
         new EBox::Types::Text(
                               fieldName        => 'subject',
                               printableName    => __('Subject'),
                               editable         => 1,
                               defaultValue     => __x('Zentyal event on {hostname}',
                                                       hostname => hostname()),
                               size             => 40,
                               allowUnsafeChars => 1,
                              ),
         new EBox::Types::Text(
                               fieldName     => 'to',
                               printableName => __('To'),
                               editable      => 1,
                               size          => 18,
                              ),
        );

    my $dataForm = {
                      tableName          => 'MailDispatcherConfiguration',
                      printableTableName => __('Configure Mail Dispatcher'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField' ],
                      tableDescription   => \@tableDesc,
                      class              => 'dataForm',
                      help               => __('This dispatcher will send events to a mail account. In order to use it' 
                                               . 'you need to enable the mail service on Zentyal.'),
                      messages           => {
                                             update => __('Mail dispatcher configuration updated.'),
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
            link  => '/Events/Composite/GeneralComposite#ConfigureDispatcherDataTable',
        },
        {
            title => __('Mail Dispatcher'),
            link  => ''
        }
    ]);

    return $custom;
}

# Group: Private methods

1;
