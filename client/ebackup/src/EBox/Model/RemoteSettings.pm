# Copyright (C) 2009 eBox Technologies, S.L.
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


package EBox::EBackup::Model::RemoteSettings;

# Class: EBox::EBackup::Model::RemoteSettings
#
#       Form to set the general configuration for the remote backup server
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Password;
use EBox::Types::Int;
use EBox::View::Customizer;

# Group: Public methods

# Constructor: new
#
#       Create the new RemoteSettings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::RemoteSettings> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: crontabStrings
#
#	Builds the crontab line for full and incremental.
#
# Returns:
#
#	Hash ref:
#		
#		full => scheduling crontab line for full backup
#		incremental => scheduling crontab line for incremental backup
#
#	Note that, it only returns the scheduling part '30 1 * * * *' and not
#	the command
#		
sub crontabStrings
{
    my ($self) = @_;

    my $time = $self->row()->valueByName('start');
    my $fullFreq = $self->row()->valueByName('full');
    my $full = _crontabStringFull($time, $fullFreq);
    my $incrValue = $self->row()->valueByName('incremental');
    my $incr = undef;
    unless ($incrValue eq 'disabled') {
        $incr =  _crontabStringIncr($time, $fullFreq, 
                $self->row()->valueByName('incremental')
                );
    }
    return ({ full => $full, incremental => $incr });
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to show and hide source and destination ports
#   depending on the protocol
#
#
sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    my $userPass = [qw/user password/];
    my $allFields = [qw/user password target/];
    my $target = [qw/target/];
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { method =>
                {
                ibackup => { disable => $target, enable=> $userPass },
                file => { disable => $userPass, enable => $target },
                rsync => { enable => $allFields },
                scp => { enable => $allFields },
                ftp => { enable => $allFields },
                }
            });
    $customizer->setPermanentMessage(_message());
    return $customizer;
}

#

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader = (
       new EBox::Types::Select(
           fieldName     => 'method',
           printableName => __('Method'),
           editable      => 1,
           populate      => \&_method,
       ),
       new EBox::Types::Text(
           fieldName     => 'target',
           printableName => __('Host or destination'),
           editable      => 1,
           optional      => 1,
       ),
       new EBox::Types::Text(
           fieldName     => 'user',
           printableName => __('User'),
           editable      => 1,
           optional      => 1,
       ),
       new EBox::Types::Password(
           fieldName     => 'password',
           printableName => __('Password'),
           editable      => 1,
           optional      => 1,
       ),
       new EBox::Types::Select(
           fieldName     => 'gpg_key',
           printableName => __('GPG key'),
           editable      => 1,
           populate      => \&_gpgKeys,
           disabledCache  => 1,
       ),
       new EBox::Types::Select(
           fieldName     => 'full',
           printableName => __('Full Backup Frequency'),
           editable      => 1,
           populate      => \&_fullFrequency,
       ),
       new EBox::Types::Select(
           fieldName     => 'full_copies_to_keep',
           printableName => __('Number of full copies to keep'),
           editable      => 1,
           populate      => \&_fullCopies,
       ),

       new EBox::Types::Select(
           fieldName     => 'incremental',
           printableName => __('Incremental Backup Frequency'),
           editable      => 1,
           populate      => \&_incrFrequency,
       ),
       new EBox::Types::Select(
           fieldName     => 'start',
           printableName => __('Backup process starts at'),
           editable      => 1,
           populate      => \&_startingTime,
       ),
    );

    my $dataTable =
    {
        tableName          => 'RemoteSettings',
        printableTableName => __('General Configuration'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        help               => __('General remte backup server configuration'),
        messages           =>
            {
                update => __('General backup server configuration updated'),
        },
        modelDomain        => 'EBackup',
    };

    return $dataTable;

}

sub _fullFrequency
{
    return ([
        {
            value => 'daily',
            printableValue => __('Daily'),
        },
        {
            value => 'weekly',
            printableValue => __('Weekly'),
        },
        {
            value => 'monthly',
            printableValue => __('Monthly'),
        }]
    );
}

sub _incrFrequency
{
    return ([{
            value => 'disabled',
            printableValue => __('Disabled'),
           },
           @{_fullFrequency()}]
    );
}



sub _startingTime
{
    my @time;

    for my $hour (0 .. 23) {
        my $string = sprintf("%02d", $hour) . ':00';
        push (@time,
            {
                value => $hour,
                printableValue => $string,
            }
        );
    }

    return \@time;
}

sub _crontabStringFull
{
    my ($time, $freq) = @_;

    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';
    if ( $freq eq 'weekly' ) {
        $weekDay = '0';
    } elsif ( $freq eq 'monthly' ) {
        $monthDay = '1';
    }

    return "0 $time $monthDay $month $weekDay";
}

sub _crontabStringIncr
{
    my ($time, $fullFreq, $freq) = @_;

    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';
    if ( $freq eq 'weekly' ) {
        $weekDay = '0';
    } elsif ( $freq eq 'monthly' ) {
        $monthDay = '1';
    }
    if ( $fullFreq eq 'monthly' ) {
        $monthDay = '2-31';
    } elsif ( $fullFreq eq 'weekly') {
        $weekDay = '1-6';
    }

    return "0 $time $monthDay $month $weekDay";
}

sub _method
{
    return ([
            {
            value => 'ibackup',
            printableValue => 'iBackup',
            },
            {
            value => 'file',
            printableValue => 'File System',
            },
            {
            value => 'rsync',
            printableValue => 'RSYNC',
            },
            {
            value => 'ftp',
            printableValue => 'FTP',
            },
            {
            value => 'scp',
            printableValue => 'SCP',
            },
    ]);
}

sub _fullCopies
{
    my @copies;

    for my $number (1 .. 42) {
        push (@copies,
            {
                value => $number,
                printableValue => $number,
            }
        );
    }

    return \@copies;
}

sub _gpgKeys
{
    my @keys = ({value => 'disabled', printableValue => __('Disabled')});

    my $cmd = 'gpg --list-secret-keys | grep "^sec" | awk \'{print $2}\'';
    for my $line (`$cmd`) {
        chop($line);
        $line =~ s:^.*/::;
        push (@keys, {value => $line , printableValue => $line});
    }

    return \@keys;
}

sub _message
{
    my $ibackup =  __x(
        'By creating the iBackup account through this {ohref}link{chref} you ' .
        'support the development of eBox with no extra charge',
         ohref => '<a href="https://www.ibackup.com/p=ebox_technologies">',
         chref => '</a>'
    );
}

1;
