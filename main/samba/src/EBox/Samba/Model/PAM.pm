# Copyright (C) 2010-2014 Zentyal S.L.
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

# Class: EBox::Samba::Model::PAM
#

use strict;
use warnings;

package EBox::Samba::Model::PAM;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;
use File::Basename;

use constant DEFAULT_SHELL => '/usr/bin/bash';

# Group: Public methods

# Constructor: new
#
#      Create the PAM settings form
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

# Function: validShells
#
#      Retrieve the valid shells from /etc/shells
#
# Returns:
#
#      array ref - containing the valid shells in a hash ref with the
#                  following keys:
#
#                  value - String path to the shell
#                  printableValue - String the basename from the shell
#
sub validShells
{
    my %shells;

    my $defaultPrintableValue = basename(DEFAULT_SHELL);
    $shells{$defaultPrintableValue} =  { value => DEFAULT_SHELL,
                                         printableValue => $defaultPrintableValue
                                        };

    open (my $FH, '<', '/etc/shells') or return [ values %shells];

    foreach my $line (<$FH>) {
        next if $line =~ /^#/;
        next if $line eq DEFAULT_SHELL;

        chomp ($line);
        my $printableValue =  basename($line);
        $shells{$printableValue} = { value => $line,
                                     printableValue => $printableValue
                                    };
    }
    close ($FH);

    return [ values %shells];
}

# Method: _table
#
#       Overrides <EBox::Model::DataForm::_table to change its name
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

    push(@tableDesc,
         new EBox::Types::Select(
             fieldName => 'login_shell',
             printableName => __('Default login shell'),
             disableCache => 1,
             populate => \&validShells,
             editable => 1,
             defaultValue => DEFAULT_SHELL,
             help => __('This will apply only to new users from now on.')
            )
        );

    my $dataForm = {
        tableName           => 'PAM',
        printableTableName  => __('PAM settings'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Samba',
    };

    return $dataForm;
}

1;
