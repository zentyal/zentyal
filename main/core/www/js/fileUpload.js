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
 * Class: Zentyal.FileUpload
 *
 * This object manages a file upload using only JS and Asynchronous
 * requests. It is based on Ajax Iframe method from
 * www.webtoolkit.info. The method is based on storing the server
 * response on a Iframe element while the file is sent using a form
 * submitted when a change on the file input is done, i.e. when "browse"
 * action is finished.
 *
 * Adapted to be use with jQuery library
 *
 *
 */
"use strict";
/* Method: Zentyal.FileUpload constructor

     Create a Zentyal.FileUpload JS class to manage file upload

     Parameters:

     formId  - String the form identifier which stores the input file

     start - Function to be performed before submit the file

     complete - Function to be performed after completing the file
     submitting

     - Named parameters

     Returns:

     <Zentyal.FileUpload> - the recently created object

*/
Zentyal.FileUpload = function (params) {
    this.start = params.start;
    this.complete = params.complete;
    this.form = $('#' + params.formId);
    this.iframe = this._createIframe();
    this.form.attr('target', this.iframe.id);
    return this;
};


Zentyal.FileUpload.prototype = {
  /* Method: submit

     Submit the file

  */
  submit : function() {
    if ( this.start ) {
      this.start();
    }
    this.form.submit();
    return false;
  },

  // Method to create the iframe to store the server response
  // Returns the iframe created and already stored in the document
  _createIframe : function() {
    this.div = document.createElement('DIV');
    this.form.append(this.div);

    var iframe = document.createElement('IFRAME');
    var iframeId = 'iframe_' + Math.floor(Math.random() * 99999);
    iframe.setAttribute('id', iframeId);
    iframe.setAttribute('name', iframeId);
    iframe.setAttribute('src', 'about:blank');
    this.div.appendChild(iframe);

    var eventData = {complete: this.complete, iframe: iframe};
    $('#' + iframeId).hide().on('load', eventData, Zentyal.FileUpload.prototype._onIframeLoad);

    return iframe;
  },

  // Handler to manage when the iframe is loaded
  _onIframeLoad : function (event) {
    var iframe = event.data.iframe;
    var complete = event.data.complete;
    var doc;
    if ( iframe.contentDocument ) {
      doc = iframe.contentDocument;
    } else if ( iframe.contentWindow ) {
      doc = iframe.contentWindow.document;
    } else {
      doc = window.frames[iframe.id].document;
    }
    if ( doc.location.href == "about:blank" ) {
      return;
    }

    if ( typeof(complete == "function") ) {
      complete(doc.body.innerHTML);
      $(iframe).off('load', Zentyal.FileUpload.prototype._onIframeLoad);
    }

  }

}

