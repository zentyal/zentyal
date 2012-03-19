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
use POSIX;

use EBox::Gettext;
use EBox::Menu;

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#   Override <EBox::Model::DataTable::validateTypedRow> method
#
sub validateTypedRow
{
    my ($self, $action, $oldParams, $newParams) = @_;

    my $langs = EBox::Gettext::langs();
    my $lang = $newParams->{'language'}->value();

    my $showPkgWarn = not EBox::Config::configkey('custom_prefix');
    my $pkgInstalled = 1;
    my $package = '';
    if ($showPkgWarn) {
        my ($pkglang) = split (/_/, $lang);
        if (($pkglang eq 'pt') or ($pkglang eq 'zh')) {
            ($pkglang) = split (/\./, $lang);
            $pkglang =~ tr/_/-/;
            $pkglang =~ tr/[A-Z]/[a-z]/;
            $pkglang = 'pt' if ($pkglang eq 'pt-pt');
        }
        $package = "language-pack-zentyal-$pkglang";
        $pkgInstalled = $lang eq 'C' ? 1 : EBox::GlobalImpl::_packageInstalled($package);
    }

    if ($showPkgWarn and not $pkgInstalled) {
        throw EBox::Exceptions::External(
            __x('The language pack for {l} is missing, you can install it by running the following command: {c}',
                              l => $lang, c => "<b>sudo apt-get install $package</b>"));
    }
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Select( fieldName     => 'language',
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

sub _populateLanguages
{
    my $langs = EBox::Gettext::langs();

    my $array = [];
    foreach my $l (sort keys %{$langs}) {
        push ($array, { value => $l, printableValue => $langs->{$l} });
    }
    return $array;
}

1;
