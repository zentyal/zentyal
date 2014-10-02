// Copyright (C) 2013-2014 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('RemoteServices');

Zentyal.RemoteServices.setupSubscriptionPage = function() {
// subscription_form
    Zentyal.Form.setupAjaxSubmit('#subscription_form', {
        noteDiv: '#subscription_slots_list_note', // bz it will made visible in success
        errorDiv: '#subscription_form_error',
        submitButton: '#subscription_form_submit',
        success : function(response) {
            if (!response.success) {
                return;
            }
            Zentyal.RemoteServices.listSubscriptionSlots(response);
        }
    });


// select slot
    $('#subscription_slots_list').on('click', 'a', function(event) {
        event.preventDefault();
        $('#subscription_slots_list_note, #subscription_slots_list_error').hide();
        var href = event.target.getAttribute('href');
        // The form is the sibling
        var selectForm = $( $( event.target ).siblings('form')[0] );
        $.ajax({
            type: "POST",
            url: href,
            data: selectForm.serialize(),
            dataType: 'json',
            success: function(response) {
                if (!response.success) {
                    $('#subscription_slots_list_error').html(response.msg).show();
                    return;
                }
                Zentyal.refreshSaveChangesButton();
                Zentyal.RemoteServices.showSubscriptionInfo(response.subscription, response.username);
                $('#subscription_info_note').html(response.msg).show();
            },
            error: function(jqXHR) {
                $('#subscription_slots_list_error').html(jqXHR.responseText).show();
            }
        });
    });

// unsubscription_form
    Zentyal.Form.setupAjaxSubmit('#unsubscription_form', {
        noteDiv: '#subscription_form_info', // bz it will made visible in success
        errorDiv: '#unsubscription_form_error',
        submitButton: '#sunubscription_form_submit',
        success : function(response) {
            if (!response.success) {
                return;
            }
            Zentyal.refreshSaveChangesButton();
            Zentyal.RemoteServices.showFirstPage(false);
        }
    });
};

Zentyal.RemoteServices.showFirstPage = function(subscription_info, username) {
    if (subscription_info) {
        Zentyal.RemoteServices.showSubscriptionInfo(subscription_info, username);
    } else {
        $('.subscription_page').hide();
        $('#no_subscription_div').show();
     }
};

Zentyal.RemoteServices.listSubscriptionSlots = function(response) {
    var slots_list_body;

    $('.subscription_page').hide();    

    slots_list_body = $('#subscription_slots_list tbody');
    slots_list_body.children().remove();
    slots_list_body.append(response.subscriptions);    

    $('#subscription_slots_div').show();
};

Zentyal.RemoteServices.showSubscriptionInfo = function(subscription, username) {
    $('.subscription_page').hide();
    
    $('#subscription_info_title').text(subscription.label);
    $('#info_username').text(username);
    $('#info_server_name').text(subscription.server.name);
    $('#info_product_label').text(subscription.product_label);
    $('#info_subscription_begin').text(subscription.subscription_start);
    if (subscription.subscription_end) {
        $('#info_subscription_end').text(subscription.subscription_end);
        $('#row_info_subscription_end').show();
    } else {
        $('#row_info_subscription_end').hide();
    }
    if (subscription.messages) {
        $('#info_messages').text(subscription.messages);
        $('#row_info_messages').show();
    } else {
        $('#row_info_messages').hide();
    }

    $('#subscription_info_div').show();
};

// backup page
Zentyal.RemoteServices.setupBackupPage = function() {
    var tbody = $('#list_backups_tbody');
    tbody.on('click', '.btn-download', function(event) {
        var uuid, 
            name, 
            url;
        event.preventDefault();
        uuid =  event.target.getAttribute('data-uuid');
        name =  event.target.getAttribute('data-name');
        url = '/RemoteServices/Backup/DownloadRemoteBackup';
        url += '?uuid=' + uuid;
        url += '&name=' + name;
        window.location.replace(url);
    });

    tbody.on('click', '.btn-restore', function(event) {
        var uuid, 
            data,
            title,
            url;
        event.preventDefault();
        uuid  =  event.target.getAttribute('data-uuid');
        title = tbody.attr('data-restore-title');
        url = '/RemoteServices/Backup/Confirm';
        data = 'uuid=' + uuid;
        data += '&action=restore&popup=1';
        Zentyal.Dialog.showURL(url,  {title: title, data: data});
    });

    tbody.on('click', '.btn-delete', function(event) {
        var uuid, 
            name,
            data,
            title,
            url;
        event.preventDefault();
        uuid  =  event.target.getAttribute('data-uuid');
        title = tbody.attr('data-delete-title');
        url = '/RemoteServices/Backup/Confirm';
        data = 'uuid=' + uuid;
        data += '&action=delete&popup=1';
        Zentyal.Dialog.showURL(url,  {title: title, data: data});
    });
};


