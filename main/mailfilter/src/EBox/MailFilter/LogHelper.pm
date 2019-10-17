# Copyright (C) 2008-2013 Zentyal S.L.
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
use strict;
use warnings;

package EBox::MailFilter::LogHelper;

use base qw(EBox::LogHelper);

use EBox::Gettext;

use constant MAIL_LOG => '/var/log/mail.log';
use constant SMTP_FILTER_TABLE => 'mailfilter_smtp';

sub new
{
    my $class = shift;
    my %params = @_;

    my $self = {};

    my $mail = EBox::Global->getInstance(1)->modInstance('mail');
    my $mailname = $mail->mailname();
    $self->{mailname} = $mailname;

    bless($self, $class);
    return $self;
}

sub logFiles
{
    return [MAIL_LOG];
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
    my $ts = "$year-$month-$day $hour:$min:$sec";
    return $self->_convertTimestamp($ts, '%Y-%b-%d %T');
}

# Oct 17 14:27:03 zentyal6-dev amavis[3388]: (03388-04) Passed CLEAN, [127.0.0.1] <root@zentyal6-dev.zentyal-domain.lan> -> <bruno@zentyal-domain.lan>, Message-ID: <20191017122700.GA4648@zentyal6-dev.zentyal-domain.lan>, Hits: 1.984
my $amavisLineRe = qr{^\s\(.*?\)\s
                (\w+)\s([\w\-]+).*?, # action (Passed or Blocked) and event type
                \s(\[.*?\])\s<(.*?)>\s->\s<(.*?)>, # mail sender and receiver
                \s(Message-ID:\s.*?), # Message-ID
                \sHits:\s([\d\.\-]+) # Spam hits ('-' for none)
                }x;

sub processLine
{
    my ($self, $file, $line, $dbengine) = @_;
    if ($file ne MAIL_LOG) {
        return;
    }elsif (not $line =~ m/amavis/) {
        return;
    }

    my $header;
    ($header, $line) = split 'amavis.*?:' , $line, 2;
    $line or next;

    if (not $line =~ $amavisLineRe) {
        return;
    }

    my ($action, $event, $from, $to, $hits) = ($1, $2, $4, $5, $7);

    my $mailname = $self->{mailname};
    if (($from =~ m/@\Q$mailname\E$/) and ($to =~ m/@\Q$mailname\E$/)) {
        return;
    }

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

                  timestamp => $date,
                 };

    if ($hits ne '-') {
        $values->{'spam_hits'} = $hits;
    }

    $dbengine->insert(SMTP_FILTER_TABLE, $values);
}

1;
