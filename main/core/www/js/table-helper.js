// Copyright (C) 2007 Warp Networks S.L
// Copyright (C) 2008-2012 Zentyal S.L. licensed under the GPLv2

// TODO
//      - Use Form.serialize stuff to get params
//      - Refactor addNewRow and actionClicked, they do almost the same
//      - Implement a generic function for the onComplete stage

function cleanError(table) {
    var error = $('error_' + table);
    if (error) {
        error.innerHTML = "";
    }
}

function setError(table, html) {
    var error = $('error_' + table);
    error.className = 'error';
    if (error) {
        error.innerHTML = html;
    }
}

// Function: setEnableRecursively
//
//  Disable or enable recursively all child elements of a given elment
//
// Parameters:
//
//  element - Parent HTMLElement object
//  state - boolean, true to enable, false to disable
//
function setEnableRecursively(element, state) {
    element.childElements().each(
        function (child) {
            //XXX Should we check child is a From or
            //    prototype takes care of it?
            if (state) {
                Form.Element.enable(child);
            } else {
                Form.Element.disable(child);
            }
            setEnableRecursively(child, state);
        }
    );
}


// Function: onFieldChange
//
//  Function called from onChange events on form and table fields.
//
// Parameters:
//
//  Event - Event prototype
//  JSONActions - JSON Object containing the actions to take
//
function onFieldChange(event, JSONActions, table) {
    var actions = new Hash(JSONActions);
    var selectedValue = $F(Event.element(event));
    if (selectedValue == undefined) {
        selectedValue = 'off';
    }

    if (! actions.get(selectedValue)) {
        return;
    }
    var onValue = new Hash(actions.get(selectedValue));
    var supportedActions = new Array('show', 'hide', 'enable', 'disable');
    supportedActions.each (
        function (action) {
            if (onValue.get(action) == undefined) {
                return;
            }
            var fields = onValue.get(action);
            for (var i = 0; i < fields.length; i++) {
                var fullId = table + '_' + fields[i] + '_row';
                switch (action)
                {
                    case 'show':
                        show(fullId);
                        break;
                    case 'hide':
                        hide(fullId);
                        break;
                     case 'enable':
                        setEnableRecursively($(fullId), true);
                        break;
                     case 'disable':
                        setEnableRecursively($(fullId), false);
                        break;
                }
            }
        }
    );
}

function encodeFields(table, fields)
{
    var pars = [];
    for (i in fields) {
        var field = fields[i];
        var value = inputValue(table + '_' + field);
        if (value) {
            pars.push(field + '=' + encodeURIComponent(value));
        }
    }
    return pars.join('&');
}

function modalAddNewRow(url, table, fields, directory,  nextPage, extraParams)
{
    var title = '';
    var selectForeignField;
    var selectCallerId;
    var nextPageContextName;
    var MyAjax;
    var AjaxParams;
    var pars = 'action=add&tablename=' + table + '&directory=' + directory ;
    var wantJSON = 0;

    if (nextPage){
     wantJSON = 1;
     pars +=  '&json=1';
    } else {
        pars += '&page=0';
        pars += '&filter=' + inputValue(table + '_filter');
        pars += '&pageSize=' + inputValue(table + '_pageSize');
    }
    if (extraParams) {
      selectCallerId        = extraParams['selectCallerId'];
      selectForeignField    = extraParams['selectForeignField'];
      nextPageContextName = extraParams['nextPageContextName'];
    }

    cleanError(table);

    if (fields) {
      pars += '&' + encodeFields(table, fields);
    }
    if (selectCallerId) {
     pars += '&selectCallerId=' + selectCallerId;
   }


   AjaxParams =  {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
              stripe('dataTable', 'even', 'odd');
              completedAjaxRequest();

              if (!wantJSON) {
                Modalbox.resizeToContent();
                return;
              }

              var json = t.responseText.evalJSON(true);
              if (!json.success) {
                 var error = json.error;
                 if (!error) {
                   error = 'Unknown error';
                 }
                 setError(table, error);
                 restoreHidden('buttons_' + table, table);
                 Modalbox.resizeToContent();
                 return;
              }

              if (nextPage && nextPageContextName) {
                var nextDirectory = json.directory;
                var rowId = json.rowId;
                if (selectCallerId && selectForeignField){
                  var printableValue = json.callParams[selectForeignField];
                  addSelectChoice(selectCallerId, rowId, printableValue, true);
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
                  nextPageUrl += '?directory=' + newDirectory;
                  nextPageUrl += '&firstShow=0';
                  nextPageUrl += '&action=viewAndAdd';
                  nextPageUrl += "&selectCallerId=" + selectCallerId;

                  Modalbox.show(nextPageUrl, {
                                  transitions: false,
                                  overlayClose : false
                                }
                               );
                } else {
                  setError(table, 'Cannot get next page URL');
                  restoreHidden('buttons_' + table, table);
                  Modalbox.resizeToContent();
                }
                return;
              }

              //sucesss and not next page
              restoreHidden('buttons_' + table, table);
              Modalbox.resizeToContent();
            },
            onFailure: function(t) {
              restoreHidden('buttons_' + table, table);
              Modalbox.resizeToContent();
            }
   };

  if (nextPage) {
    MyAjax = new Ajax.Request(
      url,
      AjaxParams
    );
  } else {
    MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
      url,
      AjaxParams
    );
  }


    setLoading('buttons_' + table, table, true);

}


