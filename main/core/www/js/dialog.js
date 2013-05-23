"use strict";
jQuery.noConflict();

Zentyal.namespace('Dialog');

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
    var existentDialog = jQuery('#load_in_dialog');
    if (existentDialog.length > 0) {
        Zentyal.Dialog.loadInExistent(existentDialog, url, params);
    }

    jQuery('<div id="load_in_dialog"></div>').dialog({
        title:  (params.title !== undefined) ? params.title : '',
        resizable: false,
        modal: true,
        create: function (event, ui) {
            Zentyal.Dialog.loadInExistent(jQuery(event.target), url, params);
        }
    });
};