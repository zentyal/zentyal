// Copyright (C) 2007 Warp Networks S.L.
// Copyright (C) 2008-2014 Zentyal S.L. licensed under the GPLv2
"use strict";

Zentyal.namespace('TableHelper');

// Detect session loss on ajax request:
$(document).ajaxError(function(event, jqxhr, settings, exception) {
    if (jqxhr.status === 403) {
        location.reload(true);
    }
});

Zentyal.TableHelper.cleanMessage = function (table) {
    $('#' + table + '_message').html('').removeClass();
    $('#' + table + '_error').html('').removeClass();
};

Zentyal.TableHelper.setMessage = function (table, html) {
    $('#' + table + '_message').addClass('note').html(html);
};

Zentyal.TableHelper.setError = function (table, html) {
    $('#' + table + '_error').removeClass().addClass('error').html(html);
};

// Function: setEnableRecursively
//
//  Disable or enable recursively all child elements of a given elment
//
// Parameters:
//
//  element - Parent $ element object
//  state - boolean, true to enable, false to disable
//
Zentyal.TableHelper.setEnableRecursively = function (element, state) {
    element.find(':input').each(function(index, el) {
        $(el).prop('disabled', !state);
    });
};

// Function: onFieldChange
//
//  Function called from onChange events on form and table fields.
//
// Parameters:
//
//  Event - Event prototype
//  JSONActions - JSON Object containing the actions to take
//
Zentyal.TableHelper.onFieldChange = function (event, JSONActions, table) {
    var target = $(event.target);
    var selectedValue;
    if (target.is(':checkbox, :radio') && ! target.prop('checked'))  {
        // unchecked = no value
        selectedValue = 'off';
    } else {
        selectedValue = target.val();
        if (selectedValue === null) {
            selectedValue = 'off';
        }
    }

    if (!(selectedValue in JSONActions)) {
        return;
    }

    var onValue = JSONActions[selectedValue];
    var supportedActions = ['show', 'hide', 'enable', 'disable'];
    $.each(supportedActions, function (index, action) {
        if (!(action in onValue)) {
            return true;
        }
        var fields = onValue[action];
        for (var i = 0; i < fields.length; i++) {
            var fullId = '#' + table + '_' + fields[i] + '_row';
            var element = $(fullId).first();
            switch (action)  {
               case 'show':
                  element.show();
                  break;
               case 'hide':
                  element.hide();
                  break;
               case 'enable':
                  Zentyal.TableHelper.setEnableRecursively(element, true);
                  break;
               case 'disable':
                  Zentyal.TableHelper.setEnableRecursively(element, false);
                  break;
              default:
                 break;
            }
        }
        return true;
    });
};

Zentyal.TableHelper.encodeFields = function (table, fields) {
    var pars = [];
    $.each(fields, function(index, field) {
        var value = Zentyal.TableHelper.inputValue(table + '_' + field);
        if (value) {
            pars.push(field + '=' + encodeURIComponent(value));
        }
    });

    return pars.join('&');
};

Zentyal.TableHelper.setErrorFromJSON = function(table, response) {
    var errorText;
    if ('error' in response) {
        errorText = response.error;
    } else {
        errorText = 'Unexpected failure'; // XXX lack i18n
    }
    Zentyal.TableHelper.setError(table, errorText);
};

Zentyal.TableHelper._newSuccessJSONCallback = function(table, afterSetError) {
    var success = function(response) {
        if (! response.success) {
            Zentyal.TableHelper.setErrorFromJSON(table ,response);
            if (afterSetError) {
                afterSetError(response);
            }
            return;
        }

        Zentyal.TableHelper.updateTable(table, response);
    };
    return success;
};

Zentyal.TableHelper.addNewRow = function (url, table, fields, directory, page) {
    var params, buttons_id;

    Zentyal.TableHelper.cleanMessage(table);
    buttons_id = table + '_buttons';
    Zentyal.TableHelper.setLoading(buttons_id, table, true);

    params = 'action=add&tablename=' + table + '&directory=' + directory + '&';
    params += '&page=' + page;
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }

    var error    =  function(jqXHR) { Zentyal.TableHelper.setError(table, jqXHR.responseText); };
    var success  = Zentyal.TableHelper._newSuccessJSONCallback(table);
    var complete = function(response) {
        Zentyal.refreshSaveChangesButton();
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.TableHelper.restoreHidden(buttons_id, table);
    };

    $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            success: success,
            error: error,
            complete: complete
    });

    location.hash = "#" + table;
};

