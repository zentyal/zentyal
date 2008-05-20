#!/usr/bin/perl

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

use strict;
use warnings;


use Test::More qw(no_plan);
use Test::Exception;

use EBox::TestStubs;

use Data::Dumper;

use constant DEBUG => 1;
use constant LDIF_FILE => 'testdata/test.ldif';

use lib '../../src';

use EBox::UsersAndGroups::ImportFromLdif::Engine;


my %users;
my %groups;


sub fakeModLdapsUserBase
{
	my $self = shift;

	my $global = EBox::Global->modInstance('global');
	my @names = @{$global->modNames};
	
	my @modules;
	foreach my $name (@names) {
		my $mod = EBox::Global->modInstance($name);
		if ($mod->isa('EBox::LdapModule')) {
			push (@modules, $mod->_ldapModImplementation);
		}
	}
	
	return \@modules;

}

sub fakeAddUser 
{
    my ($self, $user_r, $system, %params) = @_;
    $system = $system ? 1 : 0;

    print "addUser(" . (Dumper $user_r) . ", $system, " . (join ', ', %params) . ")\n" if DEBUG;

    my $username = $user_r->{user};
    my %userData = (
		%{ $user_r  },
		system => $system,
		%params,

	       );
    
    
    $users{$username} = \%userData;

}


sub fakeAddGroup
{
    my ($self, $group, $comment, $system, %params) = @_;
    $system = $system ? 1 : 0;
    $comment or $comment = '';

    print "addGroup($group, $comment, $system, " . (join ', ', %params) . ")\n" if DEBUG;

    my %groupData = (
		     group => $group,
		     comment => $comment,
		     system => $system,
		     members => [],
		     %params,
		    );

    
    $groups{$group} = \%groupData;
}

sub fakeAddUserToGroup # (user, group)
{
    my ($self, $user, $group) = @_;
    print "addUserToGroup($user, $group)\n" if DEBUG;

    exists $users{$user} or die "inexistent user $user";
    exists $groups{$group} or die "inexistent group $group";

    push @{ $groups{$group}->{members}  }, $user;
}

EBox::TestStubs::activateTestStubs();
EBox::TestStubs::fakeEBoxModule(
				name => 'users',
				package => 'EBox::UsersAndGroups',
				subs => [
					 _modsLdapUserBase => \&fakeModLdapsUserBase,
					 addUser => \&fakeAddUser,
					 userExists => sub {
					     my ($self, $username) = @_;
					     return exists $users{$username}
					 },
					 addGroup => \&fakeAddGroup,
					 groupExists => sub {
					     my ($self, $groupname) = @_;
					     return exists $groups{$groupname}
					 },
					 addUserToGroup => \&fakeAddUserToGroup,
					 lastUid => sub { return 100 },
					 lastGid => sub { return 100 },
					],
				isa => ['EBox::LdapModule'],

			       );



lives_ok {
    EBox::UsersAndGroups::ImportFromLdif::Engine::importLdif(LDIF_FILE);
} 'Adding users and groups from LDIF file';


1;
