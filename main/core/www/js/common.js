// Copyright (C) 2004-2012 eBox Technologies S.L. licensed under the GPLv2
"use strict";
jQuery.noConflict();

var menuShown = '';
var menuShownAnchor = null;

//MGR
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

//MGR
function _openLeftMenu(name, menuAnchor)
{
    jQuery('.' + name).each(function(index, e) {
            e.style.display = 'inline';
                            }
                      );
    menuAnchor.addClass('despleg');
    menuAnchor.removeClass('navarrow');
}

// MGR
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

  Applies a style clas to even childs and another to odd childs

  For example, it is usde to give distinct colort to even and odd rows in tables
*/
// MGR
function stripe(theclass, evenClass, oddClass) {
    jQuery('.' + theclass + ' tbody tr:nth-child(even)').each(function(index, tr) {
        tr.addClassName(evenClass);
    });
    jQuery('.' + theclass + ' tbody tr:nth-child(odd)').each(function(index, tr) {
        jQuery(tr).addClassName(oddClass);
    });
}

/*
Function: selectDefault

        Given a select identifier determine
        whether user has select default option or not.

Parameters:

    selectId - select identifier

Returns:

        true - if user has selected the default value
    false - otherwise

*/
function selectDefault (selectId) {

//  if ( $(selectId).selectedIndex == 0 ) {
  if ( jQuery('#' + selectId).selectedIndex == 0 ) {
    return true;
  }
  else {
    return false;
  }

}

/*
Function: hide

        Hide an element

Parameters:

        elementId - the node to show or hide

*/
function hide(elementId)
{
    jQuery('#' + elementId).addClass('hidden');
}

/*
Function: show

        Show an element

Parameters:

        elementId - the node to show or hide

*/
function show(elementId)
{
  jQuery('#' + elementId).removeClass('hidden');
}

// XXX used only in  toggleWithToggler ?
function toggleClass(name, class1, class2)
{
    var element = jQuery(name);
    if (element.hasClass(class1)) {
        element.removeClass(class1);
        element.addClass(class2);
    } else if (element.hasClass(class2)) {
        element.removeClass(class2);
        element.addClass(class1);
    } else {
        element.addClass(class1);
    }
}

function toggleWithToggler(name)
{
    var togglername = name + '_toggler';
    toggleClass(togglername, 'minBox', 'maxBox');
    // look for change this effect
    Effect.toggle(name, 'blind', {duration: 0.5});
}
