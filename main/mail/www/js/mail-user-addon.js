"use strict";

Zentyal.namespace('MailUserAddon');

Zentyal.MailUserAddon.accountChange = function(mail) {
    var hasAccount = (mail !== '');
    $('#userMailNoAccountDiv').toggle(!hasAccount);
    $('#userMailWithAccountDiv').toggle(hasAccount);

    if (hasAccount) {
        $('#userMailDelAccount_mail').val(mail);
        $('#userMailDelAccount_mailLabel').text(mail);
    }

    // aliases
    $('#userMailCreateAlias_maildrop').val(mail);
    $('#userMailAliasTable .aliasRow').remove();
    $('#note_userMailAlias, #error_userMailAlias, #note_userMailSetMaildirQuota, #error_userMailSetMaildirQuota').html('').hide();

    // external accounts
    $('#userMailAddExternalAccount_localmail').val(mail);
    $('#userMailExternalAccountsTable').children().remove();
    $('#note_userMailExternalAccount, #error_userMailExternalAccount').html('').hide();

    // set mail form element
    $('#user_attrs_mail').val(mail);
};