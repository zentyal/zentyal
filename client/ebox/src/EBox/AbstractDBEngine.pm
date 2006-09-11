# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

# Class: EBox::AbstractEngine
#
#	This class exposes the interface to be implemented by a new database backend
#	module.
#	
package EBox::AbstractDBEngine;

use strict;
use warnings;

use DBI;
use EBox::Exceptions::NotImplemented;

sub new {
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: _dbname
#
#  This function returns the database name.
#
sub _dbname {
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: _dbuser
#
#  This function returns the database user.
#
sub _dbuser {
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: _dbpass
#
#  This function returns the database user password.
#
sub _dbpass {
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: _connect
#
#	This function do the necessary operations to establish a connection with the
#	database.
#
sub _connect  {
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: _disconnect
#
#	This function do the necessary operations to get disconnected from the
#	database.
#
sub _disconnect {
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: insert
#
#	This function do the necessary operations to create and establish an insert
#	operation to a table form the database.
#
# Parameters:
#   $table: The table name to insert data.
#   $values: A hash ref with database fields name and values pairs that do you
#   want to insert to.the table name passed as parameter too.
#
sub insert {	
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: query
#
#	This function do the necessary operations to create and establish a query
#	operation to a table form the database.
#
sub query {
	throw EBox::Exceptions::NotImplemented();		  
}

# Method: dumpDB
#
#         Makes a dump of the database in the specified file
sub  dumpDB
{
  throw EBox::Exceptions::NotImplemented();		  
}

# Method: restoreDB
#
# restore a database from a dump file.
# 
sub restoreDB
{
  throw EBox::Exceptions::NotImplemented(); 
}  


1;