function addNewRow(url, table, fields, directory)
{
    var pars = 'action=add&tablename=' + table + '&directory=' + directory + '&';

    pars += '&page=0';
    pars += '&filter=' + inputValue(table + '_filter');
    pars += '&pageSize=' + inputValue(table + '_pageSize');

    cleanError(table);

    if (fields) pars += '&' + encodeFields(table, fields);

    var MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
        url,
        {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
              stripe('dataTable', 'even', 'odd');
              completedAjaxRequest();
            },
            onFailure: function(t) {
              restoreHidden('buttons_' + table, table);
            }
        }
    );

    setLoading('buttons_' + table, table, true);
}



function changeRow(url, table, fields, directory, id, page, force, resizeModalbox, extraParams)
{
    var pars = '&action=edit&tablename=' + table + '&directory='
                   + directory + '&id=' + id + '&';
    if ( page != undefined ) pars += '&page=' + page;

    pars += '&filter=' + inputValue(table + '_filter');
    pars += '&pageSize=' + inputValue(table + '_pageSize');

    // If force parameter is ready, show it
    if ( force ) pars += '&force=1';

    cleanError(table);
    if (fields) {
      pars += '&' + encodeFields(table, fields);
    }
    for (name in extraParams) {
        pars += '&' + name + '=' + extraParams[name];
    }


    var MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
        url,
        {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
                highlightRow( id, false);
                stripe('dataTable', 'even', 'odd');
                if (resizeModalbox) {
                  Modalbox.resizeToContent();
                }
            },
            onFailure: function(t) {
                restoreHidden('buttons_' + table, table );
                if (resizeModalbox) {
                  Modalbox.resizeToContent();
                }

            }
        });

     setLoading('buttons_' + table, table, true);
}


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

function actionClicked(url, table, action, rowId, paramsAction, directory, page, extraParams) {

  var pars = '&action=' + action + '&id=' + rowId;

  if ( paramsAction != '' ) {
    pars += '&' + paramsAction;
  }
  if ( page != undefined ) {
    pars += '&page=' + page;
  }

  pars += '&filter=' + inputValue(table + '_filter');
  pars += '&pageSize=' + inputValue(table + '_pageSize');
  pars += '&directory=' + directory + '&tablename=' + table;
  for (name in extraParams) {
    pars += '&' + name + '=' + extraParams[name];
  }


  cleanError(table);

  var MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
        url,
        {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
                stripe('dataTable', 'even', 'odd');
                if ( action == 'del' ) {
                  delete savedElements['actionsCell_' + rowId];
                }
            },
            onFailure: function(t) {
                restoreHidden('actionsCell_' + rowId, table);
            }
        });

  if ( action == 'del' ) {
    setLoading('actionsCell_' + rowId, table, true);
  }
  else if ( action == 'move' ) {
    setLoading('actionsCell_' + rowId, table);
  }

}