Zentyal.TableHelper.setPagination = function(tableId, page, nPages, pageNumbersText) {
    var pager  = $('#' + tableId + '_pager');
    page   = parseInt(page, 10);
    nPages = parseInt(nPages, 10);

    $('#' + tableId + '_page_numbers', pager).text(pageNumbersText);
    $('.tablePrevPageControl', pager).prop('disabled', page === 0);
    $('.tableNextPageControl', pager).prop('disabled', (page+1) === nPages);
};

Zentyal.TableHelper.updateTable = function(tableId, changes) {
    var rowId,
        tr,
        i, values;
    var noMoreRowChanges = false;

    // exclusive row changes, if fired other row changes are ignored
    if ('reload' in changes) {
        $('#' + tableId).html(changes.reload);
        if ('highlightRowAfterReload' in changes) {
            $('#' + changes.highlightRowAfterReload).effect('highlight');
        }
        noMoreRowChanges = true;
    } else if ('changeRowForm' in changes) {
        $('#' + tableId + '_top').hide();
        $('#' + tableId + '_editForm').html(changes.changeRowForm).show();
        noMoreRowChanges = true;
    } else if ('dataInUseForm' in changes) {
        var topForm = $('#' + tableId + '_top');
        Zentyal.TableHelper.removeWarnings(tableId);
        topForm.before(changes.dataInUseForm);
        topForm.hide();
        $('#' + tableId + '_editForm').hide(); // Hide form but sending in the dataInUse form
        noMoreRowChanges = true;
    }
    if ('message' in changes) {
        Zentyal.TableHelper.setMessage(tableId, changes.message);
    }

    if (noMoreRowChanges) {
        if ('redirect' in changes) {
            window.location.replace(changes.redirect);
        }
        return;
    }


    var table = $('#' + tableId + '_table');
    if ('removed' in changes) {
        for (i=0; i < changes.removed.length; i++) {
            rowId = changes.removed[i];
            var row = $('#' + rowId, table);
            row.remove();
            delete savedElements['actionsCell_' + rowId];
        }
    }

    if ('added' in changes) {
        var tbody = $('#' + tableId + '_tbody', table);
        var trs   = $('tr', tbody);
        var empty = trs.length === 0;
        for (i=0; i < changes.added.length; i ++) {
            var toAdd = changes.added[i];
            var position = toAdd.position;
            tr = $(toAdd.row);
            if (position === 'append') {
                tbody.append(tr);
            } else if (position === 'prepend') {
                tbody.prepend(tr);
            } else {
                // after a given row
                var trReference  = $('#' + position, tbody);
                trReference.after(tr);
            }
            tr.effect('highlight');
        }

    }

    if ('changed' in changes) {
        for (rowId in changes.changed) {
            $('#' + rowId, table).replaceWith(changes.changed[rowId]);
            $('#' + rowId, table).effect('highlight');
        }
    }

    if ('paginationChanges' in changes) {
        Zentyal.TableHelper.setPagination(tableId,
                                          changes.paginationChanges.page,
                                          changes.paginationChanges.nPages,
                                          changes.paginationChanges.pageNumbersText);
    }

    Zentyal.TableHelper.restoreTop(tableId);

    if ('redirect' in changes) {
        window.location.replace(changes.redirect);
    }
};

Zentyal.TableHelper.restoreTop = function(tableId) {
    $('#' + tableId + '_top').show();
    $('#' + tableId + '_editForm').hide();
    $('#creatingForm_' + tableId).html('');
};

/* Function: removeWarnings

    Restore the status before the DataInUse were raised

*/
Zentyal.TableHelper.removeWarnings = function(tableId) {
    $('#' + tableId + '_data_in_use').remove();
};

Zentyal.TableHelper.changeRow = function (url, table, fields, directory, id, page, force) {
    var params, buttonsId;

    Zentyal.TableHelper.cleanMessage(table);
    buttonsId = table + '_buttons';
    Zentyal.TableHelper.setLoading(buttonsId, table, true);

    params = '&action=edit&tablename=' + table;
    params +=  '&directory='  + directory + '&id=' + id + '&';
    if ( page != undefined ) params += '&page=' + page;

    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    if (force) {
          params += '&force=1';
    }
    if (fields) {
      params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }

    var error  =  function(jqXHR) { Zentyal.TableHelper.setError(table, jqXHR.responseText); };
    var success = Zentyal.TableHelper._newSuccessJSONCallback(table);
    var complete = function(response) {
        Zentyal.TableHelper.highlightRow( id, false);
        Zentyal.TableHelper.restoreHidden(buttonsId, table);
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.refreshSaveChangesButton();
    };

    $.ajax({
        url: url,
        data: params,
        type : 'POST',
        dataType: 'json',
        success: success,
        error: error,
        complete: complete
    });

};

