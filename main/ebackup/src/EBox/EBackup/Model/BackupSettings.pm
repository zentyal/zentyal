# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::EBackup::Model::BackupSettings;

use base 'EBox::Model::DataForm';

# Class: EBox::EBackup::Model::BackupSettings
#
#       Form to set the general configuration for the remote backup server
#

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
use EBox::Exceptions::NotConnected;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use File::Basename;
use TryCatch;

# Group: Public methods

# Constructor: new
#
#       Create the new BackupSettings model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::BackupSettings> - the recently created model
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
#       Builds the crontab line for full and incremental.
#
# Returns:
#
#       Hash ref:
#
#               full => scheduling crontab lines for full backup
#               incremental => scheduling crontab lines for incremental backup
#               once        => scheduling crontab lines for full backup once mode
#
#       Note that, it only returns the scheduling part '30 1 * * * *' and not
#       the command
#
sub crontabStrings
{
    my ($self) = @_;

    my $time = $self->row()->valueByName('start');
    my ($fullFreq, $fullStartsOn) = $self->_frequencyAndStartsOn('full');
    my ($incrFreq, $incrStartsOn) = $self->_frequencyAndStartsOn('incremental');

    my ($full, $incr, $once);

    if ($fullFreq eq 'once') {
        $once = _crontabStringOnce($time, $incrFreq, $incrStartsOn);
    } else {
        $full = _crontabStringFull($time, $fullFreq, $fullStartsOn);
        unless ($incrFreq eq 'disabled') {
            $incr =  _crontabStringIncr($time, $fullFreq, $fullStartsOn,
                                        $incrFreq, $incrStartsOn
                                       );
        }
    }

    my $strings = {
                   full => $full,
                   incremental => $incr,
                   once        => $once
                  };
    return $strings;
}

sub _frequencyAndStartsOn
{
    my ($self, $elementName) = @_;
    my $element = $self->row()->elementByName($elementName);
    my $freq = $element->selectedType();
    my $selectedTypePrefix= $elementName . '_';
    $freq =~ s/^$selectedTypePrefix//; # standarize freq
    my $startsOn = $element->value();
    return ($freq, $startsOn);
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
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { method =>
                {
                file => { hide => $userPass , show => ['target'] },
                rsync => { hide => ['password'], show => ['user', 'target'] },
                scp => { show => $allFields },
                ftp => { show => $allFields },
                }
            });

    return $customizer;
}

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
           help          => __('If the selected method is file system, only set the target directory'),
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
# XXX asymmetric key disabled until we could support it in disaster-recovery if
#     you want to use it uncomment the following lines and execute
#     service zentyal webadmin restart

