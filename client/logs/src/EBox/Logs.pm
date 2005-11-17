# Copyright (C) 2005 Warp Netwoks S.L.

package EBox::Logs;

use strict;
use warnings;

use base qw(EBox::GConfModule);

use EBox::Global;
use EBox::Gettext;
use EBox::Loggerd;
use EBox::Config;
use EBox::Sudo qw( :all );
use EBox::Summary::Module;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::DBEngineFactory;
use POSIX qw(ceil);

use constant IMAGEPATH => EBox::Config::tmp . '/varimages';
use constant PIDPATH => EBox::Config::tmp . '/pids/';


#	EBox::GConfModule interface
#

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'logs',
					  domain => 'ebox-logs');

	bless($self, $class);
	return $self;
}

sub _regenConfig
{
	_stopService();
	root(EBox::Config::libexec . 'ebox-loggerd');
}

sub _stopService
{
	if (-f PIDPATH . "loggerd.pid") {
        	root(EBox::Config::libexec . 'ebox-kill-pid loggerd');
	}
}

sub cleanup 
{
	my $self = shift;
	$self->SUPER::revokeConfig();
}

sub rootCommands
{
	my $self = shift;

	my @cmd;
	push @cmd , (EBox::Config::libexec . 'ebox-kill-pid');
	push @cmd, (EBox::Config::libexec . 'ebox-loggerd');

	return @cmd;
}

# Method: menu 
#
#       Overrides EBox::Module method.
#   
#
sub menu
{
	my ($self, $root) = @_;
	my $item = new EBox::Menu::Item('url' => 'Logs/Index',
		'text' => __('Logs'),
		'order' => 6);
	$root->add($item);
}



#	Module API	
#

# Method: allLogDomains
#
#	This function fetchs all the log domains available throughout 
#	ebox.
#
# Returns:
#
#       An array ref containing  hash references holding:
#
#               logdomain - log domain name
#               text - log domain name i18n
#
sub allLogDomains
{
	my $self = shift;

	my $global = EBox::Global->getInstance();

	my @domains;
	my @mods = @{$global->modInstancesOfType('EBox::LogObserver')};
	foreach my $mod (@mods) {
		my $dm = $mod->logDomain();
		next unless defined($dm);
		push @domains, $dm;
	}
	return \@domains;
}

# Method: allLogHelpers
#
#	This function fetchs all the classes implemeting the interface
#	<EBox::LogHelper> and its associated fifo. 
#
# Returns:
#
#       An array ref containing  hash references holding:
#
#               fifo - path to log file
#               classname - class name of the <EBox::LogHelper> implementation
#
sub allLogHelpers
{
	my $self = shift;

	my $global = EBox::Global->getInstance();

	my @objects;
	my @mods = @{$global->modInstancesOfType('EBox::LogObserver')};
	foreach my $mod (@mods) {
		my $obj = $mod->logHelper();
		next unless defined($obj);
		push @objects, $obj;
	}
	return \@objects;
}

sub getLogsModules
{

	my $global = EBox::Global->getInstance();

	return $global->modInstancesOfType('EBox::LogObserver');
}

sub getAllTables
{
	my ($self) = @_;
	my $global = EBox::Global->getInstance();	
	my $tables;
	
	return $self->{tables} if ($self->{tables});
	
	foreach my $mod (@{getLogsModules()}) {
		my $comp = $mod->tableInfo();
		next unless ($comp);
		$tables->{$comp->{'index'}} = $comp;
	}

	$self->{tables} = $tables;
	return $tables;
}


sub  getTableInfo
{
	my ($self, $index) = @_;

	my $tables = $self->getAllTables();
	return $tables->{$index};
}

sub getLogDomains 
{
	my ($self) = @_;
	
	my $tables = $self->getAllTables();
	my %logdomains = map { $_ => $tables->{$_}->{'name'} } keys %{$tables};
	return \%logdomains;
}

# Private helper functions
sub _checkValidDate # (date)
{
	my $datestr = shift;

	my ($date, $time) = split (/ /, $datestr); 
	my ($year, $month, $day) = split (/-/, $date);
	my ($hour, $min, $sec) = split (/:/, $time);

	unless (defined($year) and defined($month) and defined($day)) {
		return undef;
	}
	return undef unless ($year =~ /\d\d\d\d/ );
	return undef unless ($month =~ /\d+/ and $month < 13 and $month > 0);
	return undef unless ($day =~ /\d+/ and $day < 32 and $day > 0);
	return undef unless ($hour =~ /\d+/ and $hour < 24 and $hour > -1);
	return undef unless ($min =~ /\d+/ and $min < 60 and $min > -1);
	return undef unless ($sec =~ /\d+/ and $sec < 60 and $sec > -1);

	return 1;
}