/*
Function: deleteActionClicked

        Callback function when a delete action on the table is clicked

Parameters:

    url - the CGI URL to call to do the action
    table - the table's name
    action - the action to do (move, del)
    rowId  - the affected row identifier
    directory - the GConf directory where table is stored
    page        -
    extraParams - an object with extra parameter as keys and values


*/
Zentyal.TableHelper.deleteActionClicked = function (url, table, rowId, directory, page, force) {
    var params;
    var actionsCellId = 'actionsCell_' + rowId;

    Zentyal.TableHelper.cleanMessage(table);
    Zentyal.TableHelper.setLoading(actionsCellId, table, true);
    Zentyal.TableHelper.highlightRow(rowId, true, table);

    params = '&action=del&id=' + rowId;
    if ( page != undefined ) {
        params += '&page=' + page;
    }
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    params += '&directory=' + directory + '&tablename=' + table;
    if (force) {
          params += '&force=1';
    }

    var afterSetError = function () {
        Zentyal.TableHelper.restoreHidden(actionsCellId);
    };
    var error = function(response) {
        Zentyal.TableHelper.setError(table, response.responseText);
        afterSetError();
    };
    var success  = Zentyal.TableHelper._newSuccessJSONCallback(table, afterSetError);
    var complete = function(response) {
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.refreshSaveChangesButton();
    };

    $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            success: success,
            error: error,
            complete: complete
   });
};

Zentyal.TableHelper.formSubmit = function (url, table, fields, directory, id) {
    var params;

    Zentyal.TableHelper.cleanMessage(table);

    params = '&action=edit&form=1';
    params += '&tablename=' + table;
    params += '&directory=' + directory;
    params += '&id=' + id;
    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }

    var error  =  function(jqXHR) { Zentyal.TableHelper.setError(table, jqXHR.responseText); };
    var success = function(response) {
        if (!response.success) {
            Zentyal.TableHelper.setErrorFromJSON(table, response);
            return;
        }
        if ('message' in response) {
            Zentyal.TableHelper.setMessage(table, response.message);
        }
        if ('redirect' in response) {
            window.location.replace(response.redirect);
        }
        if ('dataInUseForm' in response) {
            Zentyal.TableHelper.removeWarnings(table);
            var form = $('#' + table + '_ajaxform');
            form.before(response.dataInUseForm);
        }
    };
    var complete = function(response){
        $('#' + id + ' .customActions').each(function(index, element) {
            Zentyal.TableHelper.restoreHidden(element.id, table);
        });
        Zentyal.refreshSaveChangesButton();
    };

    $('#' + id + ' .customActions').each(function(index, element) {
        Zentyal.TableHelper.setLoading(element.id, table, true);
    });

   $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            success: success,
            error: error,
            complete: complete
    });
};


Zentyal.TableHelper.showChangeRowForm = function (url, table, directory, action, id, page, isFilter) {
    var params;

    Zentyal.TableHelper.cleanMessage(table);
    if ( action == 'changeAdd' ) {
      Zentyal.TableHelper.setLoading('creatingForm_' + table, table, true);
    } else if ( action == 'changeList' ) {
        if ( ! isFilter ) {
            Zentyal.TableHelper.setLoading(table + '_buttons', table, true);
        }
    } else if ( (action == 'changeEdit') || (action == 'changeClone') ) {
      Zentyal.TableHelper.setLoading('actionsCell_' + id, table, true);
    } else {
        throw "Unsupported action: " + action;
    }

    params = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    params += '&page=' + page;

    var afterSetError = function () {
        if ( action == 'changeAdd' ) {
            Zentyal.TableHelper.restoreHidden('creatingForm_' + table, table);
        } else if ( action == 'changeList' ) {
            if (! isFilter ) {
                Zentyal.TableHelper.restoreHidden(table + '_buttons', table);
            }
        }  else if ( action == 'changeEdit' ) {
            Zentyal.TableHelper.restoreHidden('actionsCell_' + id, table);
        }
    };
    var error = function(response) {
        Zentyal.TableHelper.setError(table, response.responseText);
    };
    var success  = Zentyal.TableHelper._newSuccessJSONCallback(table, afterSetError);
    var complete = function(response) {
        // Highlight the element
        if (id != undefined) {
            Zentyal.TableHelper.highlightRow(id, true, table);
        }
        // Zentyal.Stripe again the table
        Zentyal.stripe('.dataTable', 'even', 'odd');
        if ( action == 'changeEdit' ) {
            Zentyal.TableHelper.restoreHidden('actionsCell_' + id, table);
        }
        Zentyal.TableHelper.completedAjaxRequest();
        Zentyal.refreshSaveChangesButton();
    };

    $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            success: success,
            error: error,
            complete: complete
    });
};

