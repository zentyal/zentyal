package EBox::Gettext;

use Locale::gettext;
use EBox::Config;
use Encode qw(:all);

BEGIN {
	use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	@ISA = qw(Exporter);
	@EXPORT = qw{ __ __x __d settextdomain gettextdomain langs };
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
	_utf8_on($string);
	return $string;
}

sub __x # (text, %variables)
{
	my ($msgid, %vars) = @_;
	_set_packagedomain();
	my $string = gettext($msgid);
	_unset_packagedomain();
	_utf8_on($string);
	return __expand($string, %vars);
}

sub __d # (text,domain)
{
	my ($string,$domain) = @_;
	bindtextdomain($domain, EBox::Config::locale());
	textdomain($domain);
	$string = gettext($string);
	textdomain($cur_domain);
	_utf8_on($string);
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
	my ($package, $filename, $line) = caller 2;
	my $domain = undef;
	eval {$domain = $package->domain};
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

use utf8;
my $langs;
$langs->{'es_ES.UTF-8'} = 'Castellano';
$langs->{'ca_ES.UTF-8'} = 'Català';
$langs->{'C'} = 'English';
$langs->{'fr_FR.UTF-8'} = 'Français';
no utf8;

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