#    new EBox::Types::Select( fieldName =>
#     'asymmetric', printableName => __('GPG Key'), editable => 1, populate =>
#     \&_gpgKeys, disabledCache => 1, ),
                ],
            'unique' => 1,
            'editable' => 1,
            ),
        new EBox::Types::Union(
            'fieldName' => 'full',
            'printableName' => __('Full Backup Frequency'),
            'subtypes' =>
                [
                new EBox::Types::Union::Text(
                    'fieldName' => 'full_once',
                    'printableName' => __('Only the first time'),
                    'optional' => 1
                ),
                new EBox::Types::Union::Text(
                    'fieldName' => 'full_daily',
                    'printableName' => __('Daily'),
                    'optional' => 1
                ),
                new EBox::Types::Select(
                    'fieldName' => 'full_weekly',
                    'printableName' => __('Weekly'),
                    'editable'=> 1,
                    populate => \&_weekDays,
                ),
                new EBox::Types::Select(
                    fieldName     => 'full_bimonthly',
                    printableName => __('Twice a month'),
                    editable      => 1,
                    populate      => \&_weekDays,
                ),
                new EBox::Types::Select(
                    fieldName     => 'full_monthly',
                    printableName => __('Monthly'),
                    editable      => 1,
                    populate      => \&_monthDays,
                ),
                ],
            'unique'        => 1,
            'editable'      => 1,
            ),
        new EBox::Types::Union(
            'fieldName' => 'incremental',
            'printableName' => __('Incremental Backup Frequency'),
            'subtypes' =>
                [
                new EBox::Types::Union::Text(
                    'fieldName' => 'incremental_daily',
                    'printableName' => __('Daily'),
                    'optional' => 1
                ),
                new EBox::Types::Select(
                    'fieldName' => 'incremental_weekly',
                    'printableName' => __('Weekly'),
                    'editable'=> 1,
                    populate => \&_weekDays,
                ),
                new EBox::Types::Union::Text(
                    'fieldName' => 'incremental_disabled',
                    'printableName' => __('Disabled'),
                    'optional' => 1
                ),
                ],
            'unique'   => 1,
            'editable' => 1,
            ),

       new EBox::Types::Select(
           fieldName     => 'start',
           printableName => __('Backup process starts at'),
           editable      => 1,
           populate      => \&_startingTime,
       ),
       new EBox::Types::Union(
           'fieldName' => 'full_copies_to_keep',
           'printableName' => __('Keep previous full copies'),
           'subtypes' =>
                [
                new EBox::Types::Int(
                    'fieldName' => 'full_copies_to_keep_number',
                    'printableName' => __('maximum number'),
                    'editable' => 1,
                    'defaultValue' => 1,
                    'min' => 1,
                    'max' => 1000,
                ),
                new EBox::Types::Select(
                    fieldName     => 'full_copies_to_keep_deadline',
                    printableName => __('no older than'),
                    editable      => 1,
                    populate      => \&_deadline,
                ),
                ],
           'unique' => 1,
           'editable' => 1,
           ),
    );

    my $dataTable =
    {
        tableName          => 'BackupSettings',
        printableTableName => __('General Configuration'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        messages           =>
            {
                update => __('General backup server configuration updated'),
        },
        modelDomain        => 'EBackup',
        help               => __('Here you have can choose the backup method, configure the frequency and other options'),
    };

    return $dataTable;
}

sub _weekDays
{
    return [
             { printableValue => __('on Monday') ,value => 1},
             { printableValue => __('on Tuesday'), value => 2},
             { printableValue => __('on Wednesday'), value => 3},
             { printableValue => __('on Thursday'), value =>  4},
             { printableValue => __('on Friday'), value =>  5},
             { printableValue => __('on Saturday'), value =>  6},
             { printableValue => __('on Sunday'), value => 0},
            ];
}

