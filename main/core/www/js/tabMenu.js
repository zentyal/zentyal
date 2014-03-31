/*
 * Copyright (C) 2007 Warp Networks S.L.
 * Copyright (C) 2008-2013 Zentyal S.L.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2, as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Class: Zentyal.Tabs
 *
 * This object creates a tab group to manage using CSS and JavaScript.
 *
 *
 */
"use strict";


/*
   Zentyal.tabs constructor

   Create a Zentyal. Tabs JS class to manage a tab group

   Parameters:

   tabContainer - String the tab container identifier from where the tabs hang
   modelAttrs   - Associative array indexing by element identifier
                  containing the following properties:
                   action -  URL for the actions to perform by an AJAX request
                   additionalParams - array containing associative arrays with
                                      the following elements:
                       name  - String the param's name
                       value - String the param's value
                   directory - a parameter to send specific for the tab model
   options      - Associate array which can contain the following
                  optional parameters:
                  - activeClassName : String the CSS class name to the active tab
                  - defaultTab : String the name of the default tab
                                 or first or last
   Returns:

   <Zentyal.Tabs> - the recently created object

*/
Zentyal.Tabs =  function(tabContainer, modelAttrs, options) {
    // The div where the tabs are
    this.tabContainer = $('#' + tabContainer);
    // Set the tabMenu name
    var nameParts = tabContainer.split('_');
    this.tabName = nameParts[1];

    this.activeTab = false;
    this.activeTabIdx = -1;
    this.tabs = [];
    // The object where the action URLs are stored, indexed by model name
    this.modelAttrs = modelAttrs;
    // Create a form to send the parameters when requestign a new tab
    this._createForm();

    if ( options && options.activeClassName ) {
      this.activeClassName = options.activeClassName;
    } else {
      // Default CSS active class name
      this.activeClassName = 'current';
    }

    if ( options && options.defaultTab ) {
      this.defaultTab = options.defaultTab;
    } else {
      // Default tab to show
      this.defaultTab = 'first';
    }

    // Menu stores all the A hrefs children from the div tab given
    this.tabs = this.tabContainer.find('a');

    var that = this;
    this.tabs.each( function(index, linkElement) {
        that._setupTab(that, linkElement);
    });

    if ( this.defaultTab == 'first' ) {
      this.activeTab = this.tabs.first();
      this.activeTabIdx = 0;
    } else if ( this.defaultTab == 'last' ) {
      this.activeTab = this.tabs.last();
      this.activeTabIdx = this.tabs.length - 1;
    } else {
        tabs.each(function(index, tab) {
            if (tab.id === options.defaultTab) {
                this.activeTab = $(tab);
                this.activeTabIdx = index;
                return false;
            }
        });
      }
    return this;
};

Zentyal.Tabs.prototype = {
  /* Method: showActiveTab

     Show the current active tab

     Parameters:

     linkElement - Extended element which contains the link to load
     the tab container
     *or*
     tabName     - String the link name whose element contains the
     link to load the tab

  */
  showActiveTab : function(tab) {
      if ( (! tab) || (tab.length === 0) ) {
          // If no tab is passed, then return silently
          return;
      }

    if ( typeof( tab ) === 'string' ) {
      // Search for the element whose id is call tab
      for ( var idx = 0, len = this.tabs.length; idx < len; idx++) {
        if ( this.tabs[idx].id == tab ) {
          this.showActiveTab(this.tabs[idx]);
          return;
        }
      }
    } else {
        // Hide the no-active tabs
        this.tabs.not(tab).removeClass(this.activeClassName);
        this.activeTab = $(tab);
        // Show the tab
        this.activeTab.addClass(this.activeClassName);
        // Set the correct form values
        var activeTabDir = this.modelAttrs[this.activeTab.attr('id')].directory;
        this._setTableFormInput('directory', activeTabDir);
        this._setAdditionalParams();

        // Load the content from table-helper
        Zentyal.TableHelper.hangTable( 'tabData_' + this.tabName ,
                   'errorTabData_' + this.tabName,
                   this.modelAttrs[ this.activeTab.attr('id') ].action,
                   'tableForm',
                   'tabData_' + this.tabName);
    }
  },

  /* Method: next

     Show the next tab. If the last one, it does nothing.

  */
  next : function () {

    if ( this.activeTabIdx == this.tabs.length ) {
      return;
    }
    this.activeTabIdx++;
    this.activeTab = this.tabs[this.activeTabIdx];
    this.showActiveTab( this.activeTab );

  },

  /* Method: previous

     Show the previous tab. If the first one, it does nothing.

  */
  previous : function () {

    if ( this.activeTabIdx === 0 ) {
      return;
    }

    this.activeTabIdx--;
    this.activeTab = this.tabs[this.activeTabIdx];
    this.showActiveTab( this.activeTab );
  },

  /* Method: first

     Show the first tab.

  */
  first : function () {

    this.activeTabIdx = 0;
    this.activeTab = this.tabs[this.activeTabIdx];
    this.showActiveTab( this.activeTab );
  },

  /* Method: last

     Show the last tab.

  */
  last : function () {

    this.activeTabIdx = this.tabs.length - 1;
    this.activeTab = this.tabs[this.activeTabIdx];
    this.showActiveTab( this.activeTab );
  },

  /* Method: _setupTab

     Add the the link element to the Zentyal.Tabs object and setup it

     Parameters:
     that        - Zentyal.Tabs object
     linkElement - Element the extended element which it is the <a> element

  */
    _setupTab : function(that, linkElement) {
        var key = linkElement.hash.substring(1)
        linkElement = $(linkElement);
        // Create the property key to call by user url#<key>
        linkElement.attr('key', key);
        linkElement.on('click', function(event) {
            that.showActiveTab(linkElement);
            return false;
        });
    },

  /* Method: _createForm

     Create the form to send parameters

  */
  _createForm : function () {
    // Create the form inputs
    var actionInput = document.createElement('INPUT');
    actionInput.setAttribute('name', 'action');
    actionInput.setAttribute('type', 'hidden');
    actionInput.setAttribute('value', 'view');
    // Create Form element
    var form = document.createElement('FORM');
    form.setAttribute( 'id', 'tableForm');
    form.appendChild( actionInput );
    // Append the form to the body
    this.tabContainer.parent().append(form);
  },

  /* Method: _setAdditionalParams

     Set the additional parameters to be sent in POST request.

  */
  _setAdditionalParams : function() {
      var activeTabId = this.activeTab.attr('id');
      // Check if additionalParams is defined

      if ( this.modelAttrs[activeTabId].additionalParams ) {
          for(var i=0; i < this.modelAttrs[activeTabId].additionalParams.length; i++) {
              var param = this.modelAttrs[activeTabId].additionalParams[i];
              this._setTableFormInput(param.name, param.value);
          }
      }
  },

  /* Method: _setTableFormInput

     Set the table form input value from the selected tab in order to
     make the POST request dynamically.
  */
  _setTableFormInput : function(name, value) {
      var input = $('#tableForm [name=' + name + ']');
      if ( input.length > 0 ) {
          // Input is defined
          input.attr('value', value);
      } else {
          // Create the input
          var tformInput = document.createElement('input');
          tformInput.setAttribute('name', name);
          tformInput.setAttribute('id', name);
          tformInput.setAttribute('type', 'hidden');
          tformInput.setAttribute('value', value);
          $('#tableForm').append(tformInput);
      }
  }

};
