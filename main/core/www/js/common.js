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
        },
        LeftMenu: {}
    };
}

Zentyal.escapeSelector = function(selector) {
    return  selector.replace(/([;&,\.\+\*\~':"\!\^#$%@\[\]\(\)=>\|])/g, '\\$1');
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
    var collection = jQuery(selector);
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
  menuAnchor = jQuery(menuAnchor);
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
    jQuery('.' + name).each(function(index, e) {
            e.style.display = 'inline';
                            }
                      );
    menuAnchor.addClass('despleg');
    menuAnchor.removeClass('navarrow');
};

Zentyal.LeftMenu._close = function(name, menuAnchor) {
  jQuery('.' + name).each(function(index, e) {
      e.style.display = 'none';
                             }
                    );
  menuAnchor.addClass('navarrow');
  menuAnchor.removeClass('despleg');
};

// XXX used only in the not-tottaly implemented data table sections feature
Zentyal.toggleWithToggler = function(name) {
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
};
