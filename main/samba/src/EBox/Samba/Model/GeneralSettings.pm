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
use EBox::Exceptions::External;

use strict;
use warnings;

use base 'EBox::Model::DataForm';

use constant MAXNETBIOSLENGTH     => 15;
use constant MAXWORKGROUPLENGTH   => 32;
use constant MAXDESCRIPTIONLENGTH => 255;

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

    my $netbios = exists $newParams->{'netbiosName'} ?
                         $newParams->{'netbiosName'}->value() :
                         $oldParams->{'netbiosName'}->value();

    my $workgroup = exists $newParams->{'workgroup'} ?
                           $newParams->{'workgroup'}->value() :
                           $oldParams->{'workgroup'}->value();

    my $realm = exists $newParams->{'realm'} ?
                       $newParams->{'realm'}->value() :
                       $oldParams->{'realm'}->value();
    my $description = exists $newParams->{'description'} ?
                             $newParams->{'description'}->value() :
                             $oldParams->{'description'}->value();

    if (uc ($netbios) eq uc ($workgroup)) {
        throw EBox::Exceptions::External(
                __('Netbios and workgroup must have different names'));
    }

    $self->_checkNetbiosName($netbios);
    $self->_checkDomainName($workgroup);
    $self->_checkDomainName($realm);
    $self->_checkDescriptionString($description);

    # Check if the password meet the policy requirements
    if (exists $newParams->{password}) {
        my $password = $newParams->{password}->value();

        # Check if the password meet the complexity constraints
        unless ($password =~ /[a-z]+/ and $password =~ /[A-Z]+/ and
                $password =~ /[0-9]+/ and length ($password) >=8) {
                throw EBox::Exceptions::External(
                    __('The password does not meet the password policy requirements. ' .
                       'It must be at least eight characters long and contain uppercase, ' .
                       'lowercase and numbers'));
        }
    }

#    # Check for incompatibility between PDC and PAM
#    # only on slave servers
#
#    my $users = EBox::Global->modInstance('users');
#    return unless ($users->mode() eq 'slave');
#
#    my $pdc = exists $newParams->{pdc} ?
#                  $newParams->{pdc}->value() :
#                  $oldParams->{pdc}->value();
#
#    my $pam = $users->model('PAM')->enable_pamValue();
#
#    if ($pam and $pdc) {
#        throw EBox::Exceptions::External(__x('A slave server can not act as PDC if PAM is enabled. You can do disable PAM at {ohref}LDAP Settings{chref}.',
#            ohref => q{<a href='/Users/Composite/Settings/'>},
#            chref => q{</a>}));
#    }
}

sub _checkDomainName
{
    my ($self, $domain) = @_;

    if (length ($domain) > MAXWORKGROUPLENGTH) {
        throw EBox::Exceptions::External(__('Domain or workgroup name field is empty'));
    }
    if (length ($domain) <= 0) {
        throw EBox::Exceptions::Externam(__('Domain or workgroup name is too long'));
    }
    if ($domain =~ m/\.local$/) {
        throw EBox::Exceptions::External(__(q{Domain name cannot end in '.local'}));
    }

    $self->_checkWinName($domain, __('Domain name'));
}

sub _checkNetbiosName
{
    my ($self, $netbios) = @_;

    if (length ($netbios) <= 0) {
        throw EBox::Exceptions::External(__('NetBIOS name field is empty'));
    }
    if (length ($netbios) > MAXNETBIOSLENGTH) {
        throw EBox::Exceptions::Externam(__('NetBIOS name is too long'));
    }
    $self->_checkWinName($netbios, __('NetBIOS computer name'));

}

sub _checkDescriptionString
{
    my ($self, $description) = @_;

    if (length ($description) <= 0) {
        throw EBox::Exceptions::External(__('Description string is empty'));
    }
    if (length ($description) > MAXDESCRIPTIONLENGTH) {
        throw EBox::Exceptions::Externam(__('Description string is too long'));
    }
}

