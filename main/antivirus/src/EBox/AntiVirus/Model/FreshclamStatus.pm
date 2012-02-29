# Copyright (C) 2009-2012 eBox Technologies S.L.
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
#

package EBox::AntiVirus::Model::FreshclamStatus;
use base 'EBox::Model::DataForm::ReadOnly';

use feature 'switch';

use strict;
use warnings;

use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;

# Constants
use constant SB_URL => 'https://store.zentyal.com/small-business-edition.html/?utm_source=zentyal&utm_medium=dashboard&utm_campaign=smallbusiness_edition';
use constant ENT_URL => 'https://store.zentyal.com/enterprise-edition.html/?utm_source=zentyal&utm_medium=dashboard&utm_campaign=enterprise_edition';

use constant CLAMAV_LOG_FILE => '/var/log/clamav/clamav.log';

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: viewCustomizer
#
#      To display a permanent message
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    my $securityUpdatesAddOn = 0;
    if ( EBox::Global->modExists('remoteservices') ) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
    }

    unless ( $securityUpdatesAddOn ) {
        $customizer->setPermanentMessage($self->_commercialMsg(), 'ad');
    }

    return $customizer;

}

# Group: Protected methods

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
         new EBox::Types::Text(
                               fieldName => 'message',
                               printableName => __('Status'),
                              ),
         new EBox::Types::Text(
                               fieldName => 'date',
                               printableName => __('Date'),
                              ),
         new EBox::Types::Int(
                              fieldName     => 'nSignatures',
                              printableName => __('Signatures'),
                          ),
        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Database Update Status'),
                      pageTitle          => __('Antivirus'),
                      modelDomain        => 'AntiVirus',
                      tableDescription   => \@tableDesc,

                     };



    return $dataForm;
}

# Method: _content
#
#     Provide the content to the fields
#
# Overrides:
#
#     <EBox::Model::DataForm::Readonly::_content>
#
sub _content
{
    my ($self) = @_;

    my $antivirus  = $self->{'gconfmodule'};
    my $state      = $antivirus->freshclamState();

    my $date       = delete $state->{date};

    my $event;
    my $eventInfo;
    my $nSig = 0;
    if (defined $date) {
        # select which event is active if a event has happened
        while (($event, $eventInfo) = each %{ $state } ) {
            if ($eventInfo) {
                last;
            }
        }
        $nSig = $self->_nSig();
    }
    else {
        $date  = time();
        if ( not $antivirus->configured() ) {
            $event = 'unconfigured';
        } elsif ( not $antivirus->isEnabled() ) {
            $event = 'disabled';
        } else {
            $event = 'uninitialized';
            $nSig  = $self->_nSig();
        }
    }

    # build appropiate msg
    my $msg;
    given ( $event ) {
        when ('uninitialized')  {
            $msg = __(q{The antivirus database has not been updated since the module was enabled.});
        }
        when ('error')    { $msg = __('The last update failed.'); }
        when ('outdated') { $msg = __('Last update successful.'); }
        when ('update')   { $msg = __('Last update successful.'); }
        when ('unconfigured') {
            $msg = __('The antivirus module is not configured. Enable it first in Module Status section.');
        }
        when ('disabled') {
            $msg = __('The antivirus module is not enabled. Enable it first to know the antivirus status.');
        }
        default { $msg = __x('Unknown event {event}.', event => $event, ); }
    }

    my $printableDate =  _formatDate($date);
    return {
            message     => $msg,
            date        => $printableDate,
            nSignatures => $nSig,
           }
}

# Group: Private methods

sub _formatDate
{
    my ($date) = @_;
    my $localDate = localtime($date);

    return $localDate;
}

sub _commercialMsg
{
    return __sx('Want to protect your system against scams, spear phishing, frauds and other junk? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch} that include the Antivirus feature in the automatic security updates.',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">',
                ch => '</a>');
}

# Get the number of signatures from clamav log file
sub _nSig
{
    my $cmd = 'grep signatures ' . CLAMAV_LOG_FILE . ' | tail -n 1';
    my $output = EBox::Sudo::root($cmd);

    my $line = $output->[0];

    return 0 unless (defined($line));

    my ($nSig) = $line =~ m/([0-9]+)\ssignatures/;

    return $nSig;

}

1;