Zentyal.RemoteServices.setupCommunityRegisterPage = function(wizard) {
    var div_register_first = $('#div_register_first_time');
    var div_register_additional = $('#div_register_additional');
    
    var go_to_register_first = function() {
        $('#register_first_time_info, #register_first_time_error, #register_additional_info, #register_additional_error').html('').hide();
        div_register_first.show();
        div_register_additional.hide();
    };

    var go_to_register_additional = function() {
        $('#register_first_time_info, #register_first_time_error, #register_additional_info, #register_additional_error').html('').hide();
        div_register_first.hide();
        div_register_additional.show();
    };

    $('#switch_to_register_first').on('click', function(event) {
        event.preventDefault();
        go_to_register_first();
    });

    $('#switch_to_register_additional').on('click', function(event) {
        event.preventDefault();
        go_to_register_additional();
    });

    var submitButtonSelector = '#register_first_submit';
    var submitAddButtonSelector = '#register_additional_submit';
    var currentOnClick = "";
    var next;
    if (wizard) {
        submitButtonSelector = '#wizard-next2';
        submitAddButtonSelector = '#wizard-next2';
        var next = $(submitButtonSelector);
        // Remove current onclick and use ours
        currentOnClick = next.attr('onclick');
        next.attr('onclick', '').off('click');
        next.on('click.remoteservices', function(event) {
            event.preventDefault();
            var form = $('#register_first_time_form');
            if (div_register_additional.is(':visible')) {
                form = $('#register_additional_form');
            }
            form.submit();
        });
    }

    Zentyal.Form.setupAjaxSubmit('#register_first_time_form', {
        noteDiv: '#register_first_time_note',
        errorDiv: '#register_first_time_error',
        submitButton: submitButtonSelector,
        success : function(response) {
            if (!response.success) {
                if (response.duplicate) {
                    go_to_register_additional();
                    $('#register_additional_username').val(response.username);
                    $('#register_additional_error').text(response.error).show();
                    $('#register_additional_password').focus();
                }
                return;
            }
            if (wizard) {
                // Restore previous onclick
                next.off('click.remoteservices');
                next.attr('onclick', currentOnClick).on('click');
                if (response.trackURI) {
                    var ifr = $(document.createElement('iframe'));
                    ifr.width(1);
                    ifr.height(1);
                    ifr.attr('src', response.trackURI);
                    ifr.appendTo(document.body);
                    ifr.load( function() {
                        setTimeout( function() {
                            Zentyal.Wizard.submitPage('/Wizard?page=RemoteServices/Wizard/Subscription');
                        }, 1000);
                    });
                } else {
                    // Load next page
                    Zentyal.Wizard.submitPage('/Wizard?page=RemoteServices/Wizard/Subscription');
                }
            } else {
                var rurl = '/RemoteServices/Backup/Index?first=true';
                if (response.newsletter) {
                    rurl += '&nl=on';
                }
                window.location.replace(rurl);
            }
        }
    });

    Zentyal.Form.setupAjaxSubmit('#register_additional_form', {
        noteDiv: '#register_additional_note',
        errorDiv: '#register_additional_error',
        submitButton: submitAddButtonSelector,
        success : function(response) {
            if (!response.success) {
                return;
            }
            if (wizard) {
                // Load next page
                Zentyal.Wizard.submitPage('/Wizard?page=RemoteServices/Wizard/Subscription');
            } else {
                window.location.replace('/RemoteServices/Backup/Index');
            }
        }
    });
};

