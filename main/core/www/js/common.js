// Copyright (C) 2004-2012 eBox Technologies S.L. licensed under the GPLv2

/**
function setDefault(){
//    var elements=getElementByClass("hide");
    var elements = $$('.hide');
    var inc=0;
    while (elements[inc]){
        elements[inc].style.display="none";
        inc++;
    }
    inc=0;
//    elements = $$('.show');
    elements=getElementByClass("show");
    while (elements[inc]){
        elements[inc].style.display="inline";
        inc++;
    }
}

function show(id){
    setDefault();
    document.getElementById(id).style.display="block";
    document.getElementById("hideview" + id).style.display="none";
    document.getElementById("showview" + id).style.display="inline";
}

function hide(id){
    setDefault();
}

**/

var menuShown = '';

function showMenu(name, menuAnchor){
    if (menuShown === name) {
      menuShown = '';
      $$('.' + name).each(function(e) {
                                     e.style.display = 'none';
                                 }
                               );
      menuAnchor.addClassName('navarrow');
      menuAnchor.removeClassName('despleg');
    } else {
      menuShown = name;
      $$('.' + name).each(function(e) {
                                  e.style.display = 'inline';
                            }
                           );
      menuAnchor.addClassName('despleg');
      menuAnchor.removeClassName('navarrow');
   }
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
