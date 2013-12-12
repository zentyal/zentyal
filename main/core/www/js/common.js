// Copyright (C) 2004-2007 Warp Networks S.L
// Copyright (C) 2008-2012 Zentyal S.L. licensed under the GPLv2

var menuShown = '';
var menuShownAnchor = null;

function showMenu(name, menuAnchor){
  var open = false;
  if (menuShown === name) {
      menuShown = '';
      menuShownAnchor = null;
      _closeLeftMenu(name, menuAnchor);

  } else if (menuShown === '') {
    if (menuAnchor.hasClassName('despleg')) {
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
  $$('.' + name).each(function(e) {
                                  e.style.display = 'inline';
                            }
                      );
  menuAnchor.addClassName('despleg');
  menuAnchor.removeClassName('navarrow');
}


function _closeLeftMenu(name, menuAnchor)
{
  $$('.' + name).each(function(e) {
                                     e.style.display = 'none';
                                 }
                     );
  menuAnchor.addClassName('navarrow');
  menuAnchor.removeClassName('despleg');
}

/*
 */
function stripe(theclass,evenClass,oddClass) {
    $$('.' + theclass + ' tbody tr:nth-child(even)').each(function(tr) {
        tr.addClassName(evenClass);
    });
    $$('.' + theclass + ' tbody tr:nth-child(odd)').each(function(tr) {
        tr.addClassName(oddClass);
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

  if ( $(selectId).selectedIndex == 0 ) {
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
  Element.addClassName(elementId, 'hidden');
}

/*
Function: show

        Show an element

Parameters:

        elementId - the node to show or hide

*/
function show(elementId)
{
  Element.removeClassName(elementId, 'hidden');
}

function toggleClass(name, class1, class2)
{
    var element = $(name);
    if (element.hasClassName(class1)) {
        element.removeClassName(class1);
        element.addClassName(class2);
    } else if (element.hasClassName(class2)) {
        element.removeClassName(class2);
        element.addClassName(class1);
    } else {
        element.addClassName(class1);
    }
}

function toggleWithToggler(name)
{
    var togglername = name + '_toggler';
    toggleClass(togglername, 'minBox', 'maxBox');
    Effect.toggle(name, 'blind', {duration: 0.5});
}

function doReleaseUpgrade() {
    $('ok_button').hide();
    $('ajax_loader_upgrade').show();
    Modalbox.MBclose.hide()
    new Ajax.Request('/ReleaseUpgrade', {
        parameters: { upgrade: 1 },
        onSuccess: function(response) {
            window.location = '/ReleaseUpgrade?install=1';
        }
    });

}

