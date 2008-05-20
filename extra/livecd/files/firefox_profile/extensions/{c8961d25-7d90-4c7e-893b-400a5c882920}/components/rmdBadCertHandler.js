/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Remember Mismatched Domains
 *
 * The Initial Developer of the Original Code is
 * Andrew Lucking.
 * http://www.andrewlucking.com/
 * Portions created by the Initial Developer are Copyright (C) 2007
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** */

const CLASS_ID = Components.ID("{6563f890-ccfe-11db-8314-0800200c9a66}");
const CLASS_NAME = "RMD";
const CONTRACT_ID = "@andrewlucking.com/rmdBadCertHandler;1";

/** class **/
function rmdBadCertHandler() { };
rmdBadCertHandler.prototype = {

    confirmMismatchDomain: function(socketInfo, targetURL, cert) {
	var certpick = Components.classes["@mozilla.org/nsCertPickDialogs;1"]
                            .getService(Components.interfaces.nsIBadCertListener);

	return this._isRemembered("DOMAINMISMATCH", targetURL, cert) ||
			certpick.confirmMismatchDomain(socketInfo, targetURL, cert);
    },

    confirmCertExpired: function(socketInfo, cert) {
	var certpick = Components.classes["@mozilla.org/nsCertPickDialogs;1"]
                            .getService(Components.interfaces.nsIBadCertListener);

	return this._isRemembered("SERVERCERTEXPIRED", "", cert) ||
			certpick.confirmCertExpired(socketInfo, cert);
    },

    confirmUnknownIssuer: function(socketInfo, cert, certAddType) {
	var certpick = Components.classes["@mozilla.org/nsCertPickDialogs;1"]
                            .getService(Components.interfaces.nsIBadCertListener);
	return certpick.confirmUnknownIssuer(socketInfo, cert, certAddType);
    },

    notifyCrlNextupdate: function(socketInfo, targetURL, cert) {
	var certpick = Components.classes["@mozilla.org/nsCertPickDialogs;1"]
                            .getService(Components.interfaces.nsIBadCertListener);
	return certpick.notifyCrlNextupdate(socketInfo, targetURL, cert);
    },

    QueryInterface: function(aIID)  {
        if (!aIID.equals(Components.interfaces.rmdIBadCertHandler) &&
            !aIID.equals(Components.interfaces.nsISupports)) {
                throw Components.results.NS_ERROR_NO_INTERFACE;
        } else {
            return this;
        }
    },
       // handler_type:    "DOMAINMISMATCH" or "SERVERCERTEXPIRED"
    _isRemembered: function (handler_type, target_url, cert) {
        var prefs = Components.classes["@mozilla.org/preferences-service;1"].
                    getService(Components.interfaces.nsIPrefBranch);

        var bypass_dialog = false;
        var pref_name = "";

                // which prefs are we after
        if (handler_type == "DOMAINMISMATCH"){
            pref_name = "remember_mismatched_domains.domain_pairs"; // use domain pairs prefs
        } else if (handler_type == "SERVERCERTEXPIRED"){
            pref_name = "remember_mismatched_domains.expired_pairs";  // use expired pairs prefs
        }

        // gather prefs
        var domain_pairs = "";
        if (prefs.getPrefType(pref_name) == prefs.PREF_STRING) domain_pairs = prefs.getCharPref(pref_name);
        var pairs_array = domain_pairs.split(" ");

        for (var i in pairs_array){
            var cert_data = pairs_array[i].split(":")[0]; // either domain or date
            cert_data = unescape(cert_data);
            var cert_url = pairs_array[i].split(":")[1];
            cert_url = unescape(cert_url);
            var cert_fingerprint_sha1 = pairs_array[i].split(":")[2]; // sha1 (as stored)
            cert_fingerprint_sha1 = unescape(cert_fingerprint_sha1);
            var cert_fingerprint_md5 = pairs_array[i].split(":")[3]; // md5 (as stored)
            cert_fingerprint_md5 = unescape(cert_fingerprint_md5);

            if (handler_type == "DOMAINMISMATCH"){
                if (cert_data == target_url &&
                    cert_url == cert.commonName &&
                    cert_fingerprint_sha1 == cert.sha1Fingerprint &&
                    cert_fingerprint_md5 == cert.md5Fingerprint){
                        dump("RMD :: mismatch remembered\n");
                        bypass_dialog = true;
                        break;
                }
            } else if (handler_type == "SERVERCERTEXPIRED"){
                if (cert_data == cert.validity.notAfter &&
                    cert_url == cert.commonName &&
                    cert_fingerprint_sha1 == cert.sha1Fingerprint &&
                    cert_fingerprint_md5 == cert.md5Fingerprint){
                        dump("RMD :: expired remembered\n");
                        bypass_dialog = true;
                        break;
                }
            }
        }
      return bypass_dialog;
    }
};

/** class factory **/
var rmdBadCertHandlerFactory = {
  createInstance: function (aOuter, aIID)  {
    if (aOuter != null)
      throw Components.results.NS_ERROR_NO_AGGREGATION;
    return (new rmdBadCertHandler()).QueryInterface(aIID);
  }
};

/** module defined - xpcom registration **/
var rmdBadCertHandlerModule = {
  _firstTime: true,
  registerSelf: function(aCompMgr, aFileSpec, aLocation, aType)  {
    aCompMgr = aCompMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
    aCompMgr.registerFactoryLocation(CLASS_ID, CLASS_NAME, CONTRACT_ID, aFileSpec, aLocation, aType);
  },

  unregisterSelf: function(aCompMgr, aLocation, aType) {
    aCompMgr = aCompMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
    aCompMgr.unregisterFactoryLocation(CLASS_ID, aLocation);
  },

  getClassObject: function(aCompMgr, aCID, aIID)  {
    if (!aIID.equals(Components.interfaces.nsIFactory))
      throw Components.results.NS_ERROR_NOT_IMPLEMENTED;

    if (aCID.equals(CLASS_ID))
      return rmdBadCertHandlerFactory;
    throw Components.results.NS_ERROR_NO_INTERFACE;
  },

  canUnload: function(aCompMgr) { return true; }
};

/** module init **/
function NSGetModule(aCompMgr, aFileSpec) { return rmdBadCertHandlerModule; }
