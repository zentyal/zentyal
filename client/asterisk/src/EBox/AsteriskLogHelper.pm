# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::AsteriskLogHelper;

# Class: EBox::AsteriskLogHelper
#
#
#

use strict;
use warnings;

use EBox;
use EBox::Config;
use EBox::Gettext;

use Text::CSV;

use constant LOGFILE => '/var/log/asterisk/cdr-csv/Master.csv';

# Group: Public methods

# Constructor: new
#
#       Create the new Log helper.
#
# Returns:
#
#       <EBox::AsteriskLogHelper> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = {};

    bless($self, $class);

    return $self;
}


sub domain
{
    return 'ebox-asterisk';
}


# Method: logFiles
#
#       This function must return the file or files to be read from.
#
# Returns:
#
#       array ref - containing the whole paths.
#
sub logFiles
{
    return [LOGFILE];
}


# Method: processLine
#
#       This function will be run every time a new line is received in
#       the associated file. You must parse the line, and generate
#       the messages which will be logged to ebox through an object
#       implementing EBox::AbstractLogger interface.
#
# Parameters:
#
#       file - file name
#       line - string containing the log line
#       dbengine- An instance of class implemeting AbstractDBEngine interface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;

    my $csv = Text::CSV->new();

    unless ( $csv->parse($line) ) { return; }

    my @columns = $csv->fields();

    # see http://www.voip-info.org/wiki/view/Asterisk+cdr+csv
    my %dataToInsert;
    $dataToInsert{accountcode} = $columns[0];
    $dataToInsert{src} = $columns[1];
    $dataToInsert{dst} = $columns[2];
    $dataToInsert{dcontext} = $columns[3];
    $dataToInsert{clid} = $columns[4];
    $dataToInsert{channel} = $columns[5];
    $dataToInsert{dstchannel} = $columns[6];
    $dataToInsert{lastapp} = $columns[7];
    $dataToInsert{lastdata} = $columns[8];
    $dataToInsert{timestamp} = $columns[9]; # 3 fields on logs with dates
    $dataToInsert{duration} = $columns[12];
    $dataToInsert{billsec} = $columns[13];
    $dataToInsert{disposition} = $columns[14];
    $dataToInsert{amaflags} = $columns[15];
    $dataToInsert{uniqueid} = $columns[16];
    $dataToInsert{userfield} = $columns[17];

    $dbengine->insert('asterisk_cdr', \%dataToInsert);
}

1;
