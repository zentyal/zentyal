# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Squid::Model::Extensions;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;

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

sub _table
{
    my ($self) = @_;
    my $warnMsg = q{The extension filter needs a 'filter' policy to take effect};

    my $dataTable =
    {
        tableName          => 'Extensions',
        printableTableName => __('File extensions'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        checkAll           => [ 'allowed' ],
        tableDescription   => $self->_tableHeader(),
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __('extension'),
        help               => __("Allow/Deny the HTTP traffic of the files which the given extensions.\nExtensions not listed here are allowed.\nThe extension filter needs a 'filter' policy to be in effect"),

        messages           => {
            add    => __('Extension added'),
            del    => __('Extension removed'),
            update => __('Extension updated'),
        },
        sortedBy           => 'extension',
    };
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
#
sub viewCustomizer
{
    my ($self) = @_;

    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([]);

    return $custom;
}

sub _aclName
{
    my ($sef, $profileId) = @_;
    my $aclName = $profileId . '~ext';
    return $aclName;
}

sub squidAcls
{
    my ($self, $profileId) = @_;
    my @acls;

    my $name = $self->_aclName($profileId);
    foreach my $id (@{ $self->ids()}) {
        my $row = $self->row($id);
        if ($row->valueByName('allowed')) {
            next;
        }

        my $ext = $row->valueByName('extension');
        push @acls, "acl $name urlpath_regex -i \.$ext\$";
    }
    return \@acls;
}

sub squidRulesStubs
{
    my ($self, $profileId) = @_;
    my $banned;
    foreach my $id (@{ $self->ids()}) {
        my $row = $self->row($id);
         if (not $row->valueByName('allowed')) {
             $banned = 1;
             last;
         }

    }
    if (not $banned) {
        return [];
    }

    my $aclName = $self->_aclName($profileId);
    my $rule = {
        type => 'http_access',
        acl => $aclName,
        policy => 'deny',
    };
    return [$rule];
}

1;

