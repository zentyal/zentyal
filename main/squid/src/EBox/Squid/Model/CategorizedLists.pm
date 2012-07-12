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

use strict;
use warnings;

package EBox::Squid::Model::CategorizedLists;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use EBox::Sudo;
use EBox::Types::Text::WriteOnce;
use EBox::Squid::Types::ListArchive;

use Error qw(:try);
use Perl6::Junction qw(any);
use File::Basename;

use constant LIST_FILE_DIR => '/etc/dansguardian/extralists';

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
         new EBox::Types::Text::WriteOnce(
             fieldName => 'description',
             printableName => ('Description'),
             unique   => 1,
             editable => 1,
         ),
         new EBox::Squid::Types::ListArchive(
             fieldName     => 'fileList',
             printableName => __('File'),
             unique        => 1,
             editable      => 1,
             optional      => 1,
             allowDownload => 1,
             filePath      => '/tmp/FIXME.tar.gz',
             user          => 'root',
             group         => 'root',
         ),
    );

    my $dataTable =
    {
        tableName          => 'CategorizedLists',
        pageTitle          => __('HTTP Proxy'),
        printableTableName => __('Categorized Lists'),
        modelDomain        => 'Squid',
        defaultActions => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        rowUnique          => 1,
        automaticRemove    => 1,
        printableRowName   => __('categorized list'),
        help               => __('You can upload files with categorized lists of domains. You will be able to filter by those categories in each filter profile.'),
    };
}

# Method: viewCustomizer
#
#      To display a permanent message
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    my $securityUpdatesAddOn = 0;
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
    }

    unless ($securityUpdatesAddOn) {
        $customizer->setPermanentMessage($self->parentModule()->_commercialMsg(), 'ad');
    }

    return $customizer;
}

1;