Zentyal.TableHelper.changeView = function (url, table, directory, action, id, page, isFilter) {
    var params;
    Zentyal.TableHelper.cleanMessage(table);

    if ( action == 'changeList' ) {
        if ( ! isFilter ) {
            Zentyal.TableHelper.setLoading(table + '_buttons', table, true);
        }
    } else {
        throw "Unsupported action: " + action;
    }

    params = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    params += '&page=' + page;
    var success = function(responseText) {
        $('#' + table).html(responseText);
    };
    var error = function(response) {
        Zentyal.TableHelper.setError(table, response.responseText);
        if ( action == 'changeList' ) {
            if (! isFilter ) {
                Zentyal.TableHelper.restoreHidden(table + '_buttons', table);
            }
        }
    };
    var complete = function(response) {
        // Highlight the element
        if (id != undefined) {
            Zentyal.TableHelper.highlightRow(id, true, table);
        }
        // Zentyal.Stripe again the table
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.TableHelper.completedAjaxRequest();
        Zentyal.refreshSaveChangesButton();
    };

   $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: error,
            complete: complete
    });
};

Zentyal.TableHelper.checkAll = function (url, table, directory, field, checkAllValue) {
    var params;
    Zentyal.TableHelper.cleanMessage(table);

    var selector = 'input[id^="' + table + '_' + field + '_"]';
    var checkboxesParents = $(selector).parent();
    checkboxesParents.each( function(i, e) {
        Zentyal.TableHelper.setLoading(e.id, table, true);
    });

    params = 'action=checkAll&editid=' + field;
    params += '&' + field + '=' + (checkAllValue ? 1 : 0) + '&tablename=' + table + '&directory=' + directory;

    var restore = function() {
        checkboxesParents.each(function(index, element) {
            Zentyal.TableHelper.restoreHidden(element.id, table);
        });
    };
    var error = function(response) {
        restore();
        Zentyal.TableHelper.setError(table, response.error);
    };
    var success = function(response) {
        if (response.success) {
            restore();
            checkboxesParents.find(':checkbox').prop('checked', response.checkAllValue == 1 ? true : false);
        } else {
            error(response);
        }
    };
    var complete = function(response) {
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.TableHelper.completedAjaxRequest();
        Zentyal.refreshSaveChangesButton();
    };

   $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            success: success,
            error: error,
            complete: complete
    });
};

/*
Function: hangTable

        Hang a table under the given identifier via AJAX request
    replacing all HTML content. The parameters to the HTTP request
    are passed by an HTML form.

Parameters:

        successId - div identifier where the new table will be on on success
    errorId - div identifier
        url - the URL where the CGI which generates the HTML is placed
    formId - form identifier which has the parameters to pass to the CGI
        loadingId - String element identifier that it will substitute by the loading image
        *(Optional)* Default: 'loadingTable'

*/
Zentyal.TableHelper.hangTable = function (successId, errorId, url, formId, loadingId) {
  Zentyal.TableHelper.setLoading(loadingId);
    // clean error messages
    $('#' + errorId).html("");

    if ( ! loadingId ) {
        loadingId = 'loadingTable';
    }

    var params = $('#' + formId).first().serialize();
    var success = function(responseText) {
        $('#' + successId).html(responseText);
    };
    var error = function(response) {
        $('#' + errorId).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden(loadingId, '', true);
    };
    var complete = function(response) {
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.TableHelper.completedAjaxRequest();
        Zentyal.refreshSaveChangesButton();
    };

    $.ajax({
        url: url,
        data: params,
        type : 'POST',
        dataType: 'html',
        success: success,
        error: error,
        complete: complete
    });
};

/*
Function: selectComponentToHang

        Call to a component to be hang in a select entry

Parameters:

    successId - div identifier where the new table will be on on success
    errorId - div identifier
    formId - form identifier which has the parameters to pass to the CGI
    urls - associative array which contains tthe URL where the CGI which generates the HTML is placed
    loadingId - String element identifier that it will substitute by the loading image
    *(Optional)* Default: 'loadingTable'

*/
Zentyal.TableHelper.selectComponentToHang = function (successId, errorId, formId, urls, loadingId) {
    // clean error messages
    $('#' + errorId).html("");

    if ( ! loadingId ) {
        loadingId = 'loadingTable';
    }

    var selectValue = $('#' + formId).children(':select').first().val();
    var url = urls[selectValue];

    var params = "action=view"; // FIXME: maybe the directory could be sent
    var success = function(responseText) {
        $('#' + successId).html(responseText);
        Zentyal.TableHelper.restoreHidden(loadingId);
    };
    var error = function(response) {
        $('#' + errorId).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden(loadingId);
    };
    var complete = function(response) {
        Zentyal.TableHelper.completedAjaxRequest();
        Zentyal.refreshSaveChangesButton();
    };

    $.ajax({
        url: url,
        data: params,
        type : 'POST',
        dataType: 'html',
        success: success,
        error: error,
        complete: complete
    });

  Zentyal.TableHelper.setLoading(loadingId);
};


