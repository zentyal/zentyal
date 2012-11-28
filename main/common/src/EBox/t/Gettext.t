use strict;
use warnings;

use EBox;
use EBox::Gettext;
use Test::More qw(no_plan);

my ($locale) = @ARGV;
$locale or $locale = 'es_ES.UTF8';

my ($pkglang) = split (/_/, $locale);
if (($pkglang eq 'pt') or ($pkglang eq 'zh')) {
    ($pkglang) = split (/\./, $locale);
    $pkglang =~ tr/_/-/;
    $pkglang =~ tr/[A-Z]/[a-z]/;
    $pkglang = 'pt' if ($pkglang eq 'pt-pt');
}
my $package = "language-pack-zentyal-$pkglang";
system "dpkg -l $package > /dev/null";
if ($? != 0) {
    die "To do this test with locale $locale you need to install $package";
}

diag "Switching to locale $locale";
EBox::setLocaleEnvironment($locale);

diag "This test assumes that the translation of digit 0 to locale $locale is the same digit '0'";
my $notTranslatedString = 'we bet this string is not translated in any po. no traducida por favor. foobar zabar';
my @tests = (
           ['' => ''],
           [undef,  => ''],
           ['   ' => '   '],
           ["\n" => "\n"],
           [0 => 0],
           [$notTranslatedString => $notTranslatedString],
          );

foreach my $test_r  (@tests) {
    my ($st, $wanted) = @{ $test_r };
    my $testName;
    if (defined $st) {
        $testName = "__('$st') => '$wanted'";
    } else {
        $testName = "__(undef) => '$wanted'";
    }

    my $newSt = __($st);
    is $newSt, $wanted, $testName;
}

1;
