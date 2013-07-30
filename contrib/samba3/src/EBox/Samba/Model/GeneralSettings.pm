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

# Class: EBox::Samba::Model::GeneralSettings
#
#   This model is used to configure file sharing eneral settings.
#

package EBox::Samba::Model::GeneralSettings;

use EBox::Gettext;
use EBox::Validate qw(:all);
use Error qw(:try);

use EBox::Samba;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::Text;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Config;
use EBox::View::Customizer;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

# see http://support.microsoft.com/kb/909264
my @reservedNames = (
'ANONYMOUS',
'AUTHENTICATED USER',
'BATCH',
'BUILTIN',
'CREATOR GROUP',
'CREATOR GROUP SERVER',
'CREATOR OWNER',
'CREATOR OWNER SERVER',
'DIALUP',
'DIGEST AUTH',
'INTERACTIVE',
'INTERNET',
'LOCAL',
'LOCAL SYSTEM',
'NETWORK',
'NETWORK SERVICE',
'NT AUTHORITY',
'NT DOMAIN',
'NTLM AUTH',
'NULL',
'PROXY',
'REMOTE INTERACTIVE',
'RESTRICTED',
'SCHANNEL AUTH',
'SELF',
'SERVER',
'SERVICE',
'SYSTEM',
'TERMINAL SERVER',
'THIS ORGANIZATION',
'USERS',
'WORLD',
);

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

# Method: validateTypedRow
#
#       Override <EBox::Model::DataTable::validateTypedRow> method
#
sub validateTypedRow
{
    my ($self, $action, $oldParams, $newParams) = @_;

    my $netbios = exists $newParams->{'netbios'} ?
                         $newParams->{'netbios'}->value() :
                         $oldParams->{'netbios'}->value();

    my $workgroup = exists $newParams->{'workgroup'} ?
                           $newParams->{'workgroup'}->value() :
                           $oldParams->{'workgroup'}->value();

    if (uc($netbios) eq uc($workgroup)) {
        throw EBox::Exceptions::External(
                __('Netbios and workgroup must have different names'));
    }

    $self->_checkNetbiosName($netbios);
    $self->_checkDomainName($workgroup);

    # Check for incompatibility between PDC and PAM
    # only on slave servers

    my $users = EBox::Global->modInstance('users');
    return unless ($users->mode() eq 'slave');

    my $pdc = exists $newParams->{pdc} ?
                  $newParams->{pdc}->value() :
                  $oldParams->{pdc}->value();

    my $pam = $users->model('PAM')->enable_pamValue();

    if ($pam and $pdc) {
        throw EBox::Exceptions::External(__x('A slave server can not act as PDC if PAM is enabled. You can do disable PAM at {ohref}LDAP Settings{chref}.',
            ohref => q{<a href='/Users/Composite/Settings/'>},
            chref => q{</a>}));
    }
}

sub _checkDomainName
{
    my ($self, $domain) = @_;

    if ($domain =~ m/\.local$/) {
        throw EBox::Exceptions::External(__(q{Domain name cannot end in '.local'}));
    }

    $self->_checkWinName($domain, __('Domain name'));
}

sub _checkNetbiosName
{
    my ($self, $netbios) = @_;
    $self->_checkWinName($netbios, __('NetBIOS computer name'));
}

sub _checkWinName
{
    my ($self, $name, $type) = @_;

    my $length = length $name;
    if ($length > 15) {
        throw EBox::Exceptions::External(
                __x('{type} is limited to a maximum of 15 characters.',
                    type => $type)
        );
    }

    my @parts = split '\.', $name;
    foreach my $part (@parts) {
        $part = uc $part;
        foreach my $reserved (@reservedNames) {
            if ($part eq $reserved) {
                throw EBox::Exceptions::External(
                    __x(q{{type} cannot contain the reserved name {reserved}},
                         type => $type,
                         reserved => $reserved)
                   );
            }
        }
    }
}

sub _table
{
    my $prefix = EBox::Config::configkey('custom_prefix');
    $prefix = 'zentyal' unless $prefix;

    my @tableHead =
    (
        new EBox::Types::Boolean(
            'fieldName' => 'pdc',
            'printableName' => __('Enable PDC'),
            'defaultValue' => 1,
            'editable' => 1,
        ),
        new EBox::Types::DomainName(
            'fieldName' => 'workgroup',
            'printableName' => __('Domain name'),
            'defaultValue' => uc($prefix) . '-DOMAIN',
            'editable' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'netbios',
            'printableName' => __('NetBIOS computer name'),
            'defaultValue' => EBox::Samba::defaultNetbios(),
            'editable' => 1,
        ),
        new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Description'),
            'defaultValue' => ucfirst($prefix) . ' File Server',
            'editable' => 1,
        ),
        new EBox::Types::Boolean(
            'fieldName' => 'roaming',
            'printableName' => __('Enable roaming profiles'),
            'defaultValue' => 0,
            'editable' => 1,
        ),
        new EBox::Types::Select(
            'fieldName' => 'drive',
            'printableName' => __('Drive letter'),
            'populate' => \&_drive_letters,
            'editable' => 1,
        ),
        new EBox::Types::Select(
                'fieldName' => 'sambaGroup',
                'printableName' => __('Samba group'),
                'populate' => \&_samba_group,
                'editable' => 1,
                'noCache' => 1,
                'help' => __('Only users belonging to this group will have a samba account. Sync happens every hour')
                ),
    );
    my $dataTable =
    {
        'tableName' => 'GeneralSettings',
        'printableTableName' => __('General settings'),
        'modelDomain' => 'Samba',
        'defaultActions' => [ 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
        'help' => __('On this page you can set different general settings for Samba'),
    };

    return $dataTable;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to show and hide source and destination ports
#   depending on the protocol
#
#
sub viewCustomizer
{
    my ($self) = @_;
    my $customizer = new EBox::View::Customizer();
    my $fields = [qw/roaming drive/];
    $customizer->setModel($self);
    $customizer->setOnChangeActions(
            { pdc =>
                {
                on  => { enable => $fields },
                off => { disable => $fields },
                }
            });
    return $customizer;
}

sub _drive_letters
{
    my @letters;

    foreach my $letter ('H'..'Z') {
        $letter .= ':';
        push (@letters, { value => $letter, printableValue => $letter });
    }

    return \@letters;
}

# Method: headTile
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
#
sub headTitle
{
    return undef;
}

sub _samba_group
{
    my @groups = ( { value => 1901, printableValue => __('All users') });
    my $users = EBox::Global->modInstance('users');

    return \@groups unless ($users->configured());

    my @sortedGroups = sort { $a->{account} cmp $b->{account} }  $users->groups();
    for my $group (@sortedGroups) {
        push (@groups, { value => $group->{gid},
                printableValue => $group->{account} });
    }
    return \@groups;
}

1;