function customActionClicked(action, url, table, fields, directory, id, page)
{
    var pars = '&action=' + action;
    pars += '&tablename=' + table;
    pars += '&directory=' + directory;
    pars += '&id=' + id;

    if (page) pars += '&page=' + page;

    pars += '&filter=' + inputValue(table + '_filter');
    pars += '&pageSize=' + inputValue(table + '_pageSize');

    cleanError(table);

    if (fields) pars += '&' + encodeFields(table, fields);

    var MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
        url,
        {
            method: 'post',
            parameters: pars,
            evalScripts: true
        }
    );

    /* while the ajax udpater is running the active row is shown as loading
     and the other table rows input are disabled to avoid running two custom
     actions at the same time */
    $$('tr:not(#' + id +  ') .customActions input').each(function(e) {
        e.disabled = true;
        e.addClassName('disabledCustomAction');
    });
    $$('#' + id + ' .customActions').each(function(e) {
        setLoading(e.identify(), table, true);
    });
}

function changeView(url, table, directory, action, id, page, isFilter)
{
    var pars = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;

    pars += '&filter=' + inputValue(table + '_filter');
    pars += '&pageSize=' + inputValue(table + '_pageSize');
    pars += '&page=' + page;

    cleanError(table);

    var MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
        url,
        {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
              // Highlight the element
              if (id != undefined) {
                highlightRow(id, true);
              }
              // Stripe again the table
              stripe('dataTable', 'even', 'odd');
              if ( action == 'changeEdit' ) {
                restoreHidden('actionsCell_' + id, table);
              }
              completedAjaxRequest();
            },
            onFailure: function(t) {
              if ( action == 'changeAdd' ) {
                restoreHidden('creatingForm_' + table, table);
              }
              else if ( action == 'changeList' ) {
                            if (! isFilter ) {
                              restoreHidden('buttons_' + table, table);
                            }
              }
              else if ( action == 'changeEdit' ) {
                restoreHidden('actionsCell_' + id, table);
              } else if ( (action == 'checkboxSetAll') || (action == 'checkboxUnsetAll') ) {
                var selector = 'input[id^="' + table + '_' + id + '_"]';
                var checkboxes = $$(selector);
                checkboxes.each(function(e) {
                                  restoreHidden(e.parentNode.identify(), table);
                                });

                restoreHidden(table + '_' + id + '_div_CheckAll', table);
             }
         }

        });

    if ( action == 'changeAdd' ) {
      setLoading('creatingForm_' + table, table, true);
    }
    else if ( action == 'changeList' ) {
          if ( ! isFilter ) {
            setLoading('buttons_' + table, table, true);
          }
    }
    else if ( action == 'changeEdit' ) {
      setLoading('actionsCell_' + id, table, true);
   } else if ( (action == 'checkboxSetAll') || (action == 'checkboxUnsetAll') ) {
       var selector = 'input[id^="' + table + '_' + id + '_"]';
       var checkboxes = $$(selector);
       checkboxes.each(function(e) {
                         setLoading(e.parentNode.identify(), table, true);
                      });

      setLoading(table + '_' + id + '_div_CheckAll', table, true);
    }

}

