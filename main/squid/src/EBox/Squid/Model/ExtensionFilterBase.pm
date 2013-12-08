# Copyright (C) 2009-2011 Zentyal S.L.
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

package EBox::Squid::Model::ExtensionFilterBase;
use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;

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

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;
}

sub validateTypedRow
{
    my ($self, $action, $params_r) = @_;

    if (exists $params_r->{extension} ) {
        my $extension = $params_r->{extension}->value();
        if ($extension =~ m{\.}) {
            throw EBox::Exceptions::InvalidData(
                    data  => __('File extension'),
                    value => $extension,
                    advice => ('Dots (".") are not allowed in file extensions')
            );
        }
    }
}

# Function: bannedExtensions
#
#       Fetch the banned extensions
#
# Returns:
#
#       Array ref - containing the extensions
sub banned
{
    my ($self) = @_;

    my @banned = @{$self->findAllValue(allowed => 0)};
    @banned = map { $self->row($_)->valueByName('extension') } @banned;

    return \@banned;
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

# Group: Protected methods

sub _tableHeader
{
    my @tableHeader = (
        new EBox::Types::Text(
                              fieldName     => 'extension',
                              printableName => __('Extension'),
                              unique        => 1,
                              editable      => 1,
                              optional      => 0,
                             ),
         new EBox::Types::Boolean(
                                  fieldName     => 'allowed',
                                  printableName => __('Allow'),

                                  optional      => 0,
                                  editable      => 1,
                                  defaultValue  => 1,
                                 ),
    );

    return \@tableHeader;
}

1;
