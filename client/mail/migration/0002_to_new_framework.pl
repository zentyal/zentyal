#!/usr/bin/perl
#
# This is a migration script to add a service and firewall rules
# for the eBox mail system
#
# For next releases we should be able to enable/disable some ports
# depening on if certain mail service is enabled or not
#
package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;

use EBox::MailVDomainsLdap;

use Error qw(:try);

sub runGConf
{
    my ($self) = @_;
    
    $self->_migrateSmtpAuth();
    $self->_migrateSmtpOptions();
    $self->_migrateRetrievalServices();
    $self->_migrateObjectPolicy();
    $self->_migrateExternalFilter();
    $self->_migrateDomains();
}

sub _migrateSmtpAuth 
{
    my ($self) = @_;

    $self->_migrateToForm(
                        'SMTPAuth',
                        smtptls => {
                                    keyGetter => 'get_bool',
                                    formElement => 'tls',
                                    adapter     => sub {
                                        my ($smtptls) = @_;
                                        return 0 if $smtptls eq 'no';
                                        return 1;
                                    },
                                   },
                        sasl    => {
                                    keyGetter => 'get_bool',
                                    formElement => 'sasl',
                                   },
                       );
 
}


sub _migrateSmtpOptions
{
    my ($self) = @_;

    $self->_migrateToForm(
                        'SMTPOptions',
                        relay => {
                                    keyGetter => 'get_string',
                                    formElement => 'smarthost',
                                   },
                        maxmsgsize    => {
                                          keyGetter => 'get_int',
                                          formElement => 'maxSize',
                                          adapter => sub {
                                              my ($size) = @_;
                                              if ($size == 0) {
                                                 return { unlimited => '' } ;
                                              }
                                              
                                              return { size => $size }
                                          },
                                         },
                       );
}


sub _migrateRetrievalServices 
{
    my ($self) = @_;


    $self->_migrateToForm(
                        'RetrievalServices',
                        pop => {
                                    keyGetter => 'get_bool',
                                    formElement => 'pop3',
                               },
                        imap => {
                                    keyGetter => 'get_bool',
                                    formElement => 'imap',
                               },

                       );


    # ssl value must be the higher of previous por and imap ssl option
    my $mail = $self->{gconfmodule};

    my $popssl = $mail->get_string('popssl');
    my $imapssl = $mail->get_string('imapssl');

    if ((not defined $popssl) and (not defined $imapssl)) {
        return;
    }

    my $ssl;
    if (($popssl eq 'required') or ($imapssl eq 'required')) {
        $ssl = 'required';
    } elsif (($popssl eq 'optional') or ($imapssl eq 'optional')) {
        $ssl = 'optional';
    } else {
        $ssl = 'no';
    }

    my $retrievalServices = $mail->model('RetrievalServices');
    my $row = $retrievalServices->row();
    $row->elementByName('ssl')->setValue($ssl);
    $row->store();

    $mail->unset('popssl');
    $mail->unset('imapssl');
}

sub _migrateObjectPolicy 
{
    my ($self) = @_;
    my $mail = $self->{gconfmodule};
    my $objectPolicy = $mail->model('ObjectPolicy');

    my @allowedObjects = @{ $mail->get_list('allowed') };
    
    foreach my $object (@allowedObjects) {
        $objectPolicy->addRow(
                              object => $object,
                              allow  => 1,
                             );
    }


    $mail->unset('allowed');

}

sub _migrateExternalFilter
{
    my ($self) = @_;
    $self->_migrateToForm(
                        'ExternalFilter',
                        external_filter_name => {
                                    keyGetter => 'get_string',
                                    formElement => 'externalFilter',
                               },
                        ipfilter => {
                                    keyGetter => 'get_string',
                                    formElement => 'ipfilter',
                               },
                        portfilter => {
                                    keyGetter => 'get_int',
                                    formElement => 'portfilter',
                               },
                        fwport => {
                                    keyGetter => 'get_int',
                                    formElement => 'fwport',
                               },
                       );
}



sub _migrateDomains
{
    my ($self) = @_;
    my $mail   = $self->{gconfmodule};

    my $vdomainsLdap = new EBox::MailVDomainsLdap;
    my @vdomainsInLdap = $vdomainsLdap->vdomains();

    my $vdomainsTable  = $mail->model('VDomains');

    foreach my $vdomain (@vdomainsInLdap) {
        $vdomainsTable->add(
                            vdomain => $vdomain,
                           );
        
    }
    
}

sub _migrateToForm
{
    my ($self, $formName, %migrate) = @_;
    my $mail = $self->{gconfmodule};
    my $form = $mail->model($formName);
    
    my $row = $form->row();

    my $changed = 0;
    while (my ($oldKey, $migrationSpec) = each %migrate) {
        my $keyGetter   = $migrationSpec->{keyGetter};
        my $formElement = $migrationSpec->{formElement};

        my $value = $mail->$keyGetter($oldKey);
        if (not defined $value) {
            next;
        }

        # zero may be the equivalent of undefined value for ints
        if ($keyGetter eq 'get_int') {
            if ($value == 0 and not $migrate{alowZero}) {
                next;
            }
        }


        if (exists $migrationSpec->{adapter}) {
            $value = $migrationSpec->{adapter}->($value);
        }


        my $element = $row->elementByName($formElement);
        $element->setValue($value);
        $changed = 1;
    }

    if ($changed) {
        $row->store();
    }


    # remove old keys
    foreach my $oldKey (keys %migrate) {
        $mail->unset($oldKey);
    }

}

EBox::init();

my $mailMod = EBox::Global->modInstance('mail');
my $migration =  __PACKAGE__->new( 
        'gconfmodule' => $mailMod,
        'version' => 2
        );
$migration->execute();
