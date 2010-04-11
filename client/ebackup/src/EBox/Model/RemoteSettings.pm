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
#		full => scheduling crontab lines for full backup
#		incremental => scheduling crontab lines for incremental backup
#
#	Note that, it only returns the scheduling part '30 1 * * * *' and not
#	the command
#
sub crontabStrings
{
    my ($self) = @_;

    my $time = $self->row()->valueByName('start');
    my ($fullFreq, $fullStartsOn) = $self->_frequencyAndStartsOn('full');
    my ($incrFreq, $incrStartsOn) = $self->_frequencyAndStartsOn('incremental');

    my $full = _crontabStringFull($time, $fullFreq, $fullStartsOn);

    my $incr = undef;
    unless ($incrFreq eq 'disabled') {
        $incr =  _crontabStringIncr($time, $fullFreq, $fullStartsOn,
                                    $incrFreq, $incrStartsOn                
                                   );
    }


    return ({ full => $full, incremental => $incr });
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
        new EBox::Types::Union(
            'fieldName' => 'full',
            'printableName' => __('Full Backup Frequency'),
            'subtypes' =>
                [
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
                    fieldName     => 'full_monthly',
                    printableName => __('Monthly'),
                    editable      => 1,
                    populate      => \&_monthDays,
                ),
                ],
            'unique' => 1,
            'editable' => 1,
            ),
        new EBox::Types::Union(
            'fieldName' => 'full_copies_to_keep',
            'printableName' => __('Keep previous full copies'),
            'subtypes' =>
                [
                new EBox::Types::Int(
                    'fieldName' => 'full_copies_to_keep_number',
                    'printableName' => __('maximum number'),
                                     
                    'editable'=> 1,
                    'default' => 1,
                    'min'     => 1,
                    'max'     => 1000,
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
        new EBox::Types::Union(
            'fieldName' => 'incremental',
            'printableName' => __('Incremental Backup Frequency'),
            'subtypes' =>
                [
                new EBox::Types::Union::Text(
                    'fieldName' => 'incremental_disabled',
                    'printableName' => __('Disabled'),
                    'optional' => 1
                ),
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
                ],
            'unique' => 1,
            'editable' => 1,
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

sub _crontabStringFull
{
    my ($hour, $freq, $startsOn) = @_;

    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';
    if ( $freq eq 'weekly' ) {
        $weekDay = $startsOn;
    } elsif ( $freq eq 'monthly' ) {
        if ($startsOn <= 28) {
            $monthDay = $startsOn,
        } else {
            return _crontabStringLastDayMonth($hour);
        }
    }

    return ["0 $hour $monthDay $month $weekDay"];
}





# Warning: is assumed that full and inc frequencies and startOn values are
# enforced as coherent vlaues by the interface
sub _crontabStringIncr
{
    my ($hour, $fullFreq, $fullStartsOn, $freq, $startsOn) = @_;
    my $weekDay = '*';
    my $monthDay = '*';
    my $month = '*';

    if ($fullFreq eq 'weekly') {
        my @daysWeek =  grep { $_ ne $fullStartsOn }  (0 .. 6);
        $weekDay = join ',', @daysWeek;
        return ["0 $hour $monthDay $month $weekDay"];
    } elsif ($fullFreq eq 'monthly') {
        if ($freq eq 'weekly') {
            $weekDay = $startsOn;
        }

        my @daysMonth;
        if ($fullStartsOn <= 28) {
            my @daysMonth = grep { $_ ne $fullStartsOn }  (1 .. 31);
            my $monthDay = join ',', @daysMonth;
            return ["0 $hour $monthDay $month $weekDay"];
        } else {
            # every day except last day
            my @strings;
            push @strings, "0 $hour 1-30 1,3,5,7,8,10,12 $weekDay";
            # we dont use 29th days every 4 years
            push @strings, "0 $hour 1-27 2 $weekDay"; 
            push @strings, "0 $hour 1-29 4,6,9,11 $weekDay";
            return \@strings;
        }
        
    }


}



sub _crontabStringLastDayMonth
{
    my ($hour) = @_;
    my $weekDay = '*';

    my @strings;
    push @strings, "0 $hour 31 1,3,5,7,8,10,12 $weekDay";
    # we dont use 29th days every 4 years
    push @strings, "0 $hour 28 2 $weekDay"; 
    push @strings, "0 $hour 30 4,6,9,11 $weekDay";
    return \@strings;
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

    my $incrementalFreq = $actualValues->{incremental}->selectedType();
    if ($incrementalFreq ne 'incremental_disabled') {
        my $fullFreq = $actualValues->{full}->selectedType();
        my $fullStart = $actualValues->{'full'}->value();
        my $incStart  = $actualValues->{'incremental'}->value();

        $fullFreq =~ s{full_}{};
        $incrementalFreq =~ s{incremental_}{};


        $self->_validateFrequencies($fullFreq, $incrementalFreq,
                                    $fullStart, $incStart
                                   );
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
    my ($self, $full, $partial, $fullStartAt, $partialStartAt) = @_;

    return if ($partial eq 'disabled');
    my %values = (
                  daily => 3,
                  weekly => 2,
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
