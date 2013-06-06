// Copyright (C) 2004-2013 Zentyal S.L. licensed under the GPLv2

// TODO
//      - Refactor addNewRow and actionClicked, they do almost the same
//      - Implement a generic function for the onComplete stage
"use strict";
jQuery.noConflict();

Zentyal.namespace('TableHelper');

// Detect session loss on ajax request:
jQuery(document).ajaxError(function(event, jqxhr, settings, exception) {
    if (jqxhr.status === 403) {
        location.reload(true);
    }
});

Zentyal.TableHelper.cleanError = function (table) {
    jQuery('#error_' + table).html('');
};

Zentyal.TableHelper.setError = function (table, html) {
    jQuery('#error_' + table).removeClass().addClass('error').html(html);
};

// Function: setEnableRecursively
//
//  Disable or enable recursively all child elements of a given elment
//
// Parameters:
//
//  element - Parent jQuery element object
//  state - boolean, true to enable, false to disable
//
Zentyal.TableHelper.setEnableRecursively = function (element, state) {
    element.find(':input').each(function(index, el) {
        jQuery(el).prop('disabled', !state);
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
    var target = jQuery(event.target);
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
    jQuery.each(supportedActions, function (index, action) {
        if (!(action in onValue)) {
            return true;
        }
        var fields = onValue[action];
        for (var i = 0; i < fields.length; i++) {
            var fullId = '#' + table + '_' + fields[i] + '_row';
            var element = jQuery(fullId).first();
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
    jQuery.each(fields, function(index, field) {
        var value = Zentyal.TableHelper.inputValue(table + '_' + field);
        if (value) {
            pars.push(field + '=' + encodeURIComponent(value));
        }
    });

    return pars.join('&');
};

Zentyal.TableHelper.modalAddNewRow = function (url, table, fields, directory,  nextPage, extraParams) {
    var title = '';
    var selectForeignField;
    var selectCallerId;
    var nextPageContextName;
    var wantJSON = 0;
    var params = 'action=add&tablename=' + table + '&directory=' + directory ;

    if (nextPage){
        wantJSON = 1;
        params +=  '&json=1';
    } else {
        params += '&page=0';
        params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
        params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    }
    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }
    if (extraParams) {
        selectCallerId        = extraParams['selectCallerId'];
        if (selectCallerId) {
            params += '&selectCallerId=' + selectCallerId;
        }

        selectForeignField    = extraParams['selectForeignField'];
        nextPageContextName = extraParams['nextPageContextName'];
    }

    Zentyal.TableHelper.cleanError(table);

    var success =  function(text) {
        if (!nextPage) {
            jQuery('#' + table).html(text);
        }
        Zentyal.stripe('.dataTable', 'even', 'odd');
        if (!wantJSON) {
//            Modalbox.resizeToContent();
            return;
        }

        var json = text;
        if (!json.success) {
            var error = json.error;
            if (!error) {
                error = 'Unknown error';
            }
            Zentyal.TableHelper.setError(table, error);
            Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
//            Modalbox.resizeToContent();
            return;
        }

        if (nextPage && nextPageContextName) {
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
                var baseUrl = '/zentyal/' + nameParts[1] + '/';
                baseUrl += 'ModalController/' + nameParts[2];
                var newDirectory = nextDirectory + '/keys/' +  rowId + '/' + nextPage;
                var nextPageUrl = baseUrl;
                var nextPageData = 'directory=' + newDirectory;
                nextPageData += '&firstShow=0';
                nextPageData += '&action=viewAndAdd';
                nextPageData += "&selectCallerId=" + selectCallerId;

                Zentyal.Dialog.showURL(nextPageUrl, {data: nextPageData});
            } else {
                Zentyal.TableHelper.setError(table, 'Cannot get next page URL');
                Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
//                Modalbox.resizeToContent();
               }
            return;
        }

        //sucesss and not next page
        Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
//        Modalbox.resizeToContent();
    };
    var complete = function () {
        Zentyal.TableHelper.completedAjaxRequest();
    };
    var error = function (jqxhr) {
        if (!nextPage) {
            jQuery('#error_' + table).html(jqxhr.responseText).show();
        }
        Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
//        Modalbox.resizeToContent();
    };

   jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            success: success,
            error: error,
            complete: complete
    });

    Zentyal.TableHelper.setLoading('buttons_' + table, table, true);
};

Zentyal.TableHelper.addNewRow = function (url, table, fields, directory) {
    var params = 'action=add&tablename=' + table + '&directory=' + directory + '&';

    params += '&page=0';
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');

    Zentyal.TableHelper.cleanError(table);

    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }

    var success = function(responseText) {
        jQuery('#' + table).html(responseText);
    };
    var failure = function(response) {
        jQuery('#error_' + table).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
    };
    var complete = function(response) {
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.TableHelper.completedAjaxRequest();
    };

    jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: failure,
            complete: complete
    });

    Zentyal.TableHelper.setLoading('buttons_' + table, table, true);
};

