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

use constant MIN_PRIORITY => -1;

my %classesToProcess;
my $maxPriority;


sub importLdif
{
    my ($ldifPath, @extraOptions) = @_;
    
    _loadClientClasses();


    my @entries = @{ _entries($ldifPath)  };

    foreach my $priority (MIN_PRIORITY .. $maxPriority) {
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
    $maxPriority = MIN_PRIORITY;

    my $global = EBox::Global->getInstance();

    my @userMods = @{  $global->modInstancesOfType('EBox::LdapModule')  };
    foreach my $mod (@userMods) {
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
	    my $priority;

	    if (ref $ldifClassSpec) {
		$ldifClass = $ldifClassSpec->{class};
		$priority  = $ldifClassSpec->{priority};
	    }
	    else {
		$ldifClass = $ldifClassSpec;
		$priority  = 1;
	    }


	    my $importClassElement =  {
                                       importClass => $importClass,
				       priority    => $priority,
						      };

	    if (not exists  $classesToProcess{$ldifClass}) {
		 $classesToProcess{$ldifClass} = [ $importClassElement ];
	    }
	    else {
		push @{  $classesToProcess{$ldifClass} }, $importClassElement; 
	    }

	    if ($priority > $maxPriority) {
		$maxPriority = $priority;
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



1;

