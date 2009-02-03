/*
 * Copyright (C) 2007 Warp Networks S.L.
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
 * Class: EBox.Tabs
 * 
 * This object creates a tab group to manage using CSS and JavaScript.
 * 
 *
 */

if ( typeof(EBox) == 'undefined' ) {
  var EBox = {};
}

EBox.Tabs = Class.create();

EBox.Tabs.prototype = {

  /* 
     Constructor: initialize
     
     Create a EBox.Tabs JS class to manage a tab group

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
     
     <EBox.Tabs> - the recently created object

  */

  initialize : function(tabContainer, modelAttrs, options) {
    // The div where the tabs are
    this.tabContainer = $(tabContainer);
    // Set the tabMenu name
    var nameParts = tabContainer.split('_');
    this.tabName = nameParts[1];
    // Set the active tab
    this.activeTab = false;
    this.activeTabIdx = -1;
    // The tabs
    this.tabs = [];
    // The object where the action URLs are stored, indexed by model name
    this.modelAttrs = modelAttrs;
    // Create a form to send the parameters
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
    var tabs = this.tabContainer.getElementsBySelector('a');
    // Add the onclick function
    tabs.each( function(linkElement) {
      this._addTab(linkElement);
    }.bind(this));

    if ( this.defaultTab == 'first' ) {
      this.activeTab = this.tabs.first();
      this.activeTabIdx = 0;
    } else if ( this.defaultTab == 'last' ) {
      this.activeTab = this.tabs.last();
      this.activeTabIdx = this.tabs.length;
    } else {
      for( var idx = 0, len = this.tabs.length; idx < len; idx++ ) {
        if ( this.tabs[idx].id == options.defaultTab ) {
          this.activeTab = this.tabs[idx];
          this.activeTabIdx = idx;
        }
      }     
    }

    // Show default tab (Done at the template)
//    if ( this.defaultTab == 'first' ) {
//      this.showActiveTab( this.tabs.first() );
//    } else if ( this.defaultTab == 'last' ) {
//      this.showActiveTab( this.tabs.last() );
//    } else {
//      this.showActiveTab( this.defaultTab );
//    }
                   
  },

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
    if ( ! tab ) {
      // If no tab is passed, then return silently
      return;
    }

    if ( typeof( tab ) == 'string' ) {
      // Search for the element whose id is call tab
      for ( var idx = 0, len = this.tabs.length; idx < len; idx++) {
        if ( this.tabs[idx].id == tab ) {
          this.showActiveTab(this.tabs[idx]);
          return;
        }          
      }
    } else {
      // Hide the remainder tabs
      this.tabs.without(tab).each( function(linkElement) {
        linkElement.removeClassName( this.activeClassName );
      }.bind(this));
      // Set the current active tab
      this.activeTab = tab;
      // Show the tab
      tab.addClassName(this.activeClassName);
      // Set the correct form values
        this._setDirInput();
      // Set additional parameters
      this._setAdditionalParams();
      // Load the content from table-helper
      hangTable( 'tabData_' + this.tabName , 'errorTabData_' + this.tabName,
                 this.modelAttrs[ tab.id ].action, 'tableForm',
                 'tabData_' + this.tabName
               );
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

    if ( this.activeTabIdx == 0 ) {
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


  /* Group: Private method */
  
  /* Method: _addTab

     Add the the link element to the EBox.Tabs object

     Parameters:

     linkElement - Element the extended element which it is the <a> element

  */
    _addTab : function(linkElement) {
      // Add the tab to the this.tabs array in order to manage hrefs
      this.tabs.push(linkElement);
      // Create the property key to call by user url#<key>
      linkElement.key = linkElement.hash.substring(1);

      var clickHandler = function(linkElement) {
        if ( window.event ) {
          Event.stop( Window.event );
        }
        this.showActiveTab(linkElement);
        return false;
      }.bind(this, linkElement);

      Event.observe( linkElement, 'click', clickHandler);
      
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
    this.tabContainer.parentNode.appendChild(form);

  },

  /* Method: _setDirInput

     Set the directory input value from the selected tab in order to
     make the POST request dynamically. It will replace any previous
     directory input value if any.

  */
  _setDirInput : function() {

    var input = $('tableForm')['directory'];
    if ( input ) {
      // Input is defined
      input.setAttribute('value', this.modelAttrs[this.activeTab.id].directory);
    } else {
      // Create the input
      var dirInput = document.createElement('input');
      dirInput.setAttribute('name', 'directory');
      dirInput.setAttribute('type', 'hidden');
      dirInput.setAttribute('value', this.modelAttrs[this.activeTab.id].directory);
      $('tableForm').appendChild(dirInput);
    }
  },

  /* Method: _setAdditionalParams

     Set the additional parameters to be sent in POST request.

  */
  _setAdditionalParams : function() {

    // Check if additionalParams is defined
    if ( this.modelAttrs[this.activeTab.id].additionalParams ) {
      for(var idx=0; idx < this.modelAttrs[this.activeTab.id].additionalParams.length; idx++) {
        var param = this.modelAttrs[this.activeTab.id].additionalParams[idx];
        var input = $('tableForm')[param.name];
        if ( input ) {
          // Input is defined
          input.setAttribute('value', param.value);
        } else {
          // Create the input
          var dirInput = document.createElement('input');
          dirInput.setAttribute('name', param.name);
          dirInput.setAttribute('type', 'hidden');
          dirInput.setAttribute('value', param.value);
          $('tableForm').appendChild(dirInput);
        }
      } 
    }
  }
    
}
