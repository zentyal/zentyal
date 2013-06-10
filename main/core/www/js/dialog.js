"use strict";
jQuery.noConflict();

Zentyal.namespace('Dialog');

Zentyal.Dialog.DEFAULT_ID = 'load_in_dialog';

Zentyal.Dialog.loadInExistent = function(dialog, url, params) {
    var data = (params.data !== undefined) ? params.data : [];
    dialog.html('<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>');
    dialog.load(url, data, function(html) {
                    if (typeof(params.load) === 'function')  {
                        params.load.apply(this);
                    }
                });
};

Zentyal.Dialog.showURL = function(url, params) {
    var i,
        dialogParams,
        dialogParamsAllowed = ['title', 'width', 'height'],
        id;
    if (params === undefined) {
        params = {};
    }

    var existentDialog = jQuery('#load_in_dialog');
    if (existentDialog.length > 0) {
        Zentyal.Dialog.loadInExistent(existentDialog, url, params);
        return;
    }
    dialogParams = {
        resizable: false,
        modal: true,
        create: function (event, ui) {
            Zentyal.Dialog.loadInExistent(jQuery(event.target), url, params);
        },
        close:  function (event, ui) {
            if (typeof(params.close) === 'function') {
                params.close(event, ui);
            }
            jQuery(event.target).dialog('destroy');
        }
    };
    for (i=0; i < dialogParamsAllowed.length; i++) {
        var paramName = dialogParamsAllowed[i];
        if (paramName in params) {
            dialogParams[paramName] = params[paramName];
        }
    }

    if ('id' in params) {
        id = params.id;
    } else {
        id = Zentyal.Dialog.DEFAULT_ID;
    }

    jQuery('<div id="' + id + '"></div>').dialog(dialogParams);
};

Zentyal.Dialog.close = function(id) {
    if (id === undefined) {
        id =  Zentyal.Dialog.DEFAULT_ID;
    }
    jQuery('#' + id).dialog('close');
};