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
};

Zentyal.RemoteServices.showForLevel = function(level) {
    console.log("DDD level " + level);
//    if (level == -1) {
        $('#subscription_slots_div').hide();
        $('#no_subscription_div').show();
//     }

};

Zentyal.RemoteServices.listSubscriptionSlots = function(response) {
    var slots_list;

    $('#no_subscription_div').hide();    
    assert('subscriptions' in response);
    assert(response.subscriptions.length > 0);

    slots_list = $('#subscription_slots_list');
    assert(slots_list.length > 0);
    slots_list.children().remove();
    $.each(response.subscriptions, function(index, subscription) {
        slots_list.append(subscription);
    });
    

    assert(  $('#subscription_slots_div').length > 0);
    $('#subscription_slots_div').show();
};