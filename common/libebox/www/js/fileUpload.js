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
 * Class: EBox.FileUpload
 * 
 * This object manages a file upload using only JS and Asynchronous
 * requests. It is based on Ajax Iframe method from
 * www.webtoolkit.info. The method is based on storing the server
 * response on a Iframe element while the file is sent using a form
 * submitted when a change on the file input is done, i.e. when "browse"
 * action is finished.
 *
 * Adapted to be use with PrototypeJS library
 * 
 *
 */

if ( typeof(EBox) == 'undefined' ) {
  var EBox = {};
}

EBox.FileUpload = Class.create();

EBox.FileUpload.prototype = {

  /* Group: Public methods */
  /* 
     Constructor: initialize

     Create a EBox.FileUpload JS class to manage file upload

     Parameters:

     formId  - String the form identifier which stores the input file

     onStart - Function to be performed before submit the file

     onComplete - Function to be performed after completing the file
     submitting

     - Named parameters

     Returns:

     <EBox.FileUpload> - the recently created object

  */
  initialize : function(params) {
    this.onStart = params.onStart;
    this.onComplete = params.onComplete;
    this.form = $(params.formId);
    this.iframe = this._createIframe();
    this.form.setAttribute('target', this.iframe.id);
  },

  /* Method: submit

     Submit the file

  */
  submit : function() {
    if ( this.onStart ) {
      this.onStart();
    }
    this.form.submit();
    return false;
  },

  /* Group: Private methods */

  // Method to create the iframe to store the server response
  // Returns the iframe created and already stored in the document
  _createIframe : function() {
    this.div = document.createElement('DIV');
    var iframe = document.createElement('IFRAME');
    var iframeId = 'iframe_' + Math.floor(Math.random() * 99999);
    iframe.setAttribute('id', iframeId);
    iframe.setAttribute('name', iframeId);
    iframe.setAttribute('src', 'about:blank');
    Element.extend(iframe);
    iframe.hide();
    // To "cache" the bound functions so that observing is finished
    this.handler = EBox.FileUpload.prototype._onIframeLoad.bindAsEventListener(this);
    Event.observe(iframe, 'load', this.handler);
    // <div><iframe>...</iframe></div><form>...</form>
    this.div.appendChild(iframe);
    this.form.parentNode.appendChild(this.div);
    return iframe;
  },

  // Handler to manage when the iframe is loaded
  _onIframeLoad : function ( event ) {
    var doc;
    if ( this.iframe.contentDocument ) {
      doc = this.iframe.contentDocument;
    } else if ( this.iframe.contentWindow ) {
      doc = this.iframe.contentWindow.document;
    } else {
      doc = window.frames[this.iframe.id].document;
    }
    if ( doc.location.href == "about:blank" ) {
      return;
    }

    if ( typeof(this.onComplete) == "function" ) {
      this.onComplete(doc.body.innerHTML);
      // Remove everything created before
      // $(this.div).remove();
      Event.stopObserving(this.iframe, 'load', this.handler);
    }

  }
    
}

