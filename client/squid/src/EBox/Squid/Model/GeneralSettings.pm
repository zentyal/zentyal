# Copyright (C) 2007 Warp Networks S.L.
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



package EBox::Squid::Model::GeneralSettings;
use base 'EBox::Model::DataForm';

use strict;
use warnings;

# eBox classes
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::IPAddr;
use EBox::Types::Union;
use EBox::Types::Port;
use EBox::Squid::Types::Policy;
use EBox::Sudo;

# eBox exceptions used 
use EBox::Exceptions::External;

sub new 
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}



sub _table
{
    my @tableDesc = 
        ( 
            new EBox::Types::Boolean(
                    fieldName => 'transparentProxy',
                    printableName => __('Transparent Proxy'),
                    editable => 1,
                    defaultValue   => 0,
                    help => _transparentHelp() 
                ),
            new EBox::Types::Port(
                    fieldName => 'port',
                    printableName => __('Port'),
                    editable => 1,
                    defaultValue   => 3128,
                 ),
            new EBox::Squid::Types::Policy(
               fieldName => 'globalPolicy',
               printableName => __('Default policy'),
               defaultValue => 'deny',
               help => _policyHelp(), 
               ),
        );

      my $dataForm = {
                      tableName          => 'GeneralSettings',
                      printableTableName => __('General Settings '),
                      modelDomain        => 'Squid',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,
                      messages           => {
                          update => __('Settings changed'),
                      },
                     };



    return $dataForm;
}


sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;

  if (exists $params_r->{port}) {
    $self->_checkPortAvailable($params_r->{port}->value());
  }

  if (exists $params_r->{transparentProxy} or 
      exists $params_r->{globalPolicy}) {

    $self->_checkPolicyWithTransProxy($params_r, $actual_r);
    $self->_checkNoAuthPolicy($params_r, $actual_r);
  }

}



sub _checkPortAvailable
{
  my ($self, $port) = @_;

  my $oldPort    = $self->portValue();
  if ($port == $oldPort) {
    # there isn't any change so we left tht things as they are
    return;
  }

  my $firewall = EBox::Global->modInstance('firewall');
  if (not $firewall->availablePort('tcp', $port )) {
      throw EBox::Exceptions::External(
              __x('{port} is already in use. Please choose another',
                  port => $port,
                 )
              );
  }
}


sub _checkPolicyWithTransProxy
{
  my ($self, $params_r, $actual_r) = @_;

  my $trans = exists $params_r->{transparentProxy} ?
                     $params_r->{transparentProxy}->value() :
                     $actual_r->{transparentProxy}->value() ;

  if (not $trans) {
    return;
  }


  my $pol = exists $params_r->{globalPolicy} ?
                     $params_r->{globalPolicy} :
                     $actual_r->{globalPolicy} ;

  if ($pol->usesAuth()) {
    throw EBox::Exceptions::External(
       __('Transparent proxy option is not compatible with authorization policy')
                                    );
  }

  my $objectPolicy = EBox::Global->modInstance('squid')->model('squid/ObjectPolicy');
  if ($objectPolicy->existsAuthObjects()) {
    throw EBox::Exceptions::External(
     __('Transparent proxy is incompatible with the authorization policy found in some objects')
                                    );
  }
}


sub _checkNoAuthPolicy
{
    my ($self, $params_r, $actual_r) = @_;
    my $pol = exists $params_r->{globalPolicy} ?
        $params_r->{globalPolicy} :
            $actual_r->{globalPolicy} ;

    if (not $pol->usesAuth()) {
        my $squid = EBox::Global->modInstance('squid');
        my $groupsPolicies = $squid->model('GlobalGroupPolicy')->groupsPolicies();
        if (@{ $groupsPolicies }) {
            throw EBox::Exceptions::External(
  __('You need to use authorization policies wuth global group policies')
                                            );
        }
    }
}


sub _policyHelp
{
    return __('<i>Filter</i> means that HTTP requests will go through the ' . 
              'content filter and they might be rejected if the content is ' .   
              'not considered valid.');
}

sub _transparentHelp
{
    return  __('Note that you cannot proxy HTTPS ' .
               'transparently. You will need to add ' .
               'a firewall rule if you enable this mode.');
               
 }

1;