sub _monthDays
{
    my @days = map {
        my $mday = $_;
        {
            value => $mday,
            printableValue => __x(
                                  'on the {mday}th',
                                   mday => $mday,
                                 )
        }

    } (1 .. 28);

    push @days, {
                 value => 31,
                 printableValue => __('on the last day'),
                };

    return \@days;
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

sub _crontabMinute
{
    return 0;
}

sub _crontabWeekDayAndUser
{
    my ($weekDay, $equal) = @_;
    my $user = 'root';

    if ($weekDay eq '*') {
        return "* $user";
    }

    if ($equal) {
        return "* $user test \$(date +\\\%w) -eq $weekDay && ";
    } else {
        return "* $user test \$(date +\\\%w) -ne $weekDay && ";
    }
}

sub _crontabStringOnce
{
    my ($hour, $freq, $startsOn) = @_;

    my $minute  = _crontabMinute();
    my $weekDay = _crontabWeekDayAndUser('*');
    my $monthDay = '*';
    my $month = '*';
    if ($freq eq 'weekly') {
        $weekDay = _crontabWeekDayAndUser($startsOn, 1);
    } # Do nothing if freq is daily

    return ["$minute $hour $monthDay $month $weekDay"];
}

sub _crontabStringFull
{
    my ($hour, $freq, $startsOn) = @_;
    my $minute  = _crontabMinute();
    my $weekDay = _crontabWeekDayAndUser('*');
    my $monthDay = '*';
    my $month = '*';
    if ( $freq eq 'weekly' ) {
        $weekDay = _crontabWeekDayAndUser($startsOn, 1);
    } elsif ( $freq eq 'bimonthly' ) {
        $weekDay = _crontabWeekDayAndUser($startsOn, 1);
        $monthDay ='1-7,15-21';
    } elsif ( $freq eq 'monthly' ) {
        if ( $startsOn <= 28 ) {
            $monthDay = $startsOn;
        } else {
            return _crontabStringLastDayMonth($hour);
        }
    } # Do nothing if freq is daily

    return ["$minute $hour $monthDay $month $weekDay"];
}

# Warning: is assumed that full and inc frequencies and startOn values are
# enforced as coherent vlaues by the interface
sub _crontabStringIncr
{
    my ($hour, $fullFreq, $fullStartsOn, $freq, $startsOn) = @_;
    my $minute  = _crontabMinute();
    my $weekDay = _crontabWeekDayAndUser('*');
    my $monthDay = '*';
    my $month = '*';

    if ($fullFreq eq 'weekly') {
        $weekDay = _crontabWeekDayAndUser($fullStartsOn, 0);
        return ["$minute $hour $monthDay $month $weekDay"];
    } elsif ($fullFreq eq 'monthly') {
        if ($freq eq 'weekly') {
            $weekDay = _crontabWeekDayAndUser($startsOn, 1);
        }

        my @daysMonth;
        if ($fullStartsOn <= 28) {
            my @daysMonth = grep { $_ ne $fullStartsOn }  (1 .. 31);
            $monthDay = join ',', @daysMonth;
            return ["$minute $hour $monthDay $month $weekDay"];
        } else {
            # every day except last day
            my @strings;
            push @strings, "$minute $hour 1-30 1,3,5,7,8,10,12 $weekDay";
            # we dont use 29th days every 4 years
            push @strings, "$minute $hour 1-27 2 $weekDay";
            push @strings, "$minute $hour 1-29 4,6,9,11 $weekDay";
            return \@strings;
        }
    } elsif ($fullFreq eq 'bimonthly') {
        my $fullMonthDays = '1-7,15-21';
        my $noFullMonthDays = '8-14,22-31';

        if ($freq eq 'weekly') {
            $weekDay = _crontabWeekDayAndUser($startsOn, 1);;
            if ($startsOn != $fullStartsOn) {
                return ["$minute $hour * $month $weekDay"];
            } else {
                return ["$minute $hour $noFullMonthDays $month $weekDay"];
            }
        }

        # incremental daily frequency
        my $noFullWeekDays = _crontabWeekDayAndUser($fullStartsOn, 0);
        return [
                "$minute $hour $noFullMonthDays * $weekDay",
                "$minute $hour $fullMonthDays * $noFullWeekDays",
               ];
    }
}

sub _crontabStringLastDayMonth
{
    my ($hour) = @_;

    my $minute  = _crontabMinute();
    my $weekDay = _crontabWeekDayAndUser('*');

    my @strings;
    push @strings, "$minute $hour 31 1,3,5,7,8,10,12 $weekDay";
    # we dont use 29th days every 4 years
    push @strings, "$minute $hour 28 2 $weekDay";
    push @strings, "$minute $hour 30 4,6,9,11 $weekDay";
    return \@strings;
}

sub _method
{
    my @methods = (
            {
            value => 'file',
            printableValue => __('File System'),
            },
            {
            value => 'ftp',
            printableValue => 'FTP',
            },
            {
            value => 'rsync',
            printableValue => 'RSYNC',
            },
            {
            value => 'scp',
            printableValue => 'SCP',
            },
    );

    return \@methods;
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

sub _deadline
{
    return [
            {
             printableValue => __('1 week'),
             value => '1W',
            },
            {
             printableValue => __('2 weeks'),
             value => '2W',
            },
            {
             printableValue => __('3 weeks'),
             value => '3W',
            },
            {
             printableValue => __('1 month'),
             value => '1M',
            },
            {
             printableValue => __('2 months'),
             value => '2M',
            },
            {
             printableValue => __('3 months'),
             value => '3M',
            },
            {
             printableValue => __('4 months'),
             value => '4M',
            },
            {
             printableValue => __('6 months'),
             value => '6M',
            },
            {
             printableValue => __('9 months'),
             value => '9M',
            },
            {
             printableValue => __('1 year'),
             value => '1Y',
            },
            {
             printableValue => __('1 year and half'),
             value => '18M',
            },
            {
             printableValue => __('2 years'),
             value => '2Y',
            },
            {
             printableValue => __('3 years'),
             value => '3Y',
            },
           ];
}

sub removeArguments
{
    my ($self) = @_;

    my $keep =  $self->row()->elementByName('full_copies_to_keep');
    my $keepSelected = $keep->selectedType();
    my $keepValue = $keep->value();
    if ($keepSelected eq 'full_copies_to_keep_number') {
        return "remove-all-but-n-full $keepValue";
    } elsif ($keepSelected eq 'full_copies_to_keep_deadline') {
        return "remove-older-than $keepValue";
    }
}

sub validateTypedRow
{
    my ($self, $action, $paramsRef, $allFieldsRef) = @_;

    if (exists $paramsRef->{target} or
        exists $paramsRef->{method}) {

        $self->{targetChanged} = 1;
    }

    if (exists $paramsRef->{encryption} and (not $self->{targetChanged}) ) {
        $self->_checkEncryptionChangeIsAllowed();
    }

    my $actualValues = $self->_actualValues($paramsRef, $allFieldsRef);

    my $method = $actualValues->{method}->value();
    my $checkMethod = '_validateTargetFor' . (ucfirst $method);
    my $target = $actualValues->{target}->value();
    $self->$checkMethod($target);

    my $incrementalFreq = $actualValues->{incremental}->selectedType();
    my $fullFreq = $actualValues->{full}->selectedType();
    my $fullStart = $actualValues->{'full'}->value();
    my $incStart  = $actualValues->{'incremental'}->value();

    $fullFreq =~ s{full_}{};
    $incrementalFreq =~ s{incremental_}{};

    $self->_validateFrequencies($fullFreq, $incrementalFreq,
                                $fullStart, $incStart);

}

sub _checkEncryptionChangeIsAllowed
{
    my ($self) = @_;
    my $ebackup = $self->{confmodule};
    my $remoteStatus = $ebackup->remoteStatus();
    if (@{ $remoteStatus }) {
        throw EBox::Exceptions::External(
__('You cannot switch encryption options when there are existent backups with the original encryption options. You must remove previous backup to change the encryption options')
                                        );
    }
}

sub _validateTargetForFtp
{
    my ($self, $target) = @_;
    $self->_validateTargetForFtpAndScp($target, 1);
}

sub _validateTargetForScp
{
    my ($self, $target) = @_;
    $self->_validateTargetForFtpAndScp($target, 0);
}

sub _validateTargetForFtpAndScp
{
    my ($self, $target, $rootAllowed) = @_;

    if (not $target) {
         throw EBox::Exceptions::MissingArgument(
   __(q{The target parameter that must be like 'other.host[:port]/some_dir})
                                               );
    }

    my $checkRegex = qr{^([^/:]*?) # host
                       (?::(\d+))? # optional port
                       (/.*)?$ # dir

                      }x;
    if (not $target =~ m/$checkRegex/)  {
        throw EBox::Exceptions::InvalidData(
             data => __('target'),
             value => $target,
             advice => __(q{Correct format is: 'other.host[:port]/some_dir'})
                                           );
    }

    my ($host, $port, $dir) = ($1, $2, $3);

    EBox::Validate::checkHost($host, __('host'));
    if (defined $port) {
        EBox::Validate::checkPort($port, __('port'));
    }

    if (($dir eq '/') and not $rootAllowed) {
        throw EBox::Exceptions::InvalidData(
             data => __('target'),
             value => $target,
             advice => __(q{Root directory ('/') not allowed in target specification})
                                           );
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

    if ($target eq '/') {
        throw EBox::Exceptions::InvalidData(
                                            data => __('Directory for backup'),
                                            value => $target,
                                            advice =>
                                    __('Cannot use the / directory as target')
                                           );
    }

    if ((-e $target) and (not -d $target)) {
        throw EBox::Exceptions::InvalidData(
                                            data => __('Directory for backup'),
                                            value => $target,
                                            advice =>
                                    __('File exists and it is not a directory')
                                           );
    }

    my $parentDir = dirname($target);
    if (($parentDir ne '/') and (not -d $parentDir) ) {
        throw EBox::Exceptions::InvalidData(
                                            data => __('Directory for backup'),
                                            value => $target,
                                            advice =>
                                    __x('Cannot read parent directory {d}',
                                         d => $parentDir)
                                           );
    }
}

sub _validateFrequencies
{
    my ($self, $full, $partial, $fullStartAt, $partialStartAt) = @_;

    my $partialDisabled =  ($partial eq 'disabled');
    if (($full eq 'once'))  {
        if ($partialDisabled) {
            throw EBox::Exceptions::External(
 __(q{You must enable incremental backups when you enable 'Only the first time' full backup frequency})
                                            );
        }

        return;
    }

    if ($partialDisabled) {
        return;
    }

    my %values = (
                  daily => 4,
                  weekly => 3,
                  bimonthly => 2,
                  monthly => 1,
                 );

    if ($values{$full} >= $values{$partial}) {
        throw EBox::Exceptions::External(
    __('Incremental backup must be more frequent than full backup')
                                        );
    }
}

sub formSubmitted
{
    my ($self) = @_;

    my $msg;
    my $targetChanged = delete $self->{targetChanged};
    if ($targetChanged) {
        $msg = __('General backup configuration updated.') . '<p>' .
               __('Backup method or target changed; you must save changes to refresh the backups list');
    }

    my $method = $self->row()->valueByName('method');
    if ($method eq 'scp') {
        if ($msg) {
            $msg .= '<p>';
        } else {
            $msg = __('General backup configuration updated.') . '<p>';
        }
        $msg .=  __('SCP method selected. Remember to add your target host to the list of known hosts by SSH');
    }

    if ($msg) {
        $self->setMessage($msg);
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

# we check that we have the target/user/password complete if eBox storage is selected
# bz is the default configuration and it is not complete. The validation methods
# avoids that the configuration is incomplete in other cases so we must only
# check this
sub configurationIsComplete
{
    my ($self) = @_;

    my $row = $self->row();

    my $target = $row->valueByName('target');
    if (not $target) {
        return 0;
    }

    my $method = $row->valueByName('method');
    if ($method eq 'file') {
        # file does not need user or password
        return 1;
    }

    my $user = $row->valueByName('user');
    if (not $user) {
        return 0;
    }

    if ($method eq 'rsync') {
        # rsync does not need password
        return 1;
    }

    my $password = $row->valueByName('password');
    if (not $password) {
        return 0;
    }

    return 1;
}

sub usedEncryptionMode
{
    my ($self) = @_;
    my $encryption = $self->row()->elementByName('encryption');
    my $encValue = $encryption->value();

    if ($encValue eq 'disabled') {
        return 'disabled';
    } else {
        my $encSelected = $encryption->selectedType();
        if ($encSelected eq 'symmetric') {
            return 'symmetric';
        }

        EBox::error('Unknown encryption type selected');
        return 'unknown';
    }
}

# Method: report
#
#     Return the backup settings
#
# Returns:
#
#     Hash ref - containing the settings to report
#
sub report
{
    my ($self) = @_;
    my $row = $self->row();

    my %report = ();

    my @attrs = qw(method target encryption full incremental);

    foreach my $attr (@attrs) {
        my $element =  $row->elementByName($attr);

        my $value;
        if ($element->isa('EBox::Types::Union')) {
            $value = $element->selectedType();
        } else {
            $value =  $element->value();
        }

        $report{$attr} = $value;
    }

    my $start = $row->valueByName('start') . ':00';
    $report{start} = $start;

    my $fullCopies =  $row->elementByName('full_copies_to_keep');
    $report{'retention policy type'} = $fullCopies->selectedType();
    $report{'policy value'} = $fullCopies->value();

    return \%report;
}

1;
