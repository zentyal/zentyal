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

package EBox::MailFilter::Model::MIMETypeACL;

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
use EBox::MailFilter::Types::MIMEType;

use constant DEFAULT_MIME_TYPES => qw(
        audio/mpeg audio/x-mpeg audio/x-pn-realaudio audio/x-wav
        video/mpeg video/x-mpeg2 video/acorn-replay video/quicktime
        video/x-msvideo video/msvideo application/gzip
        application/x-gzip application/zip application/compress
        application/x-compress application/java-vm
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
         new EBox::MailFilter::Types::MIMEType(
             fieldName     => 'MIMEType',
             printableName => __('MIME Type'),
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
        printableTableName => __(q{MIME types}),
        modelDomain        => 'mail',
        'defaultController' => '/MailFilter/Controller/MIMETypeACL',
        'defaultActions' => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __("MIME type"),
        help               => __("MIME types which are not listed below are allowed. MIME types aren't used by POP transparent proxy"),
        pageSize          => 5,
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
        foreach my $type (DEFAULT_MIME_TYPES) {
            $self->add(MIMEType => $type);
        }
        return 1;
    } else {
        return 0;
    }
}

# Method: banned
#
# Returns:
#   - reference to a list of banned MIME types
#
sub banned
{
    my ($self) = @_;

    my @banned = @{$self->findAllValue(allow => 0)};
    @banned = map { $self->row($_)->valueByName('MIMEType') } @banned;

    return \@banned;
}

sub bannedRegexes
{
    my ($self) = @_;

    my @bannedMimeTypes = @{  $self->banned() };
    @bannedMimeTypes = map {
                             $_ =~ s{/}{\/};
                             '^' . $_ . '$'
                           } @bannedMimeTypes;

    return \@bannedMimeTypes;
}

1;
