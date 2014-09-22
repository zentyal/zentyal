// Copyright (C) 2013-2014 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('CrashReport');

Zentyal.CrashReport.discard = function () {
    $('.notification_container').hide();
    $.ajax({
        url: '/SysInfo/CrashReport',
        data: { action: 'discard' }
    });
};

Zentyal.CrashReport.ready_to_report = function() {
    $('.notification_container.warning').hide();
    $('.notification_container.note').show();
}

Zentyal.CrashReport.report = function () {
    $('.notification_container').hide();
    var email = $('#submit_crash_form input[name="email"]').val();
    $.ajax({
        url: '/SysInfo/CrashReport',
        data: { action: 'report', email: email },
        success: function() {
            Zentyal.CrashReport.discard();
        },
        error: function() {
            console.log('An error ocurred while trying to submit the report.');
        }
    });
};