/*
Function: showSelected

        Show the HTML setter selected in select

Parameters:

        selectElement - HTMLSelectElement

*/
Zentyal.TableHelper.showSelected  = function (selectElement)
{
    var selectedValue = $(selectElement).val();
    var options = selectElement.options;
    $.each(options, function(index, option) {
        var childSelector = '#' + selectElement.id + "_" + option.value + "_container";
        if (selectedValue == option.value) {
            $(childSelector).show();
        } else {
            $(childSelector).hide();
        }
    });
};

/*
Function: showPort

      Show port if it's necessary given a protocol

Parameters:

    protocolSelectId - the select identifier which the protocol is chosen
    portId   - the identifier where port is going to be set
    protocols - the list of protocols which need a port to be set

*/
Zentyal.TableHelper.showPort = function (protocolSelectId, portId, protocols) {
    var selectedValue = $('#' + protocolSelectId).val();
    if (protocols.indexOf(selectedValue) > -1) {
        $('#' + portId).show();
    } else {
        $('#' + portId).hide();
    }
};

/*
Function: showPortRange

    Show/Hide elements in PortRange view

Parameters:

    id - the select identifier which the protocol is chosen

*/
Zentyal.TableHelper.showPortRange = function (id) {
    var selectedValue = $('#' + id + '_range_type').val();
    var single = $('#' + id + '_single');
    var range = $('#' + id + '_range');

    if ( selectedValue == 'range') {
        single.hide();
        range.show();
        $('#' + id + '_single_port').val('');
    } else if (selectedValue == 'single') {
        single.show();
        range.hide();
        $('#' + id + '_to_port').val('');
        $('#' + id + '_from_port').val('');
    } else {
        single.hide();
        range.hide();
        $('#' + id + '_to_port').val('');
        $('#' + id + '_from_port').val('');
        $('#' + id + '_single_port').val('');
    }
};

/*
Function: setLoading

        Set the loading icon on the given HTML element erasing
        everything which were there. If modelName is set, isSaved parameter can be used

Parameters:

        elementId - the element identifier
        modelName - the model name to distinguish among hiddenDiv tags *(Deprecated: not used)*
        isSaved   - boolean to indicate if the inner HTML should be saved to be able to restore it later
                    with restoreHidden function
*/
var savedElements = {};
//XXX modelName does not do anything..
Zentyal.TableHelper.setLoading  = function (elementId, modelName, isSaved) {
  var element = $('#' + elementId);
  if (isSaved) {
      savedElements[elementId] = element.html();
  }
  element.html('<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>');
};

/*
Function: setDone

        Set the done icon (a tick) on the given HTML element erasing
        everything which were there.

Parameters:

        elementId - String the element identifier


*/
Zentyal.TableHelper.setDone  = function (elementId)
{
    $('#' + elementId).html("<img src='/data/images/apply.gif' " +
                                 "alt='done' class='tcenter'/>");
};

/*
Function: restoreHidden

        Restore HTML stored by setLoading method

Parameters:

        elementId - the element identifier where to restore the HTML hidden
        modelName - the model name to distinguish among hidden (*Deprecated: not used*)        
        optParameters - named optional parameters:
                        keep_if_not_saved: do not overwrite with empty content
                                           if the elementId is not in saved elements

*/
Zentyal.TableHelper.restoreHidden  = function (elementId, modelName, optParameters) {
    if (elementId in savedElements) {
        $('#' + elementId).html(savedElements[elementId]);
        delete savedElements[elementId];
    } else {
        if (! optParameters || ! optParameters['keep_if_not_saved']) {
            $('#' + elementId).html('');
        }
    }
};

/*
Function: highlightRow

        Enable/Disable a hightlight over an element on the table

Parameters:

        elementId - the row identifier to highlight
        enable  - if enables/disables the highlight *(Optional)*
                Default value: true
        table  - if enable is true, it unhighlights all row from this table
                 before highlightinh *(Optional*)

*/
// XXX Seein it with elmentId = undef!!
Zentyal.TableHelper.highlightRow = function (elementId, enable, table) {
  // If enable has value null or undefined
    if ( (enable === null) || (enable === undefined)) {
        enable = true;
    }
    if (enable) {
        var row;
        if (table) {
            $('#' + table + '_table tr').removeClass('highlight');
        }
        $('#' + elementId).addClass("highlight");
    } else {
        $('#' + elementId).removeClass("highlight");
    }
};

