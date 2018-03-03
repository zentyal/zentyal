// Copyright (C) 2013 Zentyal Technologies S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('OpenChange');

Zentyal.OpenChange.updateAjaxValue = function(url, containerId) {
    var escapedId = Zentyal.escapeSelector(containerId);
    $.ajax({
         url: url,
         datatype: 'json',
         timeout: 3000,
         success: function (data, textStatus) {
            var container = $('#' + escapedId);
            //container.removeClass().addClass('summary_value summary_' + response.type);
            container.html(data.value);
            $( ".select-server-button" ).click( function() {
                var $this = $(this);
                var name = $this.data('server');
                $("#server").val(name);
                $("#server").change();
            });
         },
         error: function ( jqXHR, textStatus, errorThrown ) {
            var container = $('#' + escapedId);
            var html = '<li><span class="red">' + errorThrown + '</li>';
            container.html(html);
         }
    });
};

Zentyal.OpenChange.setMailboxes = function (url, containerId) {
    var escapedContainerId = Zentyal.escapeSelector(containerId);
    $.ajax( {
        method: "GET",
        url: url,
        datatype : 'html',
        success: function(data) {
            $('#' + escapedContainerId).html(data);
            Zentyal.OpenChange.initTable('migration-table');
        },
        error: function(jqXHR, textStatus, errorThrown) {
            Zentyal.OpenChange.migrationMessage(errorThrown, 'error');
        }
    });
};

/* Function to make select all works */
Zentyal.OpenChange.initTable = function (tableClass) {
    // This is more-or-less copied from z.js
    var table = $('.' + tableClass);
    if (!table) return;

    var update_select_all = function(table) {
        var checked = table.find('.table-row :checked').length;
        var unchecked = table.find('.table-row :checkbox:not(:checked)').length;
        table.find(':checkbox[name="select_all"]').prop('checked', checked > 0 && unchecked == 0);
        Zentyal.OpenChange.changeUsers(checked);
    };
    table.find(':checkbox[name="select_all"]').click(function (e) {
        var checked = $(this).prop('checked');
        $(this).parents('table').find('.table-row :checkbox').prop('checked', checked);
        $(this).parents('table').find('.table-row').toggleClass('row-selected', checked);
        update_select_all($(this).parents('table'));
    });

    // Select on checkbox click
    table.find('.table-row :checkbox').click(function (e) {
        var row = $($(this).parents('.table-row')[0]);
        row.toggleClass('row-selected');
        var selected = row.hasClass('row-selected');
        var check = $(this);
        check.prop("checked", selected);
        update_select_all($(this).parents('table'));
    });

};

/* Function to change migration details based on mailboxes table */
Zentyal.OpenChange.changeUsers = function(nChecked) {
    var estBtn = $('#estimate-migration');
    if (nChecked == 0) {
        estBtn.prop('disabled', true);
        $('#migration-details').hide();
        $('#migration-no-mailboxes').fadeIn();
    } else {
        $('#migration-details').find('#mailboxes .info-value').html(nChecked);
        estBtn.prop('disabled', false);
        estBtn.fadeIn();
        $('#start-migration').hide();
        $('#migration-no-mailboxes').hide();
        $('#migration-details').fadeIn();
    }
};

/* Function to launch the estimation of the migration time */
Zentyal.OpenChange.estimateMigration = function(params) {
    $(params.estimateButton).hide();
    $(params.loadingId).show();
    // Set the form params
    var usersToMigrate = $.map($(params.tableClass).find('.table-row :checked'), function(el) { return el.value; });
    $.ajax({
        type : "POST",
        url  : '/OpenChange/Migration/Estimate',
        dataType : 'json',
        data : JSON.stringify({ users : usersToMigrate }),
        contentType : 'json',
        success : function (data) {
            if ('error' in data) {
                Zentyal.OpenChange.migrationMessage(data.error, 'error');
                $(params.estimateButton).fadeIn();
            } else {
                var intervalId = setInterval( function() {
                    Zentyal.OpenChange.estimateUpdate({ loadingId : params.loadingId,
                                                        startBtnId : params.startBtnId });
                    }, 2000);
                Zentyal.OpenChange.estimateIntervalId = intervalId;
            }
        }
    });
    //.done(function() {
    //    $(params.loadingId).hide();
    //});
};

