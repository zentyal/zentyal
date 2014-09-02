// Copyright (C) 2013-2014 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('RemoteServices');

Zentyal.RemoteServices.setup = function() {
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
        $.ajax({
            url: href,
            // data:,
            dataType: 'json',
            success: function(response) {
                if (!response.success) {
                    $('#subscription_slots_list_error').html(response.msg).show();
                    return;
                }
                Zentyal.RemoteServices.showSubscriptionInfo(response.subscription);
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

Zentyal.RemoteServices.showFirstPage = function(subscription_info) {
    if (subscription_info) {
        Zentyal.RemoteServices.showSubscriptionInfo(subscription_info);
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

Zentyal.RemoteServices.showSubscriptionInfo = function(subscription) {
    $('.subscription_page').hide();

    $('#subscription_info_title').text(subscription.label);
    $('#info_server_name').text(subscription.server.name);
    $('#info_product_label').text(subscription.product_label);
    $('#info_subscription_begin').text(subscription.subscription_start);
    $('#info_subscription_end').text(subscription.subscription_end);

    $('#subscription_info_div').show();
};