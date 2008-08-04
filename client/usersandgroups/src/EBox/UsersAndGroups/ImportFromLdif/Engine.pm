# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::UsersAndGroups::ImportFromLdif::Engine;

use strict;
use warnings;

use EBox;
use EBox::Global;

use Net::LDAP;
use Net::LDAP::LDIF;



my %classesToProcess;
my %classStartup;
my $maxPriority;
my $minPriority;

sub importLdif
{
    my ($ldifPath, @extraOptions) = @_;
    
    _loadClientClasses();

    my @entries = @{ _entries($ldifPath)  };

    foreach my $priority ($minPriority .. $maxPriority) {
        @entries = map {
            _processEntry($_, priority => $priority, @extraOptions);
        } @entries;
    }


}


sub _entries
{
    my ($ldifPath) = @_;

    my $ldif = Net::LDAP::LDIF->new($ldifPath, 'r', onerror => 'die');

    my @entries;

    while (not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        push @entries, $entry;
    }

    return \@entries;
}

sub _loadClientClasses
{
    $minPriority = -1000;
    $maxPriority = $minPriority;

    my $global = EBox::Global->getInstance();

    my @userMods = @{  $global->modInstancesOfType('EBox::LdapModule')  };
    foreach my $mod (@userMods) {
        # we only import data into configured modules
        $mod->configured() or
            next;

        my $importClass = (ref $mod) . '::ImportFromLdif';
        eval "use $importClass";
        if ($@) {
            EBox::error("Error loading import users from ldif class $importClass: $@");
            EBox::error("Skipping $importClass");
            next;
        }


        my @modClassesToProcess = @{ $importClass->classesToProcess() };
        foreach my $ldifClassSpec (@modClassesToProcess) {
            my $ldifClass;
            my $priority = 1;

            if (ref $ldifClassSpec) {
                $ldifClass = $ldifClassSpec->{class};
                defined $ldifClass or
                    die "Not class specified in $importClass::classesToProcess()";
                if (exists $ldifClassSpec->{priority}) {
                    $priority  = $ldifClassSpec->{priority} 
                }
            }
            else {
                $ldifClass = $ldifClassSpec;
            }

            

            my $importClassElement =  {
                                       importClass => $importClass,
                                       priority    => $priority,
                                                      };

            if (not exists  $classesToProcess{$ldifClass}) {
                 $classesToProcess{$ldifClass} = [];
            }
            push @{ $classesToProcess{$ldifClass} }, $importClassElement; 

            if (not exists $classStartup{$ldifClass}) {
                $classStartup{$ldifClass} = [];
            }
            push @{ $classStartup{$ldifClass} }, $importClassElement;


            if ($priority > $maxPriority) {
                $maxPriority = $priority;
            }
            elsif ($priority < $minPriority) {
                $minPriority = $priority;
            }
        }
    }

}




sub _processEntry
{
    my ($entry, %params) = @_;

    
    my @objectClasses = $entry->get_value('objectClass');
    my $priority      = delete $params{priority};
    
    my $entryNotFullyProcessed = 0;

    foreach my $class (@objectClasses) {
        if (exists $classesToProcess{$class}) {
            _startupClass($class, %params);

            foreach my $package_r (@{  $classesToProcess{$class}  }) {
                my $classPriority = $package_r->{priority};

                if ($classPriority < $priority) {
                    # already processed, next object class
                next;
                }
                elsif ($classPriority > $priority) {
                    # class of lower priority, skipping and left it for latter
                    $entryNotFullyProcessed = 1;
                    next;
                }

                my $package = $package_r->{importClass};
                my $subName = 'process' . ucfirst $class;
                $package->$subName($entry, %params);
            }

        }
    }


    return $entryNotFullyProcessed ? ($entry) : ();
}



sub _startupClass
{
    my ($oclass, @params) = @_;

    return if not exists $classStartup{$oclass};

    # sort by priority
    my @importClasses = sort {  
        $a->{priority} <=> $b->{priority}
    } @{ $classStartup{$oclass} };


    foreach my $importClass_r (@importClasses) {
        my $importClass = $importClass_r->{importClass};
        my $startupName = 'startup' . ucfirst $oclass;
        if ($importClass->can($startupName)) {
            $importClass->$startupName(@params);
        }
    }

    delete $classStartup{$oclass};
}

1;