// Format the bytes in readable format within the given id
// using this format: number <i>metric</i>
Zentyal.OpenChange.formatProgressBytes = function(id, bytes) {
    var container = $(id);
    if (! container) return;
    var bytStr = getBytes(bytes);
    var parts = bytStr.split(" ");
    container.html(parts[0] + ' <i>' + parts[1] + '</i>');
};

// Format the time diff in readable format within the given id
// using this format: number_1 <i>metric_1</i> number_2 <i>metric_2</i>
Zentyal.OpenChange.formatProgressTimeDiff = function(id, s) {
    var container = $(id);
    if (! container) return;
    var timeDiffStr = s.toTimeDiffString();
    var parts = $.trim(timeDiffStr).split(" ");
    var resultStr = "";
    for (var i=0; i < parts.length; i+=2) {
        resultStr += parts[i] + ' <i>' + parts[i+1] + '</i> ';
    }
    container.html(resultStr);
};


// Call to know the progress of the mailbox migration
Zentyal.OpenChange.progress = function(params) {
    $.ajax({
        type : "GET",
        url  : params.url,
        dataType : 'json',
        success : function (data) {
            if ('error' in data) {
                Zentyal.OpenChange.migrationMessage(data.error, 'error');
                return;
            }
            // Expected data is explained in MailboxProgress CGI
            if ('totals' in data) {
                for (var total_key in params.totals) {
                    if (total_key in data.totals) {
                        switch(params.totals[total_key]) {
                        case 'bytes':
                            Zentyal.OpenChange.formatProgressBytes('#' + total_key,
                                                                   data.totals[total_key]);
                            break;
                        case 'timediff':
                            Zentyal.OpenChange.formatProgressTimeDiff('#' + total_key,
                                                                      data.totals[total_key]);
                            break;
                        default: // this take cares also of the int case
                            $('#' + total_key).html(data.totals[total_key]);
                        }
                    }
                }
            }
            if ('users' in data) {
                data.users.forEach(function(user) {
                    for (var prop_user_key in params.users) {
                        if (!user[prop_user_key]) continue;
                        var prop_id = '#' + user.username + '_' + prop_user_key;
                        var prop = $(prop_id);
                        if (prop) {
                            switch(params.users[prop_user_key]) {
                            case 'percentage':
                                prop.html(user[prop_user_key] + '<i>%</i>');
                                break;
                            case 'int':
                            default:
                                prop.html(user[prop_user_key]);
                            }
                        }
                    }
                    // Status is a different thing...
                    Zentyal.OpenChange.setProgressStatus(user);
                });
            }
        }
    });
};

// Discard migration for this user
Zentyal.OpenChange.discardMailbox = function(url, username) {
    $.ajax({
        type : "POST",
        url  : url,
        dataType : 'json',
        data : { username : username },
        success : function(data) {
            if ('error' in data) {
                Zentyal.OpenChange.migrationMessage(data.error, 'error');
                return;
            }
            if ('warning' in data) {
                Zentyal.OpenChange.migrationMessage(data.warn, 'warning');
                return;
            }
            if ('success' in data) {
                Zentyal.OpenChange.migrationMessage(data.success, 'note');
                Zentyal.OpenChange.setProgressStatus(
                    { username : username,
                      status : { state : 'cancelled',
                                 printable_value : data.printable_value }});
            }
        }});
};      

