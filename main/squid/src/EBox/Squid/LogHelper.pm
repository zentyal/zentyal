# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Squid::LogHelper;
use base 'EBox::LogHelper';

no warnings 'experimental::smartmatch';
use feature qw(switch);

use EBox;
use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Validate;
use POSIX qw(strftime);

use constant SQUIDLOGFILE => '/var/log/squid/access.log';
use constant DANSGUARDIANLOGFILE => '/var/log/dansguardian/access.log';

# TODO: Clear this periodically
my %temp;

sub new
{
    my $class = shift;
    my $self = {};

    my $global = EBox::Global->instance();
    my $squid = $global->modInstance('squid');
    $self->{filterNeeded} = $squid->filterNeeded();

    bless($self, $class);
    return $self;
}

# Method: logFiles
#
#   This function must return the file or files to be read from.
#
# Returns:
#
#   array ref - containing the whole paths
#
sub logFiles
{
    return [SQUIDLOGFILE, DANSGUARDIANLOGFILE];
}

# Method: processLine
#
#   This method will be run every time a new line is received in
#   the associated file. You must parse the line, and generate
#   the messages which will be logged to ebox through an object
#   implementing EBox::AbstractLogger interface.
# Parameters:
#
#   file - file name
#   line - string containing the log line
#   dbengine- An instance of class implemeting AbstractDBEngineinterface
#
sub processLine # (file, line, logger)
{
    my ($self, $file, $line, $dbengine) = @_;
    chomp $line;

    my @fields = split (/\s+/, $line);

    # FIXME: regex match instead of eq ??
    if ($fields[2] eq '127.0.0.1') {
        return;
    }

    my $event;
    given($fields[3]) {
        when (m{TCP_DENIED(_ABORTED)?/403}) {
            if ($file eq  DANSGUARDIANLOGFILE) {
                $event = 'filtered';
            } else {
                $event = 'denied';
            }
        }
        when ('TCP_DENIED/407') {
            # This entry requires authentication, so ignore it
            return;
        }
        default {
            $event = 'accepted';
        }
    }

    # Trim URL string as DB stores it as a varchar(1024)
    my $url = substr($fields[6], 0, 1023);
    if ($file eq  DANSGUARDIANLOGFILE) {
        my $time = strftime ('%Y-%m-%d %H:%M:%S', localtime $fields[0]);
        my $domain = $self->_domain($fields[6]);

        if ($url =~ m/$domain$/) {
            # Squid logs adds a final slash as dansguardian does not
            # So we must add final slash
            $url .= '/';
        }

        $temp{$url}->{timestamp} = $time;
        $temp{$url}->{elapsed} = $fields[1];
        $temp{$url}->{remotehost} = $fields[2];
        $temp{$url}->{code} = $fields[3];
        $temp{$url}->{method} = $fields[5];
        $temp{$url}->{url} = $url;
        $temp{$url}->{domain} = substr($domain, 0, 254);
        $temp{$url}->{peer} = $fields[8];
        $temp{$url}->{mimetype} = $fields[9];
        $temp{$url}->{event} = $event;
    } else {
        if ($self->{filterNeeded}) {
            $temp{$url}->{bytes} = $fields[4];
        } else {
            $self->_fillExternalData($url, $event, @fields);
        }
        $temp{$url}->{rfc931} = $fields[7];

        if ($event eq 'denied') {
            $self->_fillExternalData($url, $event, @fields);
        }
    }
    $self->_insertEvent($url, $dbengine);
}

# Group: Private methods

sub _fillExternalData
{
    my ($self, $url, $event, @fields) = @_;

    unless (defined($temp{$url}{timestamp})) {
        my $time = strftime ('%Y-%m-%d %H:%M:%S', localtime $fields[0]);
        my $domain = $self->_domain($fields[6]);
        $temp{$url}->{timestamp} = $time;
        $temp{$url}->{elapsed} = $fields[1];
        $temp{$url}->{remotehost} = $fields[2];
        $temp{$url}->{bytes} = $fields[4];
        $temp{$url}->{method} = $fields[5];
        $temp{$url}->{url} = $url;
        $temp{$url}->{domain} = substr($domain, 0, 254);
        $temp{$url}->{peer} = $fields[8];
        $temp{$url}->{mimetype} = $fields[9];
        $temp{$url}->{event} = $event;
        $temp{$url}->{code} = $fields[3];
    }
}

sub _insertEvent
{
    my ($self, $id, $dbengine) = @_;

    # Check we got all the data
    if (defined($temp{$id}{rfc931}) and
        defined($temp{$id}{timestamp}) and
        defined($temp{$id}{bytes})) {
        $dbengine->insert('squid_access', $temp{$id});
        delete $temp{$id};
    }
}

# Perform the required modifications from a URL to obtain the domain
sub _domain
{
    my ($self, $url) = @_;

    my $domain = $url;
    $domain =~ s{^http(s?)://}{}g;
    $domain =~ s{/.*}{};

    # IPv6 [ip_v6]
    if (substr($domain, 0, 1) eq '[') {
        $domain =~ s{\[|\]}{}g;
        return $domain;
    }

    $domain =~ s{:.*}{}; # Remove port section
    if (EBox::Validate::checkIP($domain)) {
        return $domain;
    }

    my $shortDomain = "";
    my @components = split(/\./, $domain);
    foreach my $element (reverse @components) {
        if ( $shortDomain eq "" ) {
            $shortDomain = $element;
        } elsif ( length($element) < 3 and length($shortDomain) > 5 ) {
            # Then, we should stop here ( a subdomain)
            last;
        } elsif ((length($shortDomain) < 8) or ($components[0] ne $element)) {
            $shortDomain = $element . '.' . $shortDomain;
        } else {
            last;
        }
    }
    return $shortDomain;
}

1;