sub search {
	my ($self, $from, $to, $index, 
	    $pagesize, $page, $timecol, $filters) = @_;

	my $dbengine = EBox::DBEngineFactory::DBEngine();
	
	my $tables = $self->getAllTables();
	my $tableinfo = $tables->{$index};
	my $table = $tableinfo->{'tablename'};
	
	unless (defined $tableinfo) {
		   throw  EBox::Exceptions::External( __x(
		   'Table {$table} does not exist', 'table' => $table));
	}
	
	
	$self->_addTableName($table);
	if (_checkValidDate($from)) {
		$self->_addDateFilter($timecol, $from, '>');
	}
	if (_checkValidDate($to)) {
		$self->_addDateFilter($timecol, $to, '<');
	}
	if ($filters) {
		foreach my $field (keys %{$filters}) {
			unless (exists $tableinfo->{'titles'}->{$field}) {
			   throw  EBox::Exceptions::External( __x(
			   "Field {field} does not exist", 'field' => $field));
			}
			if ($field eq 'event') {
				$self->_addFilter($field, $filters->{$field});
			} else {
				$self->_addRegExp($field, $filters->{$field});
			}
		}
	}
	
	$self->_addSelect('COUNT(*)');
	my @count = @{$dbengine->query($self->_sqlStmnt())};
	my $tcount = $count[0]{'count'};
	my $tpages = ceil($tcount / $pagesize) - 1;
	
	if ($page < 0) { $page = 0; }
	if ($page > $tpages) { $page = $tpages; }
	
	my $offset = $page * $pagesize;
	$self->_addPager($offset, $pagesize);
	$self->_addSelect('*');
	my @ret = @{$dbengine->query($self->_sqlStmnt())};
	
	$self->{'sqlselect'} = undef;

	my $hashret = {
		'totalret' => $tcount,
		'arrayret' => \@ret
	};
	
	
	return $hashret;
}



sub totalRecords {
	my ($self, $table) = @_;
	my $dbengine = EBox::DBEngineFactory::DBEngine();

	my $sql = "SELECT COUNT(*) FROM $table";
	my @tarray = @{$dbengine->query($sql)};
	my $tcount = $tarray[0]{'count'};
	
	return $tcount;
}

sub _addRegExp
{
	my ($self, $field, $regexp) = @_;
	return unless (defined($field) and defined($regexp) 
			and length($regexp) > 0);
	$self->{'sqlselect'}->{'regexp'}->{$field} = $regexp;
}

sub _addFilter
{
	my ($self, $field, $filter) = @_;
	return unless (defined($field) and defined($filter) 
			and length($filter) > 0);
	$self->{'sqlselect'}->{'filter'}->{$field} = $filter;
}

sub _addDateFilter
{
	my ($self, $field, $date, $operator) = @_;
	return unless (defined($date) and defined($operator));
	$self->{'sqlselect'}->{'date'}->{$operator}->{'date'} = $date;
	$self->{'sqlselect'}->{'date'}->{$operator}->{'field'} = $field;
}

sub _addPager
{

	my ($self, $offset, $limit) = @_;
	$self->{'sqlselect'}->{'offset'} = $offset;
	$self->{'sqlselect'}->{'limit'} = $limit;
}

sub _addTableName
{
	my ($self, $table) = @_;
	$self->{'sqlselect'}->{'table'} = $table;
}

sub _addSelect
{
	my ($self, $select) = @_;
	$self->{'sqlselect'}->{'select'} = $select;
}

sub _sqlStmnt {
	my $self = shift;

	my @params;
	my $sql = $self->{'sqlselect'};
	my $stmt = "SELECT $sql->{'select'} FROM  $sql->{'table'} ";
	
	if ($sql->{'regexp'} or $sql->{'date'}) {
		$stmt .= 'WHERE ';
	}
	
	my $and = '';
	if ($sql->{'date'}) {
		foreach my $op (keys %{$sql->{'date'}}) {
			$stmt .= "$and $sql->{'date'}->{$op}->{'field'} $op ? ";
			$and = 'AND';
			push @params, $sql->{'date'}->{$op}->{'date'};
		}
	}
	
	if ($sql->{'regexp'}) {
		foreach my $field (keys %{$sql->{'regexp'}}) {
			$stmt .= "$and $field ~ ? ";
			$and = 'AND';
			push @params, $sql->{'regexp'}->{$field};
		}
	}
	if ($sql->{'filter'}) {
		foreach my $field (keys %{$sql->{'filter'}}) {
			$stmt .= "$and $field = ? ";
			$and = 'AND';
			push @params, $sql->{'filter'}->{$field};
		}
	}

	$stmt .= "OFFSET ? LIMIT ?";
	push @params, $sql->{'offset'}, $sql->{'limit'};

	return $stmt, @params;
}

1;