// Activate mailbox after its data has been copied
Zentyal.OpenChange.activateMailbox = function(url, username) {
    $.ajax({
        type : "POST",
        url  : url,
        dataType : 'json',
        data : { username : username },
        success : function(data) {
            if ('error' in data) {
                Zentyal.OpenChange.migrationMessage(data.error, 'error');
                return;
            }
            if ('warning' in data) {
                Zentyal.OpenChange.migrationMessage(data.warn, 'warning');
                return;
            }
            if ('success' in data) {
                Zentyal.OpenChange.migrationMessage(data.success, 'note');
                Zentyal.OpenChange.setProgressStatus(
                    { username : username,
                      status : { state : 'migrated',
                                 printable_value : data.printable_value }});
            }
        }});
};      

// Set progress status for a given user
// Named parameters
Zentyal.OpenChange.setProgressStatus = function(user) {
    var status = $('#' + user.username + '_status');
    var discardBtn = $('#' + user.username + '_discard');
    var activateBtn = $('#' + user.username + '_activate');
    if (status) {
        if (user.status.done && user.status.done > 0) {
            status.find('.done-bar').width(user.status.done + '%');
        }
        if (user.status.error && user.status.error > 0) {
            status.find('.error-bar').width(user.status.error + '%');
        }
        switch(user.status.state) {
        case 'ongoing':
            status.find('.done-value').html(
                '<strong>' + user.status.done + '</strong>' + '%'
            );
            status.removeClass().addClass('status');
            discardBtn.prop('disabled', false).show();
            activateBtn.prop('disabled', true).hide();
            break;
        case 'migrated':
        case 'cancelled':
            status.find('.done-value').html(user.status.printable_value);
            status.removeClass().addClass('status stopped');
            if (user.status.state == 'migrated') {
                discardBtn.prop('disabled', true).hide();
                activateBtn.prop('disabled', true).show();
            } else {
                discardBtn.prop('disabled', true).show();
                activateBtn.prop('disabled', true).hide();
            }
            Zentyal.OpenChange.updateDone();
            break;
        case 'copied':
            status.find('.done-value').html(
                '<strong>' + user.status.done + '</strong>' + '%'
            );
            status.removeClass().addClass('status stopped');
            discardBtn.prop('disabled', false).show();
            activateBtn.prop('disabled', false).show();
            break;
        case 'waiting':
            status.find('.done-value').html(user.status.printable_value);
            status.removeClass().addClass('status');
            discardBtn.prop('disabled', false).show();
            activateBtn.prop('disabled', true).hide();
            break;
        }
    }
};

// Check to show DONE button once every user has been migrated or cancelled
Zentyal.OpenChange.updateDone = function() {
    var nStopped = $('.migration-table').find('.status.stopped').length;
    var nTotal   = $('.migration-table').find('.status').length;
    if (nStopped == nTotal) {
        $('#done_btn').fadeIn();
    } else {
        $('#done_btn').fadeOut();
    }
};

// Show migration errors in a common way
Zentyal.OpenChange.migrationMessage = function(msg, level) {
    $('#messages').append('<div class="' + level + '">' + msg + '</div>').fadeIn();
    $('.' + level).delay(10 * 1000).fadeOut('slow', function() { $(this).remove(); });
};

Zentyal.OpenChange.estimateUpdate = function(params) {
    $.ajax({
        type: "POST",
        url: "/OpenChange/Migration/Estimate",
        dataType: "json",
        data: JSON.stringify({ }),
        contentType: "json",
        success: function (data) {
            var migration = $( "#migration-details" );
            for (var property in data.result) {
                var formatted_val;
                switch(data.result[property].type) {
                case 'bytes':
                    formatted_val = getBytes(data.result[property].value);
                    break;
                case 'timediff':
                    formatted_val = data.result[property].value.toTimeDiffString();
                    break;
                default: // also covers int case
                    formatted_val = data.result[property].value;
                }
                migration.find('#' + property + ' .info-value').html(formatted_val);
            }
            if (data.state == 'done') {
                $(params.loadingId).hide();
                $(params.startBtnId).fadeIn();
                clearInterval(Zentyal.OpenChange.estimateIntervalId);
            } else {
                $(params.loadingId).attr('title', 'Estimation ongoing');
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            Zentyal.OpenChange.migrationMessage(errorThrown, 'error');
        }
    });
};
