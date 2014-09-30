# Copyright (C) 2013 Zentyal S. L.
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

package EBox::OpenChange::Model::RPCProxy;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Link;

# Method: new
#
#   Constructor, instantiate new model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

# Method: _table
#
#   Returns model description
#
sub _table
{
    my ($self) = @_;

    my $tableDesc = [
        new EBox::Types::Link(
            fieldName       => 'certificate',
            printableName   => __('CA Certificate'),
            volatile        => 1,
            optionalLabel   => 0,
            acquirer        => sub { return '/Downloader/RPCCert'; },
            HTMLViewer      => '/ajax/viewer/downloadLink.mas',
            HTMLSetter      => '/ajax/viewer/downloadLink.mas',
        ),
    ];

    my $dataForm = {
        tableName          => 'RPCProxy',
        printableTableName => __('HTTP and HTTPS clients access'),
        modelDomain        => 'OpenChange',
        defaultActions     => [],
        tableDescription   => $tableDesc,
        help               => __('FIXME'), # FIXME TODO
    };

    return $dataForm;
}

1;