Zentyal.TableHelper.changeRow = function (url, table, fields, directory, id, page, force, resizeModalbox, extraParams) {
    var params = '&action=edit&tablename=' + table;
    params +=  '&directory='  + directory + '&id=' + id + '&';
    if ( page != undefined ) params += '&page=' + page;

    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');

    // If force parameter is ready, show it
    if ( force ) params += '&force=1';

    Zentyal.TableHelper.cleanError(table);
    if (fields) {
      params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }
    for (name in extraParams) {
        params += '&' + name + '=' + extraParams[name];
    }

    var success = function(responseText) {
        jQuery('#' + table).html(responseText);
    };
    var failure = function(response) {
        jQuery('#error_' + table).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
        if (resizeModalbox) {
//            Modalbox.resizeToContent();
        }
    };
    var complete = function(response) {
        Zentyal.TableHelper.highlightRow( id, false);
        Zentyal.stripe('.dataTable', 'even', 'odd');
        if (resizeModalbox) {
//            Modalbox.resizeToContent();
        }
    };

    jQuery.ajax({
        url: url,
        data: params,
        type : 'POST',
        dataType: 'html',
        success: success,
        error: failure,
        complete: complete
    });

    Zentyal.TableHelper.setLoading('buttons_' + table, table, true);
};


/*
Function: actionClicked

        Callback function when an action on the table is clicked

Parameters:

    url - the CGI URL to call to do the action
    table - the table's name
    action - the action to do (move, del)
    rowId  - the affected row identifier
    paramsAction - an string with the parameters related to the
                   action E.g.: param1=value1&param2=value2 *(Optional)*
    directory - the GConf directory where table is stored

*/
Zentyal.TableHelper.actionClicked = function (url, table, action, rowId, paramsAction, directory, page, extraParams) {
    var params = '&action=' + action + '&id=' + rowId;

    if ( paramsAction !== '' ) {
        params += '&' + paramsAction;
    }
    if ( page != undefined ) {
        params += '&page=' + page;
    }

    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    params += '&directory=' + directory + '&tablename=' + table;
    for (name in extraParams) {
        params += '&' + name + '=' + extraParams[name];
    }

    Zentyal.TableHelper.cleanError(table);

    var success = function(responseText) {
        jQuery('#' + table).html(responseText);

    };
    var failure = function(response) {
        jQuery('#error_' + table).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden('actionsCell_' + rowId, table);
    };
    var complete = function(response) {
        Zentyal.stripe('.dataTable', 'even', 'odd');
        if ( action == 'del' ) {
            delete savedElements['actionsCell_' + rowId];
        }
    };

   jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: failure,
            complete: complete
   });

  if ( action == 'del' ) {
    Zentyal.TableHelper.setLoading('actionsCell_' + rowId, table, true);
  }  else if ( action == 'move' ) {
    Zentyal.TableHelper.setLoading('actionsCell_' + rowId, table);
  }

};