function modalChangeView(url, table, directory, action, id, extraParams)
{
    var title = '';
    var page = 1;
    var firstShow = false;
    var isFilter= false;
    var pars = 'action=' + action + '&tablename=' + table + '&directory=' + directory + '&editid=' + id;
    for (name in extraParams) {
      if (name == 'title') {
        title = extraParams['title'];
      } else if (name == 'page') {
        page = extraParams['page'];
      } else if (name == 'firstShow') {
        firstShow = extraParams['firstShow'];
        pars += '&firstShow=' + extraParams['firstShow'];
      } else {
        pars += '&' + name + '=' + extraParams[name];
      }

    }

  if (! firstShow ) {
        pars += '&firstShow=0';
   }

    pars += '&filter=' + inputValue(table + '_filter');
    pars += '&pageSize=' + inputValue(table + '_pageSize');
    pars += '&page=' + page;

  if (firstShow) {
      Modalbox.show(url, {title: title,
                          params: pars,
                          transitions: false,
                          overlayClose: false,
                          afterLoad: function() {
                               // fudge for pootle bug
                               var badText = document.getElementById('ServiceTable_modal_name');
                               if (badText){
                                badText.value = '';
                                }
                              }
                          }
          );

  } else {
      cleanError(table);
       var MyAjax = new Ajax.Updater(
        {
            success: table,
            failure: 'error_' + table
        },
        url,
        {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
              // Highlight the element
                          if (id != undefined) {
                highlightRow(id, true);
                          }
              // Stripe again the table
              stripe('dataTable', 'even', 'odd');
              if ( action == 'changeEdit' ) {
                restoreHidden('actionsCell_' + id, table);
              }
              completedAjaxRequest();
              Modalbox.resizeToContent();
            },
            onFailure: function(t) {
              if ( action == 'changeAdd' ) {
                restoreHidden('creatingForm_' + table, table);
              }
              else if ( action == 'changeList' ) {
                            if (! isFilter ) {
                              restoreHidden('buttons_' + table, table);
                            }
              }
              else if ( action == 'changeEdit' ) {
                restoreHidden('actionsCell_' + id, table);
              }
                Modalbox.resizeToContent();
            }

        });


     if ( action == 'changeAdd' ) {
        setLoading('creatingForm_' + table, table, true);
      }
      else if ( action == 'changeList' ) {
        if ( ! isFilter ) {
          setLoading('buttons_' + table, table, true);
        }
      }
      else if ( action == 'changeEdit' ) {
        setLoading('actionsCell_' + id, table, true);
      }
    }

}

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
function hangTable(successId, errorId, url, formId, loadingId)
{

  // Cleaning manually
  $(errorId).innerHTML = "";

  if ( ! loadingId ) {
    loadingId = 'loadingTable';
  }

  var ajaxUpdate = new Ajax.Updater(
  {
  success: successId,
  failure: errorId
  },
  url,
      {
    method: 'post',
    parameters: Form.serialize(formId, true), // The parameters are taken from the form
    asynchronous: true,
    evalScripts: true,
    onComplete: function(t) {
      stripe('dataTable', 'even', 'odd');
      completedAjaxRequest();
    },
    onFailure: function(t) {
      restoreHidden(loadingId);
    }
      }
  );

  setLoading(loadingId);

}

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
function selectComponentToHang(successId, errorId, formId, urls, loadingId)
{

  // Cleaning manually
  $(errorId).innerHTML = "";

  if ( ! loadingId ) {
    loadingId = 'loadingTable';
  }

  // Currently buggy, since select elements are not inputs
  // var selects = $(formId).getInputs('select');
  var children = $(formId).immediateDescendants();
  var select;
  for ( var i = 0; i < children.length; i++) {
    if ( children[i].tagName == 'SELECT' ) {
      select = children[i];
    }
  }
  var url = urls[ $F(select.id) ];

  var pars = "action=view"; // FIXME: maybe the directory could be sent

  var ajaxUpdate = new Ajax.Updater(
  {
  success: successId,
  failure: errorId
  },
  url,
      {
    method: 'post',
    parameters: pars,
    asynchronous: true,
        evalScripts: true,
        onSuccess: function(t) {
          restoreHidden(loadingId);
        },
    onFailure: function(t) {
      restoreHidden(loadingId);
    }
      }
  );

  setLoading(loadingId);

}


/*
Function: showSelected

        Show the HTML setter selected in select

Parameters:

        selectElement - HTMLSelectElement

*/
function showSelected (selectElement)
{

   var selectedValue = $F(selectElement);
   var options = selectElement.options;
   for (var i = 0; i < options.length; i++) {
     var option = options[i].value;
     var childId = selectElement.id + "_" + option + "_container";
     if (selectedValue == option) {
       show(childId);
     } else {
       hide(childId);
     }
   }
}

/*
Function: showPort

      Show port if it's necessary given a protocol

Parameters:

        protocolSelectId - the select identifier which the protocol is chosen
    portId   - the identifier where port is going to be set
    protocols - the list of protocols which need a port to be set

*/
function showPort(protocolSelectId, portId, protocols)
{

  var selectedIdx = $(protocolSelectId).selectedIndex;
  var selectedValue = $(protocolSelectId).options[selectedIdx].value;

  var found = false;
  // Search the selected value into the array to know if it needs a port or not
  for ( var idx = 0; idx < protocols.length && ! found; idx++) {
    if ( selectedValue == protocols[idx] ) {
      found = true;
      show(portId);
    }
  }

  if (! found) {
    hide(portId);
  }

}

