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
use EBox::Sudo;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Types::Password;
use EBox::Types::Int;
use EBox::Types::Union::Text;
use EBox::Types::Union;
use EBox::Types::Password;
use EBox::View::Customizer;
use EBox::Validate;


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
    my $allFields = [qw/user password/];
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { method =>
                {
                ebox_eu => {  enable => $userPass },
                ebox_us_w => { enable => $userPass },
                file => { disable => $userPass },
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
           help          => __x('If the selected method is {brand}, only set the target directory',
                                brand => 'eBox Backup Storage'),
       ),
       new EBox::Types::Text(
           fieldName     => 'user',
           printableName => __('User'),
           editable      => 1,
       ),
       new EBox::Types::Password(
           fieldName     => 'password',
           printableName => __('Password'),
           editable      => 1,
       ),
        new EBox::Types::Union(
            'fieldName' => 'encryption',
            'printableName' => __('Encryption'),
            'subtypes' =>
                [
                new EBox::Types::Union::Text(
                    'fieldName' => 'disabled',
                    'printableName' => __('Disabled'),
                    'optional' => 1
                ),
                new EBox::Types::Password(
                    'fieldName' => 'symmetric',
                    'printableName' => __('Symmetric Key'),
                    'editable'=> 1,
                ),
                new EBox::Types::Select(
                    fieldName     => 'asymmetric',
                    printableName => __('GPG Key'),
                    editable      => 1,
                    populate      => \&_gpgKeys,
                    disabledCache  => 1,
                ),
                ],
            'unique' => 1,
            'editable' => 1,
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
        help               => __x('If you choose {brand} or file system methods '
                                  . ', then the destination field '
                                  . 'may be the target directory in the backup server',
                                 brand => 'eBox Backup Storage'),
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
            value => 'ebox_eu',
            printableValue => 'eBox Backup Storage (EU)',
            },
            {
            value => 'ebox_us_denver',
            printableValue => 'eBox Backup Storage (US Denver)',
            },
            {
            value => 'ebox_us_w',
            printableValue => 'eBox Backup Storage (US West Coast)',
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
    my $output = EBox::Sudo::command($cmd);
    for my $line (@{$output}) {
        chop($line);
        $line =~ s:^.*/::;
        push (@keys, {value => $line , printableValue => $line});
    }

    return \@keys;
}

sub _message
{
    my $backupmsg =  __x(

        '{oi}{brand}{ci} is a quick and safe remote location to store the data ' .
        'you keep on your eBox servers. Purchase the backup storage ' .
        'space you need at the {ohref}eBox on-line store{chref}.',
         oi => '<i>',
         ci => '</i>',
         ohref => '<a href="http://store.ebox-technologies.com/?utm_source=ebox&utm_medium=ebox&utm_campaign=ebackup">',
         brand => 'eBox Backup Storage',
         chref => '</a>'
    );
    return $backupmsg;
}


sub validateTypedRow
{
    my ($self, $action, $paramsRef, $allFieldsRef) = @_;
    my $actualValues = $self->_actualValues($paramsRef, $allFieldsRef);

    my $method = $actualValues->{method}->value();
    my $target = $actualValues->{target}->value();

    if ($method =~ /^ebo/) {
        my $target = $actualValues->{target}->value();
        if (defined($target)) {
            my $excepTxt = __('Destination must be a relative directory');
            if ($target =~ m:^/:) {
                throw EBox::Exceptions::External($excepTxt);
            }
            EBox::Validate::checkFilePath(
                    $target,
                    $excepTxt
                    );
        }
    } else {
        # all methods except eBox need a target
        my $checkMethod = '_validateTargetFor' . (ucfirst $method);
        $self->$checkMethod($target);
    }

    my $incrementalFreq = $actualValues->{incremental}->value();
    if ($incrementalFreq ne 'disable') {
        my $fullFreq = $actualValues->{full}->value();
        $self->_validateFrequencies($fullFreq, $incrementalFreq);
    }



}


sub _validateTargetForFtp
{
    my ($self, $target) = @_;
    $self->_validateTargetForFtpAndScp($target);
}


sub _validateTargetForScp
{
    my ($self, $target) = @_;
    $self->_validateTargetForFtpAndScp($target);
}


sub _validateTargetForFtpAndScp
{
    my ($self, $target) = @_;

    if (not $target) {
         throw EBox::Exceptions::MissingArgument(
   __(q{The target parameter that must be like 'other.host[:port]/some_dir})
                                               );
    }

    my $checkRegex = qr{^([^/:]*?) # host
                       (?::(\d+))? # optional port
                       (/([^/].*?))?$ # dir

                      }x;
    if (not $target =~ m/$checkRegex/)  {
        throw EBox::Exceptions::InvalidData(
             data => __('target'),
             value => $target,
             advice => __(q{Must be a like 'other.host[:port]/some_dir'})
                                           );
    }


    my ($host, $port, $dir) = ($1, $2, $3);

    EBox::Validate::checkHost($host, __('host'));
    if (defined $port) {
        EBox::Validate::checkPort($port, __('port'));
    }
    EBox::Validate::checkFilePath($dir, __('directory'));

}

sub _validateTargetForRsync
{
    my ($self, $target) = @_;

   if (not $target) {
         throw EBox::Exceptions::MissingArgument(
   __(q{The RSYNC target parameter that must be like 'other.host[:port]/relative_path' or 'other.host[:port]/absolute_path'})
                                               );
    }

    my $checkRegex = qr{^([^/:]*?) # host
                       (?::(\d+))? # optional port
                       (/(.*?))?$ # dir

                      }x;
    if (not $target =~ m/$checkRegex/)  {
        throw EBox::Exceptions::InvalidData(
             data => __('target'),
             value => $target,
             advice =>
 __(q{Must be a like 'other.host[:port]/relative_path' or 'other.host[:port]/absolute_path'})
                                           );
    }


    my ($host, $port, $dir) = ($1, $2, $3);

    EBox::Validate::checkHost($host, __('host'));
    if (defined $port) {
        EBox::Validate::checkPort($port, __('port'));
    }
    if ($dir =~ m{^/}) {
        EBox::Validate::checkAbsoluteFilePath($dir, __('absolute directory'));
    } else {
        EBox::Validate::checkFilePath($dir, __('relative directory'));
    }



}




sub _validateTargetForFile
{
    my ($self, $target) = @_;


    if (not $target) {
        throw EBox::Exceptions::MissingArgument(
__('File system method needs a target parameter that should be a directory path')
                                               );
    }

    EBox::Validate::checkAbsoluteFilePath($target,
                                 __('Directory for backup'));

    if ((-e $target) and (not -d $target)) {
        throw EBox::Exceptions::InvalidData(
                                            data => __('Directory for backup'),
                                            value => $target,
                                            advice =>
                                    __('File exists and it is not a directory')

                                           );
    }

}


sub _validateFrequencies
{
    my ($self, $full, $partial) = @_;

    return if ($partial eq 'disabled');
    my %values = (
                  daily => 3,
                  weekly => 2,
                  monthly => 1,
                 );

    if ($values{$full} > $values{$partial}) {
        throw EBox::Exceptions::External(
    __('Full backup cannot be more frequent than incremental backup')
                                        );
    }
}


sub formSubmitted
{
    my ($self) = @_;
    my $method = $self->row()->valueByName('method');
    if ($method eq 'scp') {
        $self->setMessage(
 __('General backup server configuration updated. SCP method selected; <em>remember</em> to add your target host to the list of known hosts by SSH')
                         );

    }

}

sub _actualValues
{
    my ($self,  $paramsRef, $allFieldsRef) = @_;
    my %actualValues = %{ $allFieldsRef };
    while (my ($key, $value) = each %{ $paramsRef }) {
        $actualValues{$key} = $value;
    }

    return \%actualValues;
}




1;
