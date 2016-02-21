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

package EBox::MailFilter::Model::AntispamTraining;

use base 'EBox::Model::DataForm::Action';

use TryCatch;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::File;
use EBox::Types::Select;
use EBox::Config;
use EBox::Sudo;

use EBox::Exceptions::External;

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
sub _table
{
    my @tableDesc =
        (
           new EBox::Types::File(
                                 fieldName => 'mailbox',
                                 printableName => __('Mailbox'),
                                 help => __('mbox format expected'),
                                 filePath   => EBox::Config::tmp() . '/trainSpam',
                                 editable => 1,
                                ),
         new EBox::Types::Select(
                                 fieldName => 'mailboxContent',
                                 printableName => __('Mailbox contains'),
                                 populate => \&_populateMailboxContains,
                                 defaultValue => 'spam',
                                 editable => 1,
                                ),

        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Train bayesian spam filter'),
                      modelDomain        => 'MailFilter',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      messages           => {
                          update => __('Learned from messages')
                      },
                      printableActionName => __('Train'),
                     };

    return $dataForm;
}

sub _populateMailboxContains
{
     return [
             { value => 'spam', printableValue => __('spam') },
             { value => 'ham', printableValue => __('ham') },
            ];
 }

sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;

}

sub formSubmitted
{
    my ($self) = @_;

    my $mailboxFile    = $self->mailboxType->tmpPath();
    my $mailboxContent = $self->mailboxContent;

    my $mailfilter= EBox::Global->modInstance('mailfilter');
    my $antispam  = $mailfilter->antispam;

    my $isSpam;
    if ($mailboxContent eq 'spam') {
        $isSpam = 1;
    } elsif ($mailboxContent eq 'ham') {
        $isSpam = 0;
    } else {
        throw EBox::Exceptions::External( __x(
                                              'Invalid mailbox type: {type}',
                                              type => $mailboxContent,
                                             )
                                        );
    }

    # file must be readable by EBox::MailFilter::SpamAssassin::DB_USER
    my $user     =  $antispam->confUser();
    my $chownCmd = "chown $user.$user $mailboxFile";
    EBox::Sudo::root($chownCmd);

    $antispam->learn(
                     username => 'eboxAministrationInterface',
                     isSpam => $isSpam,
                     format => 'mbox',
                     input  => $mailboxFile,
                    );

}

1;