/*
Function: inputValue

    Return an input value. Or empty string igf the input does not exists

Parameters:

    elementId - the input element to fetch the value from

Returns:

    input value if it exits, otherwise empty string
*/
Zentyal.TableHelper.inputValue = function (elementId) {
    var value ='';
    $('#' + elementId).each(function (index, element) {
        var input = $(element);
        if (input.is('input[type="checkbox"]') && ! input.prop('checked'))  {
            // unchecked = no value
            return true;
        }
        var tmpValue = input.val();
        if ((tmpValue !== null) && (tmpValue !== undefined)){
            value = tmpValue;
            return false;
        }
    });

    return value;
};

/*
Function: markFileToRemove

    This function is used along with the File view and setter to mark
    a file to be removed

Parameters:

    elementId - a EBox::Types::File id
*/
Zentyal.TableHelper.markFileToRemove = function (id) {
    $('#' + id + '_remove').val(1);
    hide(id + '_current');
};

/*
Function: sendInPlaceBooleanValue

    This function is used to send the value change of a boolean type with in-place
    edition

Parameters:

    controller - url
    model - model
    id - row id
    dir - conf dir
    field - field name
    element - HTML element
*/
Zentyal.TableHelper.sendInPlaceBooleanValue = function (url, model, id, dir, field, element, force) {
    var elementId = element.id;
    element = $(element);
    Zentyal.TableHelper.startAjaxRequest();
    Zentyal.TableHelper.cleanMessage(model);
    element.hide();
    var loadingId = elementId + '_loading';
    Zentyal.TableHelper.setLoading(loadingId, model, true);

    var params = 'action=editBoolean';
    params += '&model=' + model;
    params += '&dir=' + dir;
    params += '&field=' + field;
    params += '&id=' + id;
    if (element.prop('checked')) {
       params += '&value=1';
    }
    // If force is used, then use it
    if (force) params += '&force=1';

    var error = function(response) {
        Zentyal.TableHelper.setError(model, response.responseText);
        var befChecked = ! element.prop('checked');
        element.prop(befChecked);
    };
    var complete = function(response) {
        Zentyal.TableHelper.completedAjaxRequest();
        element.show();
        Zentyal.TableHelper.restoreHidden(loadingId);
        Zentyal.refreshSaveChangesButton();
    };
    var success = function(response) {
        var json;
        try {
            json = $.parseJSON(response);
        } catch (e) { };
        if (json && json.success && 'dataInUseForm' in json) {
            var topForm = $('#' + model + '_top');
            Zentyal.TableHelper.removeWarnings(model);
            topForm.before(json.dataInUseForm);
            topForm.hide();
        }
    };

   $.ajax({
       url: url,
       data: params,
       type : 'POST',
       error: error,
       success: success,
       complete: complete
   });
};

/*
Function: startAjaxRequest

    This function is used to mark we start an ajax request.
    This is used to help test using selenium, it modifies
    a dom element -request_cookie- to be able to know when
    an ajax request starts and stops.

*/
Zentyal.TableHelper.startAjaxRequest = function ()
{
    $('#ajax_request_cookie').val(1);
};

/*
Function: completedAjaxRequest

    This function is used to mark we finished an ajax request.
    This is used to help test using selenium, it modifies
    a dom element -request_cookie- to be able to know when
    an ajax request starts and stops.

*/
Zentyal.TableHelper.completedAjaxRequest = function () {
    $('#ajax_request_cookie').val(0);
};

Zentyal.TableHelper.addSelectChoice = function (id, value, printableValue, selected) {
    var selectControl = document.getElementById(id);
    if (!selectControl) {
      return;
    }
    var newChoice = new Option(printableValue, value);

    selectControl.options.add(newChoice);
    if (selected) {
        selectControl.options.selectedIndex = selectControl.options.length -1;
    }
};

Zentyal.TableHelper.removeSelectChoice = function (id, value, selectedIndex) {
    var selectControl = document.getElementById(id);
    if (!selectControl) {
      return;
    }

    var options = selectControl.options;
    for(var i=0; i < options.length; i++){
      if(options[i].value==value){
        options[i] = null;
        break;
      }
    }

   if (selectedIndex) {
     options.selectedIndex = selectedIndex;
   }

};

Zentyal.TableHelper.checkAllControlValue = function (url, table, directory, controlId, field) {
    var params = 'action=checkAllControlValue&tablename=' + table + '&directory=' + directory;
    params += '&controlId=' + controlId  + '&field=' + field;
    params +=  '&json=1';

    var complete = function(response) {
        Zentyal.TableHelper.completedAjaxRequest();
        var json = $.parseJSON(response.responseText);
        $('#' + controlId).prop('checked', json.success);
        Zentyal.refreshSaveChangesButton();
    };

    $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            complete: complete
    });
};

