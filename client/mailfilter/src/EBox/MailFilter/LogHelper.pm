# Copyright (C) 2008 Warp Networks S.L
#
# This program is free software; you can redistribute it and/or modify

#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package EBox::MailFilter::LogHelper;

use strict;
use warnings;

use EBox::Gettext;

use base qw(EBox::LogHelper);

use constant MAILOG => "/var/log/mail.log";
use constant TABLENAME => "message_filter";


 

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

# Method: domain
#       
#       Must return the text domain which the package belongs to
#
sub domain 
{
    return 'ebox-mailfilter'; 
}

sub logFiles {
    return [MAILOG];
}



# Method: _getDate
#
#  This method returns the date and time on database format.
#
# Returns:
#
#               string - yyyy-mm-dd hh:mm:ss format.
sub _getDate
{
    my ($self, $line) = @_;

    my @date = localtime(time);
    
    my $year = $date[5] + 1900;
    my ($month, $day, $hour, $min, $sec) = $line =~ m/^(...) +(\d+) (..):(..):(..)/;
    
    return "$year-$month-$day $hour:$min:$sec";
}


my $lineRe = qr{^\s\(.*?\)\s
               (\w+)\s([\w\-]+).*?, # action (Passed or Blocked) and event type
               \s<(.*?)>\s->\s<(.*?)>,  # mail sender and receiver
               \sHits:\s([\d\.\-]+), # Spam hits ('-' for none)
              }x;

sub processLine
{
    my ($self, $file, $line, $dbengine) = @_;

    if (not $line =~ m/amavis/) {
        return;
    }

    my $header;
    ($header, $line) = split 'amavis.*?:' , $line, 2;

    if (not $line =~ $lineRe) {
        return;
    }

    my ($action, $event, $from, $to, $hits) = ($1, $2, $3, $4, $5);

    if ($event eq 'CLEAN') {
        $event = 'CLEAN';
    }
    
    if (($hits eq '-') and ($event eq 'SPAM')) {
        $event = 'BLACKLISTED';
    }


    my $date = $self->_getDate($header);

    my $values = {
                  event => $event,
                  action => $action,

                  from_address => $from,
                  to_address   => $to,

                  date => $date,
                 };

    if ($hits ne '-') {
        $values->{'spam_hits'} = $hits;
    }


    $dbengine->insert(TABLENAME, $values);
}

1;
