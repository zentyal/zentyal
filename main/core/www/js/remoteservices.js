// Copyright (C) 2013-2014 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('RemoteServices');

Zentyal.RemoteServices.setup = function() {
//'subscription_form'
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
        var href = event.target.getAttribute('href');
        console.log('href ' + href);
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
};

Zentyal.RemoteServices.showForLevel = function(level) {
    console.log("DDD level " + level);
//    if (level == -1) {
        $('.subscription_page').hide();
        $('#no_subscription_div').show();
//     }

};

Zentyal.RemoteServices.listSubscriptionSlots = function(response) {
    var slots_list_body;

    $('.subscription_page').hide();    
    assert('subscriptions' in response);
    assert(response.subscriptions.length > 0);

    slots_list_body = $('#subscription_slots_list tbody');
    assert(slots_list_body.length > 0);
    slots_list_body.children().remove();
    slots_list_body.append(response.subscriptions);    

    assert(  $('#subscription_slots_div').length > 0);
    $('#subscription_slots_div').show();
};

Zentyal.RemoteServices.showSubscriptionInfo = function(subscription) {
    $('.subscription_page').hide();

    $('#subscription_info_title').text(subscription.label);


    $('#subscription_info_div').show();
};