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

package EBox::MailFilter::Model::FileExtensionACL;

use base 'EBox::Model::DataTable';

# Class:
#
#    EBox::Mail::Model::ObjectPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::MailFilter::Types::FileExtension;

# FIXME: This takes about 40 seconds to populate and show
# the first time. Try to see if it can be improved.
use constant DEFAULT_EXTENSIONS => qw(
        ade adp asx bas bat cab chm cmd com cpl crt dll exe hlp
        ini hta inf ins isp lnk mda mdb mde mdt mdw mdz msc msi
        msp mst pcd pif prf reg scf scr sct sh shs shb sys url vb
        be vbs vxd wsc wsf wsh otf ops doc xls gz tar zip tgz bz2
        cdr dmg smi sit sea bin hqx rar mp3 mpeg mpg avi asf iso
        ogg wmf cue sxw stw stc sxi sti sxd sxg odt ott ods
        ots odp otp odg otg odm odf odc odb odi pdf
);

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;
}

# Group: Protected methods

# Method: _table
#
#       The table description
#
sub _table
{
    my @tableHeader =
        (
         new EBox::MailFilter::Types::FileExtension(
             fieldName     => 'extension',
             printableName => __('File extension'),
             unique        => 1,
             editable      => 1,
             ),
         new EBox::Types::Boolean(
             fieldName     => 'allow',
             printableName => __('Allow'),
             editable      => 1,
             defaultValue  => 1,
             ),
        );

    my $dataTable =
    {
        tableName          => __PACKAGE__->nameFromClass,
        printableTableName => __(q{File extensions}),
        modelDomain        => 'mail',
        'defaultController' => '/MailFilter/Controller/FileExtensionACL',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __("file extension"),
        help               => __("Extensions which are not listed below are allowed"),
        pageSize           => 5,
    };
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows)  = @_;

    unless (@{$currentRows}) {
        # if there are no rows, we have to add them
        foreach my $extension (DEFAULT_EXTENSIONS) {
            $self->add(extension => $extension);
        }
        return 1;
    } else {
        return 0;
    }
}

# Method: banned
#
# Returns:
#   - reference to a list of banned extensions
#
sub banned
{
    my ($self) = @_;

    my @banned = @{$self->findAllValue(allow => 0)};
    @banned = map { $self->row($_)->valueByName('extension') } @banned;

    return \@banned;
}

sub bannedRegexes
{
    my ($self) = @_;

    my @banned = map { '\.' . $_ .'$' } @{ $self->banned() };

    return \@banned;
}

1;
