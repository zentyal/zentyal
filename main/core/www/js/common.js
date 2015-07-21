// Copyright (C) 2004-2007 Warp Networks S.L.
// Copyright (C) 2008-2013 Zentyal S.L. licensed under the GPLv2
"use strict";

if (!('Zentyal' in  window)) {
    window.Zentyal = {
        namespace: function(ns) {
            var parts = ns.split("."),
            nsObject = this,
            i, len;

            for (i=0, len=parts.length; i < len; i++) {
                if (!nsObject[parts[i]]) {
                    nsObject[parts[i]] = {};
                }
                nsObject = nsObject[parts[i]];
            }

            return nsObject;
        },
        LeftMenu: {}
    };
}

function assert(condition, text) {
    if (!condition) {
        var exText = "Assert failed";
        if (text) {
            exText += ': ' + text;
        }
        console.trace();
        throw exText;
    }
}

Zentyal._httpQueryEscapes = {
    '<':'%3C',
    '>':'%3E',
    '#':'%23',
    '%':'%25',
    '{':'%7B',
    '}':'%7D',
    '|':'%7C',
    '\\':'%5C',
    '^':'%5E',
    '~':'%7E',
    '[':'%5B',
    ']':'%5D',
    '`':'%60',
    ';':'%3B',
    '@':'%40',
    '$':'%24',
    '+':'%2B',
    '"':'%22',
    ' ':'%20'
};

Zentyal._httpQueryEscaper = /[^\w=?&\/:-]/g;

Zentyal.escapeHTTPQuery = function(query) {
    query = '' + query;
    return query.replace(Zentyal._httpQueryEscaper, function(match) {
        if (match in Zentyal._httpQueryEscapes) {
            return Zentyal._httpQueryEscapes[match];
        } else {
            return match;
        }
  });
};

Zentyal.escapeSelector = function(selector) {
    return  selector.replace(/([;&,\.\+\*\~':"\!\^#$%@\[\]\(\)=>\|])/g, '\\$1');
};

Zentyal.refreshSaveChangesButton = function() {
    $.getJSON('/SysInfo/HasUnsavedChanges',  function(response) {
                Zentyal.setSaveChangesButton(response.changed);
             }
    );
};

Zentyal.pageReload = function() {
    var url,
    urlParts = window.location.href.split('?');
    url = urlParts[0];
    // Remove hash part, otherwise it won't reload
    url = url.replace(window.location.hash, "");
    if (urlParts.length >= 2) {
        var i,
        params,
        noActionParams = ['directory', 'page', 'pageSize', 'backview'];
        url += '?';
        params = urlParts[1].split('&');
        for (i=0;i < params.length; i++) {
            var par = params[i];
            for (i=0; i < noActionParams.length; i++) {
                if (par.indexOf(noActionParams[i] + '=') === 0) {
                    url += params[i] + '&';
                    break;
                }
            }
        }
    }
    window.location.replace(url);
};

Zentyal.setSaveChangesButton = function(changed) {
    var className = changed ?  'changed' : 'notchanged';
    $('#changes_menu').removeClass().addClass(className);
};


/*
Function: stripe

  Applies a styles class to tbody > tr elements childs of the elements of a jQuery collection;
  the class applied will be different   for odd and even elements

  For example, it is usde to give distinct colort to even and odd rows in tables

  Parameters:
     selector - jQuery selector which will contain a tbody and tr to apply style
     evenClass - css class to apply to even tr
     oddClass - css class to apply to odd tr
*/
Zentyal.stripe = function (selector, evenClass, oddClass) {
    var collection = $(selector);
    collection.find('tbody tr:nth-child(even)').removeClass(oddClass).addClass(evenClass);
    collection.find('tbody tr:nth-child(odd)').removeClass(evenClass).addClass(oddClass);
};

//** Zentyal.LetfMenu namespace **\\

Zentyal.LeftMenu.menuShown = '';
Zentyal.LeftMenu.menuShownAnchor = null;

/*
function: showMenu

Open or closes the relevan section of the left menu

Parameters:
   name - name of the selected section
   menuAnchor - DOM object of the clicked menu anchor
*/
Zentyal.LeftMenu.showMenu = function(name, menuAnchor){
  menuAnchor = $(menuAnchor);
  var open = false;
  if (Zentyal.LeftMenu.menuShown === name) {
      Zentyal.LeftMenu.menuShown = '';
      Zentyal.LeftMenu.menuShownAnchor = null;
      Zentyal.LeftMenu._close(name, menuAnchor);

  } else if (Zentyal.LeftMenu.menuShown === '') {
    if (menuAnchor.hasClass('despleg')) {
      Zentyal.LeftMenu._close(name, menuAnchor);
    } else {
      open = true;
    }
  } else {
     open = true;
     Zentyal.LeftMenu._close(Zentyal.LeftMenu.menuShown, Zentyal.LeftMenu.menuShownAnchor);
  }

  if (open){
      Zentyal.LeftMenu.menuShown = name;
      Zentyal.LeftMenu.menuShownAnchor = menuAnchor;
      Zentyal.LeftMenu._open(name, menuAnchor);
  }
};

Zentyal.LeftMenu._open = function(name, menuAnchor) {
    $('.' + name + ' .submenu').slideDown(200);
    menuAnchor.addClass('despleg');
    menuAnchor.removeClass('navarrow');
};

Zentyal.LeftMenu._close = function(name, menuAnchor) {
    $('.' + name + ' .submenu').slideUp(200);
    menuAnchor.addClass('navarrow');
    menuAnchor.removeClass('despleg');
};

// XXX used only in the not-tottaly implemented data table sections feature
Zentyal.toggleWithToggler = function(name) {
    var togglername = name + '_toggler';
    var element = $(name);
    if (element.hasClass('minBox')) {
        element.removeClass('minBox');
        element.addClass('maxBox');
    } else if (element.hasClass('maxBox')) {
        element.removeClass('maxBox');
        element.addClass('minBox');
    } else {
        element.addClass('minBox');
    }
    element.hide('blind');
};

Zentyal.namespace('HA');

Zentyal.HA.replicate = function(node) {
    $.ajax({
        url: '/HA/RetryReplication',
        type: 'post',
        dataType: 'json',
        data: { 'node': node },
        complete: function(response) {
            if (response.responseJSON && ('error' in response.responseJSON)) {
                //TODO: set error on table instead of alert
                //Zentyal.TableHelper.setError('Nodes', response.responseJSON.error);
                alert(response.responseJSON.error);
            }
            window.location.reload();
        }
    });
};
