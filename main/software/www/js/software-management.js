"use strict";
jQuery.noConflict();
Zentyal.namespace('SoftwareManagementUI');

Zentyal.SoftwareManagementUI.suites =  {
    'Gateway' : [ 'zentyal-network', 'zentyal-firewall', 'zentyal-squid', 'zentyal-trafficshaping', 'zentyal-l7-protocols',
                  'zentyal-users', 'zentyal-remoteservices', 'zentyal-monitor', 'zentyal-ca', 'zentyal-openvpn' ],
    'Infrastructure' : [ 'zentyal-network', 'zentyal-firewall', 'zentyal-dhcp', 'zentyal-dns', 'zentyal-openvpn',
                         'zentyal-webserver', 'zentyal-ftp', 'zentyal-ntp', 'zentyal-ca', 'zentyal-remoteservices' ],
    'Office' : [ 'zentyal-samba', 'zentyal-printers', 'zentyal-antivirus', 'zentyal-users', 'zentyal-firewall',
                 'zentyal-network', 'zentyal-remoteservices', 'zentyal-ca', 'zentyal-openvpn', 'zentyal-monitor' ],
    'Communications' : [ 'zentyal-mail', 'zentyal-jabber', 'zentyal-asterisk', 'zentyal-mailfilter', 'zentyal-users', 'zentyal-ca',
                         'zentyal-firewall', 'zentyal-network', 'zentyal-remoteservices', 'zentyal-openvpn', 'zentyal-monitor' ]
};

Zentyal.SoftwareManagementUI.showInstallTab = function() {
    jQuery('#installTab').removeClass().addClass('current');
    jQuery('#updateTab, #deleteTab').removeClass();
    jQuery('#installBox').show();
    jQuery('#updateBox, #deleteBox').hide();
};

Zentyal.SoftwareManagementUI.showUpdateTab = function (){
    jQuery('#updateTab').removeClass().addClass('current');
    jQuery('#installTab, #deleteTab').removeClass();
    jQuery('#updateBox').show();
    jQuery('#installBox, #deleteBox').hide();
};

Zentyal.SoftwareManagementUI.showDeleteTab = function (){
    jQuery('#deleteTab').removeClass().addClass('current');
    jQuery('#installTab, #updateTab').removeClass();
    jQuery('#deleteBox').show();
    jQuery('#installBox, #updateBox').hide();
};

Zentyal.SoftwareManagementUI.showInfo = function(id) {
    var idSel =  '#' + id;
    jQuery(idSel).show(200);
    jQuery('#Gateway, #Infrastructure, #Office, #Communications, #Install').not(idSel).hide(200);
};

Zentyal.SoftwareManagementUI.hideInfo = function (id) {
    jQuery('#' + id).fadeOut(200);
    jQuery('Install').show(200);
};

Zentyal.SoftwareManagementUI.tick = function (id, update_packages){
    jQuery('#' + id+ '_image_tick').show();
    jQuery('#' + id+ '_image').hide();
    jQuery('#' + id+ '_check').prop('checked', true);

     if (update_packages) {
         var deps = Zentyal.SoftwareManagementUI.suites[id];
         jQuery.each(deps, function(index, packageId) {
             Zentyal.SoftwareManagementUI.selectPackage(packageId, true);
         });
     }
};

Zentyal.SoftwareManagementUI.untick = function(id, update_packages){
    jQuery('#' + id+'_image_tick').hide();
    jQuery('#' + id+'_image').show();
    jQuery('#' + id+'_check').prop('checked', false);

    if (update_packages) {
        var otherSuitesPackages = {};
        for (var suite in Zentyal.SoftwareManagementUI.suites) {
            if (suite != id) {
                if (jQuery('#' + suite +'_check').prop('checked')) {
                    var suiteDeps = Zentyal.SoftwareManagementUI.suites[suite];
                    jQuery.each(suiteDeps, function(index, pkg) {
                         otherSuitesPackages[pkg] = true;
                    });
                }
            }
        }

        var deps =  Zentyal.SoftwareManagementUI.suites[id];
        jQuery.each(deps, function(index, pkg) {
            if (! (pkg in otherSuitesPackages)) {
                Zentyal.SoftwareManagementUI.unselectPackage(pkg, false);
            }
        });
    }
};

Zentyal.SoftwareManagementUI.selected = function(id) {
    return jQuery('#' + id).hasClass('package_selected');
};

Zentyal.SoftwareManagementUI.selectPackage = function(id, no_update_ticks) {
  jQuery('#' + id).addClass('package_selected');
  if (!no_update_ticks) {
       Zentyal.SoftwareManagementUI.updateTicks();
  }
};