/* TODO: showPortRange and showPort do things in common
     like showing/hiding elments depending on which value
     is selected elsewhere. We should refactor this
     and provide a generic function to do that. Logic should
     come from model and translated in javascript.
*/
/*
Function: showPortRange

    Show/Hide elements in PortRange view

Parameters:

    id - the select identifier which the protocol is chosen

*/
function showPortRange(id)
{

  var selectId = id + "_range_type";
  var selectedIdx = $(selectId).selectedIndex;
  var selectedValue = $(selectId).options[selectedIdx].value;

  if ( selectedValue == "range") {
    show(id + "_range");
    hide(id + "_single");
    $(id + "_single_port").value = "";
  } else if (selectedValue == "single") {
    hide(id + "_range");
    show(id + "_single");
    $(id + "_to_port").value = "";
    $(id + "_from_port").value = "";
  } else {
    hide(id + "_range");
    hide(id + "_single");
    $(id + "_to_port").value = "";
    $(id + "_from_port").value = "";
    $(id + "_single_port").value = "";
  }
}

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


function setLoading (elementId, modelName, isSaved)
{
  var element = $(elementId);
  if (isSaved) {
    savedElements[elementId] = element.innerHTML;
  }

  element.innerHTML = '<img src="/data/images/ajax-loader.gif" alt="loading..." class="tcenter"/>';
}



/*
Function: setDone

        Set the done icon (a tick) on the given HTML element erasing
        everything which were there.

Parameters:

        elementId - String the element identifier


*/
function setDone (elementId)
{

  $(elementId).innerHTML = "<img src='/data/images/apply.gif' " +
                           "alt='done' class='tcenter'/>";

}


/*
Function: restoreHidden

        Restore HTML stored in *hiddenDiv*

Parameters:

        elementId - the element identifier where to restore the HTML hidden
        modelName - the model name to distinguish among hiddenDiv tags

*/
function restoreHidden (elementId, modelName)
{
    if (savedElements[elementId] != null) {
        $(elementId).innerHTML = savedElements[elementId];
    } else {
        $(elementId).innerHTML = '';
    }
}

function restoreHiddenElement (element)
{
  var elementId = element.id;
  if (savedElements[elementId] != null) {
        element.innerHTML = savedElements[elementId];
    } else {
        element.innerHTML = '';
    }
}

/*
Function: disableInput

        Disable all inputs attached as children to the given element

Parameters:

        elementId - the element identifier where all input elements hang

*/
function disableInput(elementId)
{

  var children = $(elementId).childNodes;

  for (var idx = 0; idx < children.length; idx++) {
    // I'd like to use constant but in IE 6 simply they don't exist
    node = children[idx];
    if ( node.nodeType == 1 /* Node.ELEMENT_NODE */ ) {
      //      if ( typeof node == "HTMLInputElement" ) {

    node.disable = true;
    //}
    }
  }

}

/*
Function: highlightRow

        Enable/Disable a hightlight over an element on the table

Parameters:

        elementId - the row identifier to highlight
    enable    - if enables/disables the highlight *(Optional)*
                Default value: true

*/
function highlightRow(elementId, enable)
{

  // If enable has value null or undefined
  if ( enable == null) {
    enable = true;
  }
  if (enable) {
    // Highlight the element putting the CSS class which does so
    Element.addClassName(elementId, "highlight");
  }
  else {
    Element.removeClassName(elementId, "highlight");
  }

}

/*
Function: inputValue

    Return an input value. It firstly checks using $() if the id exits

Parameters:

    elementId - the input element to fetch the value from

Returns:

    input value if it exits, otherwise empty string
*/
function inputValue(elementId) {
    var $element = $(elementId);
    if ($element) {
        return $element.getValue();
    } else {
        return '';
    }
}