Zentyal.TableHelper.confirmationDialog = function (url, table, directory, actionToConfirm, elements) {
    var wantDialog  = false;
    var dialogTitle = null;
    var dialogMsg = null;
    var abort = false;

    var params = 'action=confirmationDialog' +  '&tablename=' + table + '&directory=' + directory;
    params +='&actionToConfirm=' + actionToConfirm;
    for (var i=0; i < elements.length; i++) {
        var name = elements[i];
        var id = table + '_' + name;
        var el = $('#' + id);
        params +='&'+ name + '=';
        params += encodeURIComponent(el.val());
    }

    var success = function (text) {
        var json = $.parseJSON(text);
        if (json.success) {
            if (json.wantDialog) {
                wantDialog = true;
                dialogTitle = json.title;
                dialogMsg = json.message;
            }
        } else {
            Zentyal.TableHelper.setError(table, json.error);
            abort = true;
        }

    };
    var error = function(jqXHR) {
        Zentyal.TableHelper.setError(table, jqXHR.responseText);
        abort = true;
    };

   $.ajax({
       url: url,
       async: false,
       data: params,
       type : 'POST',
       dataType: 'html',
       success: success,
       error: error
   });

  return {
    'wantDialog' : wantDialog,
    'abort' : abort,
    'title': dialogTitle,
    'message': dialogMsg
   };
};

Zentyal.TableHelper.showConfirmationDialog = function (params, acceptMethod) {
    var modalboxHtml = "<div><div class='warning'>" + params.message  +  '</div></div>';

    $(modalboxHtml).first().dialog({
        title:  params.title,
        resizable: false,
        modal: true,
        buttons: {
            Ok: function() {
                acceptMethod();
                Zentyal.refreshSaveChangesButton();
                $( this ).dialog( "close" );
            },
            Cancel: function() {
                $( this ).dialog( "close" );
            }
        }
    });
};

Zentyal.TableHelper.setSortableTable = function(url, tableName, directory) {
    var tableBody = $('#' + tableName + '_tbody');
    tableBody.sortable({
        items: '.movableRow',
        handle: '.moveRowHandle',
        placeholder: 'moveRowPlaceholder',
        delay: 100,
        start: function(event, ui) {
            ui.placeholder.height(ui.helper.outerHeight());
        },
        helper: function(e, ui) {
            ui.children().each(function() {
                $(this).width($(this).width());
            });
            return ui;
        },
        update: function(event, ui) {
            var movedId = ui.item.attr('id');
            var newOrder = tableBody.children('tr').map(function() {
                         return this.id ? this.id : null;
            }).get();
            Zentyal.TableHelper.changeOrder(url, tableName, directory, movedId, newOrder);
            Zentyal.stripe('#' + tableName, 'even', 'odd');
        }
    });
};

Zentyal.TableHelper.changeOrder = function(url, table, directory, movedId, order) {
    var data;
    var prevId = 0, nextId = 0;

    for (var i=0; i < order.length; i++) {
        if (order[i] === movedId) {
            if ((i-1) >= 0) {
                prevId = order[i-1];
            }
            if ((i+1) < order.length) {
                nextId = order[i+1];
            }
        }
    }

    if ((prevId === null) && (nextId === null)) {
        // no real change
        return;
    }

    data = 'action=setPosition&tablename=' + table + '&directory=' + directory;
    data += '&id=' + movedId;
    data += '&prevId=' + prevId;
    data += '&nextId=' + nextId;
    $.ajax({
        url: url,
        data: data,
        dataType: 'json',
        complete: function (response) {
            Zentyal.refreshSaveChangesButton();
        }
   });
};

Zentyal.TableHelper.modalChangeView = function (url, table, directory, action, id, extraParams)
{
    var title = '';
    var params;

    if ( action == 'changeAdd' ) {
        Zentyal.TableHelper.setLoading('creatingForm_' + table, table, true);
    } else {
        throw "Unsupported action: " + action;
    }

    params = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
    for (name in extraParams) {
      if (name == 'title') {
        title = extraParams['title'];
      } else {
        params += '&' + name + '=' + extraParams[name];
      }
    }

    Zentyal.Dialog.showURL(url, {title: title,
                                 data: params,
                                 load: function() {
                                     // fudge for pootle bug
                                     var badText = document.getElementById('ServiceTable_modal_name');
                                     if (badText){
                                         badText.value = '';
                                     }
                                 }
                                });
};

