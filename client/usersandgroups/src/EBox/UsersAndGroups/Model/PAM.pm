# Copyright (C) 2010 eBox Technologies S.L.
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

# Class: EBox::UsersAndGroups::Model::PAM
#

package EBox::UsersAndGroups::Model::PAM;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;
use File::Basename;

use strict;
use warnings;

use constant DEFAULT_SHELL => '/usr/sbin/nologin';

# Group: Public methods

# Constructor: new
#
#      Create a data form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: validateTypedRow
#
#   Check if mail services are disabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedParams, $allParams) = @_;

    # Check for incompatibility between PDC and PAM
    # only on slave servers

    my $mode = $self->parentModule()->mode();
    return unless $mode eq 'slave';

    return unless EBox::Global->modExists('samba');

    my $samba = EBox::Global->modInstance('samba');

    my $pam = exists $allParams->{enable_pam} ?
                  $allParams->{enable_pam}->value() :
                  $changedParams->{enable_pam}->value();

    my $pdc = $samba->pdc();

    if ($pam and $pdc) {
        throw EBox::Exceptions::External(__x('PAM can not be enabled on slave servers while acting as PDC. You can disable the PDC functionality at {ohref}Samba General Settings{chref}.',
ohref => q{<a href='/ebox/Samba/Composite/General/'>},
chref => q{</a>}));
    }
}


sub validShells
{
    my @shells;

    push (@shells, { value => DEFAULT_SHELL,
                    printableValue => basename(DEFAULT_SHELL) });

    open (my $FH, '<', '/etc/shells') or return \@shells;

    foreach my $line (<$FH>) {
        next if $line =~ /^#/;
        next if $line eq DEFAULT_SHELL;

        chomp ($line);
        push (@shells, { value => $line,
                         printableValue => basename($line) });
    }
    close ($FH);

    return \@shells;
}

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{

    my ($self) = @_;
    my $users = $self->parentModule();
    my @tableDesc = ();

    push (@tableDesc,
            new EBox::Types::Boolean(
                fieldName => 'enable_pam',
                printableName => __('Enable PAM'),
                defaultValue => 0,
                editable => 1,
                help => __('Make LDAP users have system account.')
                )
         );

    unless ( $users->mode eq 'slave' ) {
        push(@tableDesc,
                new EBox::Types::Select(
                    fieldName => 'login_shell',
                    printableName => __('Default login shell'),
                    disableCache => 1,
                    populate => \&validShells,
                    editable => 1,
                    help => __('This will apply only to new users from now on.')
                    )
            );
    }

    my $dataForm = {
        tableName           => 'PAM',
        printableTableName  => __('PAM settings'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
    };

    return $dataForm;
}

1;
