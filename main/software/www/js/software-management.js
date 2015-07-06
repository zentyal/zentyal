"use strict";

Zentyal.namespace('SoftwareManagementUI');

Zentyal.SoftwareManagementUI.showInstallTab = function() {
    $('#installTab').removeClass().addClass('current');
    $('#updateTab, #deleteTab').removeClass();
    $('#installBox').show();
    $('#updateBox, #deleteBox').hide();
};

Zentyal.SoftwareManagementUI.showUpdateTab = function (){
    $('#updateTab').removeClass().addClass('current');
    $('#installTab, #deleteTab').removeClass();
    $('#updateBox').show();
    $('#installBox, #deleteBox').hide();
};

Zentyal.SoftwareManagementUI.showDeleteTab = function (){
    $('#deleteTab').removeClass().addClass('current');
    $('#installTab, #updateTab').removeClass();
    $('#deleteBox').show();
    $('#installBox, #updateBox').hide();
};

Zentyal.SoftwareManagementUI.showInfo = function(id) {
    var idSel =  '#' + id;
    $(idSel).show(200);
    $('#Gateway, #Infrastructure, #Office, #Communications, #Install').not(idSel).hide(200);
};

Zentyal.SoftwareManagementUI.hideInfo = function (id) {
    $('#' + id).fadeOut(200);
    $('#Install').show(200);
};

Zentyal.SoftwareManagementUI.tick = function (id, update_packages){
    $('#' + id+ '_image_tick').show();
    $('#' + id+ '_image').hide();
    $('#' + id+ '_check').prop('checked', true);
};

Zentyal.SoftwareManagementUI.untick = function(id, update_packages){
    $('#' + id+'_image_tick').hide();
    $('#' + id+'_image').show();
    $('#' + id+'_check').prop('checked', false);
};

Zentyal.SoftwareManagementUI.selected = function(id) {
    return $('#' + id).hasClass('package_selected');
};

Zentyal.SoftwareManagementUI.selectPackage = function(id, no_update_ticks) {
    $('#' + id).addClass('package_selected');
};

Zentyal.SoftwareManagementUI.unselectPackage = function(id, no_update_ticks) {
    $('#' + id).removeClass('package_selected');
};

Zentyal.SoftwareManagementUI.togglePackage = function(id) {
    if (Zentyal.SoftwareManagementUI.selected(id)) {
        Zentyal.SoftwareManagementUI.unselectPackage(id);
    } else {
        Zentyal.SoftwareManagementUI.selectPackage(id);
    }
};

Zentyal.SoftwareManagementUI.checkAll = function(table, value, buttonId) {
    $('#' + table  + ' :checkbox').prop('checked', value);
    Zentyal.SoftwareManagementUI.updateActionButton(table, buttonId);
};

Zentyal.SoftwareManagementUI.sendForm = function(action, container, popup, title) {
    var packages = [];
    packages = $('#' + container + ' tbody :checked').map(function() {
         return 'pkg-' + this.getAttribute('data-pkg');
    }).get();
    Zentyal.SoftwareManagementUI._sendFormPackagesList(action, packages, popup, title);
};

Zentyal.SoftwareManagementUI.sendFormBasic = function(popup, title) {
    var packages = [];
    $('.package_selected').each(function (index, el) {
       packages.push('pkg-' + el.id);
    });

    Zentyal.SoftwareManagementUI._sendFormPackagesList('install', packages, popup, title);
};

Zentyal.SoftwareManagementUI._sendFormPackagesList = function(action, packages, popup, title) {
    var url  = '/Software/InstallPkgs',
        data = action + '=1';
   if (packages.length > 0) {
     for (var i=0; i < packages.length; i++) {
         data += '&' +  packages[i] + '=yes';
     }
     data += '&popup=' + popup;
     data = Zentyal.escapeHTTPQuery(data);

     if (popup) {
         Zentyal.Dialog.showURL(url, {'title': title, 'data': data});
     } else {
       window.location = url + '?' + data;
     }
  } else {
      alert('No packages selected');
  }
};

Zentyal.SoftwareManagementUI.updateActionButton = function(table, buttonId) {
    var allDisabled = $('#' + table + ' :checked').length === 0;
    $('#' + buttonId).prop('disabled', allDisabled);
};

Zentyal.SoftwareManagementUI.filterTable = function(tableId, filterId) {
    var trSel = '#' + tableId  + ' tbody tr';
    var tableTr =  $(trSel);
    var filterText = $('#' + filterId).val();

    filterText = $.trim(filterText).toLowerCase();
    if (filterText === '') {
        tableTr.show();
        Zentyal.stripe('.dataTable', 'even', 'odd');
        return;
    }

    tableTr.each(function (index, tr) {
        tr = $(tr);
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