Zentyal.TableHelper.customActionClicked = function (action, url, table, fields, directory, id, page) {
    var params = '&action=' + action;
    params += '&tablename=' + table;
    params += '&directory=' + directory;
    params += '&id=' + id;

    if (page) {
        params += '&page=' + page;
    }

    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');

    Zentyal.TableHelper.cleanError(table);

    if (fields) {
        params += '&' + Zentyal.TableHelper.encodeFields(table, fields);
    }

    var success = function(responseText) {
        jQuery('#' + table).html(responseText);
    };
    var failure = function(response) {
        jQuery('#error_' + table).html(response.responseText).show();
        jQuery('#' + id + ' .customActions').each(function(index, element) {
            Zentyal.TableHelper.restoreHidden(element.id, table);
        });
    };
    var complete = function(response){
        jQuery('tr:not(#' + id +  ') .customActions input').prop('disabled', false).removeClass('disabledCustomAction');
    };

   jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: failure,
            complete: complete
    });

    /* while the ajax udpater is running the active row is shown as loading
     and the other table rows input are disabled to avoid running two custom
     actions at the same time */
    jQuery('tr:not(#' + id +  ') .customActions input').prop('disabled', true).addClass('disabledCustomAction');
    jQuery('#' + id + ' .customActions').each(function(index, element) {
        Zentyal.TableHelper.setLoading(element.id, table, true);
    });
};

Zentyal.TableHelper.changeView = function (url, table, directory, action, id, page, isFilter) {
    var params = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    params += '&page=' + page;

    Zentyal.TableHelper.cleanError(table);

    var success = function(responseText) {
        jQuery('#' + table).html(responseText);
    };
    var failure = function(response) {
        jQuery('#error_' + table).html(response.responseText).show();
        if ( action == 'changeAdd' ) {
            Zentyal.TableHelper.restoreHidden('creatingForm_' + table, table);
        } else if ( action == 'changeList' ) {
            if (! isFilter ) {
                Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
            }
        }  else if ( action == 'changeEdit' ) {
            Zentyal.TableHelper.restoreHidden('actionsCell_' + id, table);
        } else if ( (action == 'checkboxSetAll') || (action == 'checkboxUnsetAll') ) {
            var selector = 'input[id^="' + table + '_' + id + '_"]';
            jQuery(selector).each(function(index, element) {
                Zentyal.TableHelper.restoreHidden(element.parentNode.id, table);
            });

            Zentyal.TableHelper.restoreHidden(table + '_' + id + '_div_CheckAll', table);
        }
    };
    var complete = function(response) {
        // Highlight the element
        if (id != undefined) {
            Zentyal.TableHelper.highlightRow(id, true);
        }
        // Zentyal.Stripe again the table
        Zentyal.stripe('.dataTable', 'even', 'odd');
        if ( action == 'changeEdit' ) {
            Zentyal.TableHelper.restoreHidden('actionsCell_' + id, table);
        }
        Zentyal.TableHelper.completedAjaxRequest();
    };

   jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: failure,
            complete: complete
    });

    if ( action == 'changeAdd' ) {
      Zentyal.TableHelper.setLoading('creatingForm_' + table, table, true);
    } else if ( action == 'changeList' ) {
        if ( ! isFilter ) {
            Zentyal.TableHelper.setLoading('buttons_' + table, table, true);
        }
    } else if ( action == 'changeEdit' ) {
      Zentyal.TableHelper.setLoading('actionsCell_' + id, table, true);
   } else if ( (action == 'checkboxSetAll') || (action == 'checkboxUnsetAll') ) {
       var selector = 'input[id^="' + table + '_' + id + '_"]';
       jQuery(selector).each(function(i, e) {
           Zentyal.TableHelper.setLoading(e.parentNode.id, table, true);
       });

       Zentyal.TableHelper.setLoading(table + '_' + id + '_div_CheckAll', table, true);
   }
};

