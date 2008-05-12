# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox;

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::DeprecatedMethod;
use POSIX qw(setuid setgid setlocale LC_ALL LC_NUMERIC);
use English;

my $loginit = 0;

sub deprecated
{
	my $debug = EBox::Config::configkey('debug');
	if ($debug eq 'yes') {
		throw EBox::Exceptions::DeprecatedMethod();
	}
}

sub info # (msg)
{
	my ($msg) = @_;
	my $logger = EBox::logger(caller);
	$Log::Log4perl::caller_depth +=1;
	$logger->info($msg);
	$Log::Log4perl::caller_depth -=1;
}

sub error # (msg)
{
	my ($msg) = @_;
	my $logger = EBox::logger(caller);
	$Log::Log4perl::caller_depth +=1;
	$logger->error($msg);
	$Log::Log4perl::caller_depth -=1;
}

sub debug # (msg)
{
	my ($msg) = @_;
	my $logger = EBox::logger(caller);
	$Log::Log4perl::caller_depth +=1;
	$logger->debug($msg);
	$Log::Log4perl::caller_depth -=1;
}

sub warn # (msg)
{
	my ($msg) = @_;
	my $logger = EBox::logger(caller);
	$Log::Log4perl::caller_depth +=1;
	$logger->warn($msg);
	$Log::Log4perl::caller_depth -=1;
}

# initializes Log4perl if necessary, returns the logger for the caller package
sub logger # (caller?) 
{
	my $cat = shift;
	defined($cat) or $cat = caller;
	unless ($loginit) {
		Log::Log4perl->init(EBox::Config::conf() . "/eboxlog.conf");
		$loginit = 1;
	}
	return Log::Log4perl->get_logger($cat);
}

# arguments
# 	- locale: the locale the interface should use
sub setLocale # (locale) 
{
	my $locale = shift;
	open(LOCALE, ">" . EBox::Config::conf() . "/locale");
	print LOCALE $locale;
	close(LOCALE);
}

# returns:
# 	- the locale
sub locale 
{
	my $locale="C";
	if (-f (EBox::Config::conf() . "locale")) {
		open(LOCALE, EBox::Config::conf() . "locale");
		$locale = <LOCALE>;
		close(LOCALE);
	}
	return $locale;
}

sub init
{
	POSIX::setlocale(LC_ALL, EBox::locale());
	POSIX::setlocale(LC_NUMERIC, 'C');

	my @groups = @{EBox::Config::groups()};
	my $gids = '';
	for my $group (@groups) {
		$gids .= getgrnam($group) . ' ';	
	}
	$GID = $EGID = getgrnam(EBox::Config::group()) . " $gids";

	my $user = EBox::Config::user();
	my $uid = getpwnam($user);
	setuid($uid) or die "Cannot change user to $user";
}

1;
