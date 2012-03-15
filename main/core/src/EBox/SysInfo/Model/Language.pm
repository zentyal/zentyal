# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::SysInfo::Model::Language
#
#   This model is used to configure the interface languaje
#

package EBox::SysInfo::Model::Language;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

#% if ($showPkgWarn and not $pkgInstalled) {
# <div class="warning"><% __x('The language pack for {l} is missing, you can install it by running the following command: {c}', l => $langs->{$lang},
# c => "<br/><br/><b>sudo apt-get install $package</b>") %></div>
#% }

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Select( fieldName     => 'language',
                                              printableName => __('Language'),
                                              populate      => \&_populateLanguages,
                                              editable      => 1));

    my $dataTable =
    {
        'tableName' => 'Language',
        'printableTableName' => __('Language selection'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

# Method: formSubmitted
#
# Overrides:
#
#   <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    #if (defined($self->param('setlang'))) {
    #    my $lang = $self->param('lang');
    #    EBox::setLocale($lang);
    #    POSIX::setlocale(LC_ALL, EBox::locale());
    #    EBox::Menu::regenCache();
    #    EBox::Global->getInstance()->modChange('apache');
    #    my $audit = EBox::Global->modInstance('audit');
    #    $audit->logAction('System', 'General', 'changeLanguage', $lang);
    #}
}

sub _populateLanguages
{
    my $langs = EBox::Gettext::langs();

    #my $lang = 'C'; # TODO The current lang

    #my $showPkgWarn = not EBox::Config::configkey('custom_prefix');
    #my $pkgInstalled = 1;
    #my $package = '';
    #if ($showPkgWarn) {
    #    my ($pkglang) = split (/_/, $lang);
    #    if (($pkglang eq 'pt') or ($pkglang eq 'zh')) {
    #        ($pkglang) = split (/\./, $lang);
    #        $pkglang =~ tr/_/-/;
    #        $pkglang =~ tr/[A-Z]/[a-z]/;
    #        $pkglang = 'pt' if ($pkglang eq 'pt-pt');
    #    }
    #    $package = "language-pack-zentyal-$pkglang";
    #    $pkgInstalled = $lang eq 'C' ? 1 : EBox::GlobalImpl::_packageInstalled($package);
    #}

    my $array = [];
    foreach my $l (sort keys %{$langs}) {
        push ($array, { value => $l, printableValue => $langs->{$l} });
    }
    return $array;
}

1;
