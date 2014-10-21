"use strict";

Zentyal.namespace('MailUserAddon');

Zentyal.MailUserAddon.accountChange = function(mail, ocEnabled) {
    var hasAccount = (mail !== '');
    $('#userMailNoAccountDiv').toggle(!hasAccount);
    $('#userMailWithAccountDiv').toggle(hasAccount);

    if (hasAccount) {
        // check if vdomain is managed
        var vdManaged = false;
        var accountVDomain = mail.split('@', 2)[1];
        var vdomains       = $('#userMail_data').data('vdomains');
        for (var i=0; i < vdomains.length; i++) {
            if (accountVDomain === vdomains[i]) {
                vdManaged = true;
                break;
            }
        }

        $('#userMailManaged').toggle(vdManaged);
        $('#userMailUnmanaged').toggle(!vdManaged);

        $('#userMailDelAccount_mail').val(mail);
        $('#userMailDelAccount_mailLabel').text(mail);
    } else {
        $('#userMailManaged').show();
        $('#userMailUnmanaged').hide();
    }

    // form mail field
    $('#user_attrs_mail').val(mail);

    // aliases
    $('#userMailCreateAlias_maildrop').val(mail);
    $('#userMailAliasTable .aliasRow').remove();
    $('#note_userMailAlias, #error_userMailAlias, #note_userMailSetMaildirQuota, #error_userMailSetMaildirQuota').html('').hide();

    // external accounts
    $('#userMailAddExternalAccount_localmail').val(mail);
    $('#userMailExternalAccountsTable').children().remove();
    $('#note_userMailExternalAccount, #error_userMailExternalAccount').html('').hide();

    // event for observer in other addons
    var user_email_change_event = jQuery.Event("user_email_change");
    user_email_change_event.mail = mail;
    user_email_change_event.ocEnabled = ocEnabled;
    $('.user_email_observer').trigger(user_email_change_event);
};

Zentyal.MailUserAddon.groupAccountChange = function(mail, mailManaged) {
    var group_email_change_event = jQuery.Event("group_email_change");
    group_email_change_event.mail = mail;
    group_email_change_event.mailManaged = mailManaged;
    group_email_change_event.mailChanged = true;

    $('.group_email_observer').trigger(group_email_change_event);
};

Zentyal.MailUserAddon.editFormWillRemoveAccount = function() {
    var mail_in_form, mail_in_addon;
    if ( $('#userMailUnmanaged').filter(':visible').length > 0) {
        // not managed mail account
        return false;
    } else if ($('#userMailNoAccountDiv').filter(':visible').length > 0) {
        // user has not mail account active
        return false;
    }

    mail_in_form = $('#user_attrs_mail').val().trim();
    mail_in_addon =  $('#userMailDelAccount_mailLabel').text().trim();
    return mail_in_form != mail_in_addon;
};