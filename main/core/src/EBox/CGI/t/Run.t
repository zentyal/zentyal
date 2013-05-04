# Copyright (C) 2013 Zentyal S.L.
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

use Test::More tests => 17;
use Test::Exception;

use EBox::Global::TestStub;
use EBox::Model::Manager;

use lib '../../..';

use_ok ('EBox::CGI::Run');

EBox::Global::TestStub::fake();

is EBox::CGI::Run::_cgiFromUrl('SysInfo/Backup'), 'EBox::SysInfo::CGI::Backup', 'cgi class from url';
is EBox::CGI::Run::_cgiFromUrl(), 'EBox::Dashboard::CGI::Index', 'cgi index class';

my ($model, $module, $type, $action) = EBox::CGI::Run::_parseModelUrl('SysInfo/View/Halt');
is $module, 'SysInfo', 'model from url (module)';
is $model, 'Halt', 'model from url (model)';
is $type, 'View', 'model from url (type)';
is $action, undef, 'model from url (undefined action)';

my $sysinfo = EBox::Global->modInstance('sysinfo');
isa_ok $sysinfo->model('Halt'), 'EBox::SysInfo::Model::Halt', 'model exists';
isa_ok EBox::CGI::Run::modelFromUrl('SysInfo/View/Halt'), 'EBox::SysInfo::Model::Halt', 'instance model from url';
isa_ok EBox::CGI::Run::_instanceModelCGI('SysInfo/View/Halt'), 'EBox::CGI::View::DataTable', 'instance model viewer';

($model, $module, $type, $action) = EBox::CGI::Run::_parseModelUrl('Logs/Composite/General/foobar');
is $module, 'Logs', 'composite from url (module)';
is $model, 'General', 'composite from url (model)';
is $type, 'Composite', 'composite from url (type)';
is $action, 'foobar', 'composite from url (action)';

my $logs = EBox::Global->modInstance('logs');
isa_ok $logs->composite('General'), 'EBox::Logs::Composite::General', 'composite exists';
isa_ok EBox::CGI::Run::modelFromUrl('Logs/Composite/General/foobar'), 'EBox::Logs::Composite::General', 'instance composite from url';
isa_ok EBox::CGI::Run::_instanceModelCGI('Logs/Composite/General/foobar'), 'EBox::CGI::Controller::Composite', 'instance composite controller';

1;