sub _checkWinName
{
    my ($self, $name, $type) = @_;

    my $length = length $name;
    if ($length > MAXNETBIOSLENGTH) {
        throw EBox::Exceptions::External(
                __x('{type} is limited to a maximum of 15 characters.',
                    type => $type)
        );
    }

    my @parts = split ('\.', $name);
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

sub _mod_enabled
{
    my $module = EBox::Global->modInstance('samba');
    return not $module->isEnabled();
}

sub _table
{
    my ($self) = @_;

    my @tableHead =
    (
        new EBox::Types::Select(
            'fieldName' => 'mode',
            'printableName' => __('Server Role'),
            'populate' => \&_server_roles,
            'editable' => \&_mod_enabled,
        ),
        new EBox::Types::Text(
            fieldName => 'password',
            printableName => __('Administrator password'),
            defaultValue => EBox::Samba::defaultAdministratorPassword(),
            'editable' => \&_mod_enabled,
        ),
        new EBox::Types::DomainName(
            'fieldName' => 'realm',
            'printableName' => __('Domain'),
            'defaultValue' => EBox::Samba::defaultRealm(),
            'editable' => \&_mod_enabled,
        ),
        new EBox::Types::DomainName(
            'fieldName' => 'workgroup',
            'printableName' => __('Workgroup'),
            'defaultValue' => EBox::Samba::defaultWorkgroup(),
            'editable' => \&_mod_enabled,
        ),
        new EBox::Types::Text(
            'fieldName' => 'netbiosName',
            'printableName' => __('NetBIOS computer name'),
            'defaultValue' => EBox::Samba::defaultNetbios(),
            'editable' => \&_mod_enabled,
        ),
        new EBox::Types::Text(
            'fieldName' => 'description',
            'printableName' => __('Description'),
            'defaultValue' => EBox::Samba::defaultDescription(),
            'editable' => \&_mod_enabled,
        ),
        #new EBox::Types::Boolean(
        #    'fieldName' => 'roaming',
        #    'printableName' => __('Enable roaming profiles'),
        #    'defaultValue' => 0,
        #    'editable' => 1,
        #),
        #new EBox::Types::Select(
        #    'fieldName' => 'drive',
        #    'printableName' => __('Drive letter'),
        #    'populate' => \&_drive_letters,
        #    'editable' => 1,
        #),
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

# Method: formSubmitted
#
# Overrides:
#
#       <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    my $row = $self->row();

    my $sambaRO = EBox::Global->getInstance(1)->modInstance('samba');
    my $modeRO = $sambaRO->get_string('GeneralSettings/mode');
    my $realmRO = $sambaRO->get_string('GeneralSettings/realm');
    my $workgroupRO = $sambaRO->get_string('GeneralSettings/workgroup');

    my $mode = $row->valueByName('mode');
    my $realm = $row->valueByName('realm');
    my $workgroup = $row->valueByName('workgroup');

    if (($realm ne $realmRO) or
        ($mode ne $modeRO) or
        ($workgroup ne $workgroupRO)) {
        $self->parentModule->set_bool('provisioned', 0);

        if (($realmRO ne '') or
            ($modeRO ne '') or
            ($workgroupRO ne '')) {
            $self->setMessage(__('Changing the server mode, ' .
            'the realm or the domain will cause a database reprovision, destroying the current one.'), 'warning');
        }
    }
}


# Populate the server role select
sub _server_roles
{
    my @roles;

    push (@roles, { value => 'dc', printableValue => __('Domain controller')});

    # FIXME
    # These roles are disabled until implemented, we should also use better names
    #push (@roles, { value => 'member', printableValue => __('Secondary domain controller')});
    #push (@roles, { value => 'standalone', printableValue => __('Standalone')});

    return \@roles;
}

#sub _drive_letters
#{
#    my @letters;
#
#    foreach my $letter ('H'..'Z') {
#        $letter .= ':';
#        push (@letters, { value => $letter, printableValue => $letter });
#    }
#
#    return \@letters;
#}

# Method: headTile
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
sub headTitle
{
    return undef;
}

1;