/*
Function: markFileToRemove

    This function is used along with the File view and setter to mark
    a file to be removed

Parameters:

    elementId - a EBox::Types::File id
*/
function markFileToRemove(id)
{
    $(id + '_remove').value = "1";
    hide(id + '_current');
}

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
function sendInPlaceBooleanValue(controller, model, id, dir, field, element)
{
    startAjaxRequest();
    cleanError(model);

    var parameters = new Hash();
    parameters.set('action', 'editBoolean');
    parameters.set('model', model);
    parameters.set('dir', dir);
    parameters.set('field', field);
    if ($F(element) == 'on') {
        parameters.set('value', 1);
    }
    parameters.set('id', id);

    hide(element.id);
    setLoading(element.id + '_loading');

    var MyAjax = new Ajax.Request(
        controller,
        {
            method: 'post',
            parameters: parameters,
            onFailure: function(t) {
              $('error_' + model).innerHTML = t.responseText;
              completedAjaxRequest();
              show(element.id);
              $(element.id + '_loading').innerHTML = '';
              element.checked = ! element.checked;
            },
            onSuccess: function(t) {
              eval(t.responseText);
              completedAjaxRequest();
              show(element.id);
              $(element.id + '_loading').innerHTML = '';

            }
        });

}
/*
Function: startAjaxRequest

    This function is used to mark we start an ajax request.
    This is used to help test using selenium, it modifies
    a dom element -request_cookie- to be able to know when
    an ajax request starts and stops.

*/
function startAjaxRequest()
{
    $('ajax_request_cookie').value = 1;
}

/*
Function: completedAjaxRequest

    This function is used to mark we finished an ajax request.
    This is used to help test using selenium, it modifies
    a dom element -request_cookie- to be able to know when
    an ajax request starts and stops.

*/
function completedAjaxRequest()
{
    $('ajax_request_cookie').value = 0;
}


function addSelectChoice(id, value, printableValue, selected)
{
    var selectControl = document.getElementById(id);
    if (!selectControl) {
      return;
    }
    var newChoice = new Option(printableValue, value);

    selectControl.options.add(newChoice);
    if (selected) {
        selectControl.options.selectedIndex = selectControl.options.length -1;
    }
}



function removeSelectChoice(id, value, selectedIndex)
{
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

}

function checkAllControlValue(url, table, directory, controlId, field)
{
    var pars = 'action=checkAllControlValue&tablename=' + table + '&directory=' + directory;
    pars += '&controlId=' + controlId  + '&field=' + field;
    pars +=  '&json=1';

    AjaxParams =  {
            method: 'post',
            parameters: pars,
            evalScripts: true,
            onComplete: function(t) {
              completedAjaxRequest();
              var json = t.responseText.evalJSON(true);
              $(controlId).checked = json.success;
            }
    };

    MyAjax = new Ajax.Request(
      url,
      AjaxParams
    );
}


function confirmationDialog(url, table, directory, actionToConfirm, elements)
{
  var wantDialog  = true;
  var dialogTitle = null;
  var dialogMsg = null;

  var pars = 'action=confirmationDialog' +  '&tablename=' + table + '&directory=' + directory;
  pars +='&actionToConfirm=' + actionToConfirm;
  for (var i=0; i < elements.length; i++) {
    var name = elements[i];
    var id = table + '_' + name;
    var el = $(id);
    pars +='&'+ name + '=';
    pars +=  encodeURIComponent(el.value);
  }

  var request = new Ajax.Request(url, {
        method: 'post',
        parameters: pars,
        asynchronous: false,
        onSuccess: function (t) {
           var json = t.responseText.evalJSON(true);
           if (json.wantDialog) {
             dialogTitle = json.title;
             dialogMsg = json.message;
           } else {
             wantDialog = false;
           }
        },
        onFailure: function(t) {
          dialogTitle = '';
          dialogMsg = 'Are you sure?';
        }

      }
    );

  return {
    'wantDialog' : wantDialog,
    'title': dialogTitle,
    'message': dialogMsg
   };
}

function showConfirmationDialog(params, acceptJS)
{
  var modalboxHtml = "<div class='warning'><p>" + params.message  +  '</p></div>';
  modalboxHtml += "</p></div><div class='tcenter'>";
  modalboxHtml += '<input type="button" value="OK" onclick=" Modalbox.hide();' + acceptJS +  '" />';
  modalboxHtml += "<input type='button' value='Cancel' onclick='Modalbox.hide()' />";
  modalboxHtml += "</div>";
  Modalbox.show(modalboxHtml, {'title' : params.title });
}

// Detect session loss on ajax request:
Ajax.Responders.register({
 onComplete: function(x,response) {
    if (response.status == 403) {
      location.reload(true);
        }
 }
});
