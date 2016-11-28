# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox;

use EBox::Config;
use EBox::Exceptions::DeprecatedMethod;
use EBox::Exceptions::MissingArgument;
use POSIX qw(setuid setgid setlocale LC_ALL LC_NUMERIC);
use English;
use File::Slurp;

use constant LOGGER_CAT => 'EBox';

my $loginit = 0;

my $debug = 0;

sub deprecated
{
    if ($debug) {
        throw EBox::Exceptions::DeprecatedMethod();
    }
}

sub info
{
    my ($msg) = @_;

    my $logger = EBox::logger(LOGGER_CAT);
    $Log::Log4perl::caller_depth +=1;
    $logger->info($msg);
    $Log::Log4perl::caller_depth -=1;
}

sub error
{
    my ($msg) = @_;

    my $logger = EBox::logger(LOGGER_CAT);
    $Log::Log4perl::caller_depth +=1;
    $logger->error($msg);
    $Log::Log4perl::caller_depth -=1;
}

sub debug
{
    my ($msg) = @_;

    if ($debug) {
        my $logger = EBox::logger(LOGGER_CAT);
        $Log::Log4perl::caller_depth +=1;
        $logger->debug($msg);
        $Log::Log4perl::caller_depth -=1;
    }
}

sub warn
{
    my ($msg) = @_;

    my $logger = EBox::logger(LOGGER_CAT);
    $Log::Log4perl::caller_depth +=1;
    $logger->warn($msg);
    $Log::Log4perl::caller_depth -=1;
}

sub debugDump
{
    my ($msg, $data);
    if (@_ > 1) {
        ($msg, $data) = @_;
        $msg .= ' ';
    } else {
        ($data) = @_;
        $msg = '';
    }

    use Data::Dumper;
    $msg .= Dumper($data);
    EBox::debug($msg);
}

sub trace
{
    my ($msg) = @_;

    if ($debug) {
        use Devel::StackTrace;
        my $trace = new Devel::StackTrace(indent => 1);
        EBox::debug($trace->as_string());
    }
}

sub initLogger
{
    my ($conffile) = @_;
    my $umask = umask(022);
    unless ($loginit) {
        Log::Log4perl->init(EBox::Config::conf() . '/' . $conffile);
        $loginit = 1;
    }
    umask($umask);
}

# returns the logger for the caller package, initLogger must be called before
sub logger # (caller?)
{
    my ($cat) = @_;
    defined($cat) or $cat = LOGGER_CAT;
    if(not $loginit) {
            use Devel::StackTrace;

            my $trace = Devel::StackTrace->new();
            print STDERR $trace->as_string();
        }
    return Log::Log4perl->get_logger($cat);
}

# arguments
#   - locale: the locale the interface should use
sub setLocale # (locale)
{
    my ($locale) = @_;

    open (my $fh, ">" . EBox::Config::conf() . '/locale');
    print $fh $locale;
    close ($fh);
}

# returns:
#   - the locale
sub locale
{
    my $locale;
    my $localeFile = EBox::Config::conf() . 'locale';
    if (-f $localeFile) {
        open (my $fh, $localeFile);
        $locale = <$fh>;
        close ($fh);
    } elsif (-f '/etc/default/locale') {
        $locale = read_file('/etc/default/locale');
        ($locale) = $locale =~ /LANG="(.+)"/;
    }
    unless ($locale) {
        $locale = 'C';
    }

    return $locale;
}

sub setLocaleEnvironment
{
    my ($locale) = @_;
    defined $locale or
        EBox::Exceptions::MissingArgument->throw('locale');
    POSIX::setlocale(LC_ALL, $locale);
    POSIX::setlocale(LC_NUMERIC, 'C');
    $ENV{LANG}     = $locale;
    $ENV{LANGUAGE} = $locale;
}

sub init
{
    my $locale = EBox::locale();
    setLocaleEnvironment($locale);

    my $gids = EBox::Config::gids();
    $GID = $EGID = getgrnam(EBox::Config::group()) . " $gids";

    my $user = EBox::Config::user();
    my $uid = getpwnam($user);
    setuid($uid) or die "Cannot change user to $user. Are you root?";

    EBox::initLogger('eboxlog.conf');

    # Set HOME environment variable to avoid some issues calling
    # external programs
    $ENV{HOME} = EBox::Config::home();

    $debug = EBox::Config::boolean('debug');
}

1;