Zentyal.TableHelper.customActionClicked = function (action, url, table, fields, directory, id, page) {
    var params;

    Zentyal.TableHelper.cleanMessage(table);
    /* while the ajax udpater is running the active row is shown as loading
and the other table rows input are disabled to avoid running two custom
actions at the same time */
    $('tr:not(#' + id + ') .customActions input').prop('disabled', true).addClass('disabledCustomAction');
    $('#' + id + ' .customActions').each(function(index, element) {
        Zentyal.TableHelper.setLoading(element.id, table, true);
    });

    params = '&action=' + action;
    params += '&tablename=' + table;
    params += '&directory=' + directory;
    params += '&id=' + id;
    if (page) {
        params += '&page=' + page;
    }
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }

    var success = function(responseText) {
        $('#' + table).html(responseText);
    };
    var error = function(response) {
        $('#' + table + '_error').html(response.responseText).show();
        $('#' + id + ' .customActions').each(function(index, element) {
            Zentyal.TableHelper.restoreHidden(element.id, table);
        });
    };
    var complete = function(response){
        $('tr:not(#' + id + ') .customActions input').prop('disabled', false).removeClass('disabledCustomAction');
        Zentyal.refreshSaveChangesButton();
    };

   $.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: error,
            complete: complete
    });
};

Zentyal.TableHelper.modalAddNewRow = function (url, table, fields, directory,  nextPage, extraParams) {
    var title = '';
    var selectForeignField;
    var selectCallerId;
    var nextPageContextName;
    var params;


    Zentyal.TableHelper.cleanMessage(table);
    Zentyal.TableHelper.setLoading(table + '_buttons', table, true);
    var buttonsOnNextPage = $('#buttons_on_next_page').detach();

    params = 'action=add&tablename=' + table + '&directory=' + directory ;
    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }
    if (extraParams) {
        selectCallerId        = extraParams['selectCallerId'];
        if (selectCallerId) {
            params += '&selectCallerId=' + selectCallerId;
        }

        selectForeignField    = extraParams['selectForeignField'];
        nextPageContextName =  extraParams['nextPageContextName'];
    }

    var success =  function(json) {
        if (!json.success) {
            var error = json.error;
            if (!error) {
                error = 'Unknown error';
            }
            Zentyal.TableHelper.setError(table, error);
            Zentyal.TableHelper.restoreHidden(table + '_buttons', table);
            return;
        }

        var nextDirectory = json.directory;
        var rowId = json.rowId;
        if (selectCallerId && selectForeignField){
            var printableValue = json.callParams[selectForeignField];
            Zentyal.TableHelper.addSelectChoice(selectCallerId, rowId, printableValue, true);
            // hide 'Add a new one' element
            var newLink  = document.getElementById(selectCallerId + '_empty');
            if (newLink) {
                newLink.style.display = 'none';
                document.getElementById(selectCallerId).style.display ='inline';
            }
        }

        if (rowId && directory) {
                var nameParts = nextPageContextName.split('/');
                var baseUrl = '/' + nameParts[1] + '/';
                baseUrl += 'Controller/' + nameParts[2];
                var newDirectory = nextDirectory + '/keys/' +  rowId + '/' + nextPage;
                var nextPageUrl = baseUrl;
                var nextPageData = 'directory=' + newDirectory;
                nextPageData += '&action=view';
                var addButtons = function () {
                    var mainDiv =  $('#load_in_dialog');
                    $('.item-block', mainDiv).removeClass('item-block');
                    $('#cancel_add', buttonsOnNextPage).data('rowId', rowId);
                    buttonsOnNextPage.show();
                    mainDiv.append(buttonsOnNextPage);
                    mainDiv.addClass('item-block');
                };
                Zentyal.Dialog.showURL(nextPageUrl, {data: nextPageData, load: addButtons });
        } else {
            Zentyal.TableHelper.setError(table, 'Cannot get next page URL');
            Zentyal.TableHelper.restoreHidden(table + '_buttons', table);
        }
    };
    var complete = function () {
        Zentyal.TableHelper.completedAjaxRequest();
    };
    var error = function (jqxhr) {
        Zentyal.TableHelper.restoreHidden(table + '_buttons', table);
    };

   $.ajax({
            url: url,
            data: params,
            type : 'POST',
            success: success,
            error: error,
            complete: complete
    });
};

Zentyal.TableHelper.modalCancelAddRow  = function(url, table, elementWithId, directory, selectCaller) {
    var params, success, rowId;
    rowId = $(elementWithId).data('rowId');
    params =  "action=cancelAdd&id=" + rowId + "&directory=" + directory;

    success = function(response) {
        if (response.success) {
            if (selectCaller ) {
                Zentyal.TableHelper.removeSelectChoice(selectCaller, rowId, 2);
            }
            Zentyal.Dialog.close();
        }
    };

    $.ajax({
        url:       url,
        type:     'post',
        dataType: 'json',
        data:     params,
        success:  success
    });
};

