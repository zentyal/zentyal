// Copyright (C) 2004-2013 Zentyal S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

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
        }
    };
}

Zentyal.escapeSelector = function(selector)
{
    return  selector.replace(/([;&,\.\+\*\~':"\!\^#$%@\[\]\(\)=>\|])/g, '\\$1');
};

var menuShown = '';
var menuShownAnchor = null;

/*
function: showMenu

Open or closes the relevan section of the left menu

Parameters:
   name - name of the selected section
   menuAnchor - DOM object of the clicked menu anchor
*/
function showMenu(name, menuAnchor){
  menuAnchor = jQuery(menuAnchor);
  var open = false;
  if (menuShown === name) {
      menuShown = '';
      menuShownAnchor = null;
      _closeLeftMenu(name, menuAnchor);

  } else if (menuShown === '') {
    if (menuAnchor.hasClass('despleg')) {
      _closeLeftMenu(name, menuAnchor);
    } else {
      open = true;
    }
  } else {
     open = true;
     _closeLeftMenu(menuShown, menuShownAnchor);
  }

  if (open){
      menuShown = name;
      menuShownAnchor = menuAnchor;
      _openLeftMenu(name, menuAnchor);
  }
}

function _openLeftMenu(name, menuAnchor)
{
    jQuery('.' + name).each(function(index, e) {
            e.style.display = 'inline';
                            }
                      );
    menuAnchor.addClass('despleg');
    menuAnchor.removeClass('navarrow');
}

function _closeLeftMenu(name, menuAnchor)
{
  jQuery('.' + name).each(function(index, e) {
      e.style.display = 'none';
                             }
                    );
  menuAnchor.addClass('navarrow');
  menuAnchor.removeClass('despleg');
}

/*
Function: stripe

  Applies a styles class to tr elements childs of a CSS class; the class applied will be different
  for odd and even elements

  For example, it is usde to give distinct colort to even and odd rows in tables

  Parameters:
     theclass - css class which will vontain a tbody and tr to apply style
     evenClass - css class to apply to even tr
     oddClass - css class to apply to odd tr
*/
function stripe(theclass, evenClass, oddClass) {
    jQuery('.' + theclass + ' tbody tr:nth-child(even)').each(function(index, tr) {
        tr.addClassName(evenClass);
    });
    jQuery('.' + theclass + ' tbody tr:nth-child(odd)').each(function(index, tr) {
        tr.addClassName(oddClass);
    });
}

// XXX used only in the not-tottaly implemented data table sections feature
function toggleWithToggler(name)
{
    var togglername = name + '_toggler';
    var element = jQuery(name);
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
}
