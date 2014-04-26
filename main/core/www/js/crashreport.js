// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('CrashReport');

Zentyal.CrashReport.discard = function () {
    $('#notification_container').hide();
    $.ajax({
        url: '/SysInfo/CrashReport',
        data: { action: 'discard' }
    });
};

Zentyal.CrashReport.report = function () {
    $('#notification_container').hide();
    $.ajax({
        url: '/SysInfo/CrashReport',
        data: { action: 'report' },
        success: function() {
            Zentyal.CrashReport.discard();
        },
        error: function() {
            console.log('An error ocurred while trying to submit the report.');
        }
    });
};
