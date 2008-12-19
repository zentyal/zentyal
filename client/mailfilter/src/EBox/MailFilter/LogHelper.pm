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

use constant MAIL_LOG => '/var/log/mail.log';
use constant SYS_LOG => '/var/log/syslog';

use constant SMTP_FILTER_TABLE => 'message_filter';
use constant POP_PROXY_TABLE   => 'pop_proxy_filter';


 

sub new
{
    my $class = shift;
    my %params = @_;

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
    return [MAIL_LOG, SYS_LOG];
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




sub processLine
{
    my ($self, $file, $line, $dbengine) = @_;

    if ($file eq MAIL_LOG) {
        $self->_processAmavisLine($line, $dbengine);
    }
    elsif ($file eq SYS_LOG) {
        $self->_processPOPProxyLine($line, $dbengine);
    }
}



my $amavisLineRe = qr{^\s\(.*?\)\s
               (\w+)\s([\w\-]+).*?, # action (Passed or Blocked) and event type
               \s<(.*?)>\s->\s<(.*?)>,  # mail sender and receiver
               \sHits:\s([\d\.\-]+), # Spam hits ('-' for none)
              }x;

sub _processAmavisLine
{
    my ($self, $line, $dbengine) = @_;

    if (not $line =~ m/amavis/) {
        return;
    }

    my $header;
    ($header, $line) = split 'amavis.*?:' , $line, 2;

    if (not $line =~ $amavisLineRe) {
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


    $dbengine->insert(SMTP_FILTER_TABLE, $values);
}


my $p3scanAddress;
my $p3scanVirus = 0;
my $p3scanSpam  = 0;
my $p3scanClientConn;

sub _processPOPProxyLine
{
    my ($self, $line, $dbengine) = @_;


    if ($line =~ m/p3scan\[\d+\]: Connection from (.*):/) {
        $p3scanClientConn = $1;
        $p3scanVirus   = 0;
        $p3scanSpam    = 0;
        $p3scanAddress = undef;
    }
    elsif ($line =~ m/p3scan\[\d+\]: USER \'(.*?)\'/ ) {
        $p3scanAddress = $1;
    }
    elsif ($line =~ m/p3scan\[\d+\]: .* contains a virus/) {
        $p3scanVirus += 1;
    }
    elsif ($line =~ m/spamd: identified spam .* for p3scan/) {
        $p3scanSpam += 1;
    }
    elsif ($line =~ m{p3scan\[\d+\]: Session done.*\((.*?)\).* Mails: (.*) Bytes:} ) {
        my $status = $1;
        my $mails  = $2;

        my $event;
        if ($status eq 'Clean Exit') {
            $event = 'pop3_fetch_ok';
        }
        else { # $status ~= m/abort/
            $event = 'pop3_fetch_failed';
            
        }



        my $cleanMails = $mails  - $p3scanVirus - $p3scanSpam;

        my $date = $self->_getDate($line);

        my $values = {
                      event => $event,
                      address => $p3scanAddress,
                      
                      mails  => $mails,
                      clean   => $cleanMails,
                      virus  => $p3scanVirus,
                      spam   => $p3scanSpam,
                      
                      clientConn => $p3scanClientConn,

                      
                      date => $date,
                     };



    $dbengine->insert(POP_PROXY_TABLE, $values);
    }

}

1;