Zentyal.TableHelper.modalChangeView = function (url, table, directory, action, id, extraParams)
{
    var title = '';
    var page = 1;
    var firstShow = false;
    var isFilter= false;
    var params = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
    for (name in extraParams) {
      if (name == 'title') {
        title = extraParams['title'];
      } else if (name == 'page') {
        page = extraParams['page'];
      } else if (name == 'firstShow') {
        firstShow = extraParams['firstShow'];
        params += '&firstShow=' + extraParams['firstShow'];
      } else {
        params += '&' + name + '=' + extraParams[name];
      }

    }
    if (! firstShow ) {
        params += '&firstShow=0';
    }

    params += '&filter=' + Zentyal.TableHelper.inputValue(table + '_filter');
    params += '&pageSize=' + Zentyal.TableHelper.inputValue(table + '_pageSize');
    params += '&page=' + page;

  if (firstShow) {
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
  } else {
      Zentyal.TableHelper.cleanError(table);
      var success = function(responseText) {
          jQuery('#' + table).html(responseText);
      };
      var failure = function(response) {
          jQuery('#error_' + table).html(response.responseText).show();
          if ( action == 'changeAdd' ) {
              Zentyal.TableHelper.restoreHidden('creatingForm_' + table, table);
          } else if ( action == 'changeList' ) {
              if (! isFilter ) {
                  Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
              }
          }
          else if ( action == 'changeEdit' ) {
              Zentyal.TableHelper.restoreHidden('actionsCell_' + id, table);
          }
//          Modalbox.resizeToContent();
      };
      var complete = function() {
          // Highlight the element
          if (id != undefined) {
              Zentyal.TableHelper.highlightRow(id, true);
          }
          // Zentyal.Stripe again the table
          Zentyal.stripe('.dataTable', 'even', 'odd');
          if ( action == 'changeEdit' ) {
              Zentyal.TableHelper.restoreHidden('actionsCell_' + id, table);
          }
          Zentyal.TableHelper.completedAjaxRequest();
  //        Modalbox.resizeToContent();
      };

      jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'html',
            success: success,
            error: failure,
            complete: complete
      });

      if ( action == 'changeAdd' ) {
          Zentyal.TableHelper.setLoading('creatingForm_' + table, table, true);
      } else if ( action == 'changeList' ) {
          if ( ! isFilter ) {
              Zentyal.TableHelper.setLoading('buttons_' + table, table, true);
          }
      }
      else if ( action == 'changeEdit' ) {
          Zentyal.TableHelper.setLoading('actionsCell_' + id, table, true);
      }
  }
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
    var params = jQuery('#' + formId).first().serialize();
    // clean error messages
    jQuery('#' + errorId).html("");

    if ( ! loadingId ) {
        loadingId = 'loadingTable';
    }

    var success = function(responseText) {
        jQuery('#' + successId).html(responseText);
    };
    var failure = function(response) {
        jQuery('#' + errorId).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden('buttons_' + table, table);
    };
    var complete = function(response) {
        Zentyal.stripe('.dataTable', 'even', 'odd');
        Zentyal.TableHelper.completedAjaxRequest();
    };

    jQuery.ajax({
        url: url,
        data: params,
        type : 'POST',
        dataType: 'html',
        success: success,
        error: failure,
        complete: complete
    });


  Zentyal.TableHelper.setLoading(loadingId);
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
    jQuery('#' + errorId).html("");

    if ( ! loadingId ) {
        loadingId = 'loadingTable';
    }

    var selectValue = jQuery('#' + formId).children(':select').first().val();
    var url = urls[selectValue];

    var params = "action=view"; // FIXME: maybe the directory could be sent
    var success = function(responseText) {
        jQuery('#' + successId).html(responseText);
        Zentyal.TableHelper.restoreHidden(loadingId);
    };
    var failure = function(response) {
        jQuery('#' + errorId).html(response.responseText).show();
        Zentyal.TableHelper.restoreHidden(loadingId);
    };
    var complete = function(response) {
        Zentyal.TableHelper.completedAjaxRequest();
    };

    jQuery.ajax({
        url: url,
        data: params,
        type : 'POST',
        dataType: 'html',
        success: success,
        error: failure,
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
    var selectedValue = jQuery(selectElement).val();
    var options = selectElement.options;
    jQuery.each(options, function(index, option) {
        var childSelector = '#' + selectElement.id + "_" + option.value + "_container";
        if (selectedValue == option.value) {
            jQuery(childSelector).show();
        } else {
            jQuery(childSelector).hide();
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
    var selectedValue = jQuery('#' + protocolSelectId).val();
    if (selectedValue in protocols) {
        jQuery('#' + portId).show();
    } else {
        jQuery('#' + portId).hide();
    }
};

/*
Function: showPortRange

    Show/Hide elements in PortRange view

Parameters:

    id - the select identifier which the protocol is chosen

*/
Zentyal.TableHelper.showPortRange = function (id) {
    var selectedValue = jQuery('#' + id + '_range_type').val();
    var single = jQuery('#' + id + '_single');
    var range = jQuery('#' + id + '_range');

    if ( selectedValue == 'range') {
        single.hide();
        range.show();
        jQuery('#' + id + '_single_port').val('');
    } else if (selectedValue == 'single') {
        single.show();
        range.hide();
        jQuery('#' + id + '_to_port').val('');
        jQuery('#' + id + '_from_port').val('');
    } else {
        single.hide();
        range.hide();
        jQuery('#' + id + '_to_port').val('');
        jQuery('#' + id + '_from_port').val('');
        jQuery('#' + id + '_single_port').val('');
    }
};

/*
Function: setLoading

        Set the loading icon on the given HTML element erasing
        everything which were there. If modelName is set, isSaved parameter can be used

Parameters:

        elementId - the element identifier
        modelName - the model name to distinguish among hiddenDiv tags *(Optional)*
    isSaved   - boolean to indicate if the inner HTML should be saved
    at *hiddenDiv_<modelName>* in order to be rescued afterwards *(Optional)*


*/
var savedElements = {};
//XXX modelName does ntvalue = o do anything..
Zentyal.TableHelper.setLoading  = function (elementId, modelName, isSaved) {
  var element = jQuery('#' + elementId);
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
    jQuery('#' + elementId).html("<img src='/data/images/apply.gif' " +
                                 "alt='done' class='tcenter'/>");
};

/*
Function: restoreHidden

        Restore HTML stored in *hiddenDiv*

Parameters:

        elementId - the element identifier where to restore the HTML hidden
        modelName - the model name to distinguish among hiddenDiv tags XXX not used. Remove?

*/
Zentyal.TableHelper.restoreHidden  = function (elementId, modelName)
{
    if (savedElements[elementId] !== null) {
        jQuery('#' + elementId).html(savedElements[elementId]);
    } else {
        jQuery('#' + elementId).html('');
    }
};

/*
Function: highlightRow

        Enable/Disable a hightlight over an element on the table

Parameters:

        elementId - the row identifier to highlight
    enable    - if enables/disables the highlight *(Optional)*
                Default value: true

*/
// XXX Seein it with elmentId = udnef!!
Zentyal.TableHelper.highlightRow = function (elementId, enable) {
  // If enable has value null or undefined
    if ( (enable === null) || (enable === undefined)) {
        enable = true;
    }
    if (enable) {
        // Highlight the element putting the CSS class which does so
        jQuery('#' + elementId).addClass("highlight");
    } else {
        jQuery('#' + elementId).removeClass("highlight");
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
    jQuery('#' + elementId).each(function (index, element) {
        var input = jQuery(element);
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
    jQuery('#' + id + '_remove').val(1);
    hide(id + '_current');
};

/*
Function: sendInPlaceBooleanValue

    This function is used to send the value change of a boolean type with in-place
    edtion

Parameters:

    controller - url
    model - model
    id - row id
    dir - conf dir
    field - field name
    element - HTML element
*/
Zentyal.TableHelper.sendInPlaceBooleanValue = function (url, model, id, dir, field, element) {
    var elementId = element.id;
    element = jQuery(element);

    Zentyal.TableHelper.startAjaxRequest();
    Zentyal.TableHelper.cleanError(model);

    var params = 'action=editBoolean';
    params += '&model=' + model;
    params += '&dir=' + dir;
    params += '&field=' + field;
    params += '&id=' + id;
    if (element.prop('checked')) {
       params += '&value=1';
    }

    element.hide();
    Zentyal.TableHelper.setLoading(elementId + '_loading', model, true);

    var success = function (responseText) {
        eval(responseText);
    };
    var failure = function(response) {
        jQuery('#error_' + model).html(response.responseText);
        var befChecked = ! element.prop('checked');
        element.prop(befChecked);
    };
    var complete = function(response) {
        Zentyal.TableHelper.completedAjaxRequest();
        element.show();
        jQuery('#' + elementId + '_loading').html('');
    };

   jQuery.ajax({
       url: url,
       data: params,
       type : 'POST',
       dataType: 'html',
       success: success,
       error: failure,
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
    jQuery('#ajax_request_cookie').val(1);
};

/*
Function: completedAjaxRequest

    This function is used to mark we finished an ajax request.
    This is used to help test using selenium, it modifies
    a dom element -request_cookie- to be able to know when
    an ajax request starts and stops.

*/
Zentyal.TableHelper.completedAjaxRequest = function () {
    jQuery('#ajax_request_cookie').val(0);
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
    for(var i=0;i< options.length;i++){
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
        var json = jQuery.parseJSON(response.responseText);
        jQuery('#' + controlId).prop('checked', json.success);
    };

    jQuery.ajax({
            url: url,
            data: params,
            type : 'POST',
            dataType: 'json',
            complete: complete
    });
};

Zentyal.TableHelper.confirmationDialog = function (url, table, directory, actionToConfirm, elements) {
    var wantDialog  = true;
    var dialogTitle = null;
    var dialogMsg = null;

    var params = 'action=confirmationDialog' +  '&tablename=' + table + '&directory=' + directory;
    params +='&actionToConfirm=' + actionToConfirm;
    for (var i=0; i < elements.length; i++) {
        var name = elements[i];
        var id = table + '_' + name;
        var el = jQuery('#' + id);
        params +='&'+ name + '=';
        params += el.val();
    }

    var success = function (text) {
        var json = jQuery.parseJSON(text);
        if (json.wantDialog) {
             dialogTitle = json.title;
             dialogMsg = json.message;
        } else {
            wantDialog = false;
        }
    };
    var failure = function() {
          dialogTitle = '';
          dialogMsg = 'Are you sure?';
    };
   jQuery.ajax({
       url: url,
       async: false,
       data: params,
       type : 'POST',
       dataType: 'html',
       success: success,
       error: failure
   });

  return {
    'wantDialog' : wantDialog,
    'title': dialogTitle,
    'message': dialogMsg
   };
};

Zentyal.TableHelper.showConfirmationDialog = function (params, acceptMethod) {
    var modalboxHtml = "<div class='warning'><p>" + params.message  +  '</p></div>';
    modalboxHtml += "</p></div><div class='tcenter'>";
    modalboxHtml += "</div>";

    jQuery(modalboxHtml).first().dialog({
        title:  params.title,
        resizable: false,
        modal: true,
        buttons: {
            Ok: function() {
                acceptMethod();
                jQuery( this ).dialog( "close" );
            },
            Cancel: function() {
                jQuery( this ).dialog( "close" );
            }
        }
    });
};