Zentyal.SoftwareManagementUI.unselectPackage = function(id, no_update_ticks) {
    jQuery('#' + id).removeClass('package_selected');
    if (!no_update_ticks) {
         Zentyal.SoftwareManagementUI.updateTicks();
    }
};

Zentyal.SoftwareManagementUI.togglePackage = function(id) {
    if (Zentyal.SoftwareManagementUI.selected(id)) {
        Zentyal.SoftwareManagementUI.unselectPackage(id);
    } else {
        Zentyal.SoftwareManagementUI.selectPackage(id);
    }
    Zentyal.SoftwareManagementUI.updateTicks();
};

Zentyal.SoftwareManagementUI.updateTicks = function() {
    // add/remove ticks from suites after package (un)selection
    for (var suite in Zentyal.SoftwareManagementUI.suites) {
        var allSelected = true;
        var packages = Zentyal.SoftwareManagementUI.suites[suite];
        for (var i=0; i< packages.length; i++) {
            if (!Zentyal.SoftwareManagementUI.selected(packages[i])) {
                allSelected = false;
                break;
            }
        }
        if (allSelected) {
          Zentyal.SoftwareManagementUI.tick(suite, false);
        } else {
          Zentyal.SoftwareManagementUI.untick(suite, false);
        }
    }
};

Zentyal.SoftwareManagementUI.selectAll = function(table, actionButton) {
    jQuery('#' + table  + ' :checkbox').prop('checked', true);
    jQuery('#' + actionButton).prop('disabled', false);
};

Zentyal.SoftwareManagementUI.deselectAll = function(table, actionButton) {
    jQuery('#' + table  + ' :checkbox').prop('checked', false);
    jQuery('#' + actionButton).prop('disabled', true);
};

Zentyal.SoftwareManagementUI.sendForm = function(action, container, popup, title) {
    var packages = [];
    packages = jQuery('#' + container + ' :checked').map(function() {
         return 'pkg-' + this.getAttribute('data-pkg');
    }).get();
    Zentyal.SoftwareManagementUI._sendFormPackagesList(action, packages, popup);
};

Zentyal.SoftwareManagementUI.sendFormBasic = function(popup) {
    var packages = [];
    if (jQuery('#Gateway_check').prop('checked')) {
        packages.push('pkg-zentyal-gateway');
    }
    if (jQuery('#Office_check').prop('checked')) {
        packages.push('pkg-zentyal-office');
    }
    if (jQuery('#Communications_check').prop('checked')) {
        packages.push('pkg-zentyal-communication');
    }
    if (jQuery('#Infrastructure_check').prop('checked')) {
        packages.push('pkg-zentyal-infrastructure');
    }
    jQuery('.package:checked').each(function (index, el) {
       packages.push('pkg-' + el.attr('id'));
    });

    Zentyal.SoftwareManagementUI._sendFormPackagesList('install', packages, popup, title);
};

Zentyal.SoftwareManagementUI._sendFormPackagesList = function(action, packages, popup, title) {
   if (packages.length > 0) {
     var url= 'InstallPkgs?';
     for (var i=0; i < packages.length; i++) {
         url += action + '=1';
         url += '&' +  packages[i] + '=yes';
     }
     url += '&popup=' + popup;
     if (popup) {
         Modalbox.show(url, {'title': title, 'transitions': false});
     } else {
       window.location = url;
     }
  } else {
      alert('No packages selected');
  }
};

Zentyal.SoftwareManagementUI.updateActionButton = function(table, buttonId) {
    var allDisabled = jQuery('#' + table + ' :checked').length === 0;
    jQuery('#' + buttonId).prop('disabled', allDisabled);
};

Zentyal.SoftwareManagementUI.filterTable = function(tableId, filterId) {
    var trSel = '#' + tableId  + ' tbody tr';
    var tableTr =  jQuery(trSel);
    var filterText = jQuery('#' + filterId).val();

    filterText = jQuery.trim(filterText).toLowerCase();
    if (filterText === '') {
        tableTr.show();
        Zentyal.stripe('dataTable', 'even', 'odd');
        return;
    }

    tableTr.each(function (index, tr) {
        tr = jQuery(tr)
        if (tr.text().toLowerCase().indexOf(filterText) >= 0 ) {
            tr.show();
        } else {
            tr.hide();
            }
    });

    //stripe with visible status aware
    var visibleTr =  tableTr.filter(':visible');
    visibleTr.filter(':even').addClass('even').removeClass('odd');
    visibleTr.filter(':odd').addClass('odd').removeClass('even');
};
