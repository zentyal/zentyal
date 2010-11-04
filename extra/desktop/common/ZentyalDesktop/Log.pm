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

package ZentyalDesktop::Log;

use strict;
use warnings;

use Log::Log4perl qw(get_logger);

# Method: initLog
#
#   Initialize Zentyal Desktop log
#
sub initLog
{
    my ($self, $dir) = @_:

    my $conf = q(
    log4perl.category.ZentyalDesktop::Config         = ALL, Logfile
    log4perl.appender.Logfile          = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.layout = \
    Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %d %F{1} %L> %m %n
    );
    $conf .= "log4perl.appender.Logfile.filename = $dir";
    print $conf;
    Log::Log4perl::init(\$conf);
}


# Method: getLogger
#
#   Initialize logger
#
# Returns:
#
#   logger instancie
#
sub getLogger
{
    my ($self) = @_;

    my $logger = Log::Log4perl->get_logger('ZentyalDesktop::Config');
    return $logger;
}

1;
