# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::CGI::Software::Log;

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use File::Slurp;

use base 'EBox::CGI::ClientBase';

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub actuate
{
    my ($self) = @_;

    $self->{downfile} = '/var/log/ebox/software.log';
    $self->{downfilename} = 'software.log';
}

sub _print
{
    my ($self) = @_;

    if ($self->{error} || not defined($self->{downfile})) {
        $self->SUPER::_print;
        return;
    }

    my @log = read_file($self->{downfile}) or
        throw EBox::Exceptions::Internal("Error opening software.log: $!");

    print ($self->cgi()->header(-type=>'application/octet-stream',
                                -attachment=>$self->{downfilename}));

    print "System info\n";
    print "-----------\n";
    print `cat /etc/lsb-release`;
    print `uname -rsmv`;
    print "\n\n";

    print "Broken packages (if any)\n";
    print "------------------------\n";
    my $output = EBox::Sudo::root("dpkg -l | grep -v ^ii | awk '{ print " . '$1 " " $2 ": " $3 ' . "}'");
    print @{ $output };
    print "\n\n";

    print "/var/log/ebox/software.log\n";
    print "----------------------\n\n";

    if (scalar (@log) <= 5000) {
        print @log;
    } else {
        print @log[-5000..-1];
    }
}

1;
