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

package EBox::Squid::Model::MIME;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;

use Perl6::Junction qw(all);

use constant DEFAULT_MIME_TYPES => qw(
        audio/mpeg audio/x-mpeg audio/x-pn-realaudio audio/x-wav
        video/mpeg video/x-mpeg2 video/acorn-replay video/quicktime
        video/x-msvideo video/msvideo application/gzip
        application/x-gzip application/zip application/compress
        application/x-compress application/java-vm
        application/x-shockwave-flash application/x-shockwave-flash2-preview
        application/futuresplash image/vnd.rn-realflash
);

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless  $self, $class;
    return $self;
}

sub _tableHeader
{
    my @tableHeader =
        (
         new EBox::Types::Text(
             fieldName     => 'MIMEType',
             printableName => __('MIME Type'),
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

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows)  = @_;

    unless (@{$currentRows}) {
        # if there are no rows, we have to add them
        foreach my $type (DEFAULT_MIME_TYPES) {
            $self->add(MIMEType => $type);
        }
        return 1;
    } else {
        return 0;
    }
}

sub validateTypedRow
{
    my ($self, $action, $params_r) = @_;

    if (exists $params_r->{MIMEType} ) {
        my $type = $params_r->{MIMEType}->value();
        $self->checkMimeType($type);
    }
}

# Function: bannedMimeTypes
#
#       Fetch the banned MIME types
#
# Returns:
#
#       Array ref - containing the MIME types
sub banned
{
    my ($self) = @_;

    my @banned = @{$self->findAllValue(allowed => 0)};
    @banned = map { $self->row($_)->valueByName('MIMEType') } @banned;

    return \@banned;
}

#       A MIME type follows this syntax: type/subtype
#       The current registrated types are: <http://www.iana.org/assignments/media-types/index.html>
#
my @ianaMimeTypes = ("application",
        "audio",
        "example",
        "image",
        "message",
        "model",
        "multipart",
        "text",
        "video",
        "[Xx]-.*" );
my $allIanaMimeType = all @ianaMimeTypes;

sub checkMimeType
{
    my ($self, $type) = @_;

    my ($mainType, $subType) = split '/', $type, 2;

    if (not defined $subType) {
        throw EBox::Exceptions::InvalidData(
                data  => __('MIME Type'),
                value => $type,
                advice => __('A MIME Type must follow this syntax: type/subtype'),
        );
    }

    if ($mainType ne $allIanaMimeType) {
        throw EBox::Exceptions::InvalidData(
                data  => __('MIME Type'),
                value => $type,
                advice => __x(
                    '{type} is not a valid IANA type',
                    type => $mainType,
                    )
        );
    }

    if (not $subType =~ m{^[\w\-\d\.+]+$} ) {
        throw EBox::Exceptions::InvalidData(
                data   => __('MIME Type'),
                value  => $type,
                advice => __x(
                    '{t} subtype has a wrong syntax',
                    t => $subType,
                    )
        );
    }

    return 1;
}

sub _table
{
    my ($self) = @_;

    my $dataTable =
    {
        tableName          => 'MIME',
        modelDomain        => 'Squid',
        printableTableName => __('MIME types'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        checkAll           => [ 'allowed' ],
        tableDescription   => $self->_tableHeader(),
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __('MIME type'),
        help               => __("Allow/Deny the HTTP traffic of the files which the given MIME types. MIME types not listed here are allowed.\nThe filter needs a 'filter' policy to be in effect"),

        messages           => {
            add => __('MIME type added'),
            del =>  __('MIME type removed'),
            update => __('MIME type updated'),
        },
        sortedBy           => 'MIMEType',
    };
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
sub viewCustomizer
{
    my ($self) = @_;

    my $custom = $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([]);

    return $custom;
}

sub _aclName
{
    my ($sef, $profileId) = @_;
    my $aclName = $profileId . '~mime';
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

        my $mime = $row->valueByName('MIMEType');
        push @acls, "acl $name rep_mime_type -i ^$mime\$";
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
        type => 'http_reply_access',
        acl => $aclName,
        policy => 'deny',
    };
    return [$rule];
}

1;
