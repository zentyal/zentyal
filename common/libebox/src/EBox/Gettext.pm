# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2006-2008 Warp Networks S.L.
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

package EBox::Gettext;

use Locale::gettext;
use EBox::Config;

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw{ __ __n __x __d settextdomain gettextdomain langs };
	%EXPORT_TAGS = ( DEFAULT => \@EXPORT );
	@EXPORT_OK = qw();
	$VERSION = EBox::Config::version;

}

my $cur_domain = 'ebox';
my $old_domain;

# Method: settextdomain
#
#	Sets the curent message domain   
#
# Parameters:
#
#       domain - The domain name
#
sub settextdomain # (domain)
{
	my $domain = shift;
	textdomain($domain);
	bindtextdomain($domain, EBox::Config::locale());
	my $old_domain = $cur_domain;
	$cur_domain = $domain;
	return $old_domain;
}

#
# Method: gettextdomain 
#
# 	Gathers  the curent message domain   
#
# Returns:
#
#      The current message domain 
#
sub gettextdomain
{
	return $cur_domain;
}

sub __ # (text)
{
	_set_packagedomain();
	my $string = gettext(shift);
	_unset_packagedomain();
	return $string;
}

sub __n # (text)
{
	my $string = shift;
	my ($p, $a, $c) = caller;
	return $string;
}

sub __x # (text, %variables)
{
	my ($msgid, %vars) = @_;
	_set_packagedomain();
	my $string = gettext($msgid);
	_unset_packagedomain();
	return __expand($string, %vars);
}

sub __d # (text,domain)
{
	my ($string,$domain) = @_;
	bindtextdomain($domain, EBox::Config::locale());
	textdomain($domain);
	$string = gettext($string);
	textdomain($cur_domain);
	return $string;
}

sub __expand # (translation, %arguments)
{
	my ($translation, %args) = @_;

	my $re = join '|', map { quotemeta $_ } keys %args;
	$translation =~ s/\{($re)\}/defined $args{$1} ? $args{$1} : "{$1}"/ge;
	return $translation;
}

# Method: _set_packagedomain
# 
# 	Fetch and set the module's domain.
# 	Tries to call $PACKAGE::domain function
# 	to fetch the domain
# 	
sub _set_packagedomain
{
	my ($package, $filename, $line) = caller 1;
	my $domain = undef;
	eval {$domain = $package->domain()};
	if ($domain) {
		$old_domain = settextdomain($domain);
	} else {
		$old_domain = undef;
	}
}

# Method: _unset_packagedomain
#
#	Restore de previous domain
#
sub _unset_packagedomain
{
	if ($old_domain) {
		settextdomain($old_domain);
	}
}

my $langs;
$langs->{'an_ES.UTF-8'} = 'Aragonés';
$langs->{'bg_BG.UTF-8'} = 'Български';
$langs->{'es_ES.UTF-8'} = 'Castellano';
$langs->{'ca_ES.UTF-8'} = 'Català';
$langs->{'da_DK.UTF-8'} = 'Dansk';
$langs->{'de_DE.UTF-8'} = 'Deutsch';
$langs->{'C'} = 'English';
$langs->{'eu_ES.UTF-8'} = 'Euskara';
$langs->{'fa_IR.UTF-8'} = 'فارسی';
$langs->{'fr_FR.UTF-8'} = 'Français';
$langs->{'gl_ES.UTF-8'} = 'Galego';
$langs->{'it_IT.UTF-8'} = 'Italiano';
$langs->{'ja_JP.UTF-8'} = '日本語';
$langs->{'nb_NO.UTF-8'} = 'Norsk (bokmål)';
$langs->{'nl_BE.UTF-8'} = 'Nederlands';
$langs->{'pl_PL.UTF-8'} = 'Polski';
$langs->{'pt_BR.UTF-8'} = 'Português do Brasil';
$langs->{'pt_PT.UTF-8'} = 'Português';
$langs->{'ru_RU.UTF-8'} = 'Русский';
$langs->{'sv_SE.UTF-8'} = 'Svenska';
$langs->{'tr_TR.UTF-8'} = 'Türkçe';
$langs->{'zh_TW.UTF-8'} = '繁體中文';

# Method:  langname
#
#   	Gathers the current set language
#
# Returns:
#	
#	the current domain language
#       
sub langname # (locale)
{
	my ($locale) = @_;

	return $langs->{$locale};
}

# Method: langs
#  	gathers the available languages 
#
# Returns:
#
#	hash reference -  containing the available languages. Each key 
#	represents a *locale* and its value contains the associated 
#	language	 
#		
sub langs
{
	return $langs;
}

1;
