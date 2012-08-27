    "use strict";
    function tab1(){
        document.getElementById('installTab').className = 'current';
        document.getElementById('updateTab').className='';
        document.getElementById('deleteTab').className='';
        document.getElementById('installBox').show();
        document.getElementById('updateBox').hide();
        document.getElementById('deleteBox').hide();
    }

    function tab2(){
        document.getElementById('installTab').className = '';
        document.getElementById('updateTab').className='current';
        document.getElementById('deleteTab').className='';
        document.getElementById('installBox').hide();
        document.getElementById('updateBox').show();
        document.getElementById('deleteBox').hide();
    }

    function tab3(){
        document.getElementById('installTab').className = '';
        document.getElementById('updateTab').className='';
        document.getElementById('deleteTab').className='current';
        document.getElementById('installBox').hide();
        document.getElementById('updateBox').hide();
        document.getElementById('deleteBox').show();
    }

    var suites =  {
        'Gateway' : [ 'zentyal-network', 'zentyal-firewall', 'zentyal-squid', 'zentyal-trafficshaping', 'zentyal-l7-protocols',
                      'zentyal-users', 'zentyal-remoteservices', 'zentyal-monitor', 'zentyal-ca', 'zentyal-openvpn' ],
        'Infrastructure' : [ 'zentyal-network', 'zentyal-firewall', 'zentyal-dhcp', 'zentyal-dns', 'zentyal-openvpn',
                             'zentyal-webserver', 'zentyal-ftp', 'zentyal-ntp', 'zentyal-ca', 'zentyal-remoteservices' ],
        'Office' : [ 'zentyal-samba', 'zentyal-printers', 'zentyal-antivirus', 'zentyal-users', 'zentyal-firewall',
                     'zentyal-network', 'zentyal-remoteservices', 'zentyal-ca', 'zentyal-openvpn', 'zentyal-monitor' ],
        'Communications' : [ 'zentyal-mail', 'zentyal-jabber', 'zentyal-asterisk', 'zentyal-mailfilter', 'zentyal-users', 'zentyal-ca',
                             'zentyal-firewall', 'zentyal-network', 'zentyal-remoteservices', 'zentyal-openvpn', 'zentyal-monitor' ]
    };

    function showInfo(id){
        var items = ['Gateway', 'Infrastructure', 'Office', 'Communications', 'Install'];
        Effect.Appear(id, { duration : 0.2 });
        for (var i = 0; i < items.length; i++) {
            if (items[i] != id) {
                Effect.Fade(items[i], { duration : 0.2 });
            }
        }
    }

    function hideInfo(id) {
        Effect.Fade(id, { duration : 0.2 });
        Effect.Appear('Install', { duration : 0.2 });
    }

    function tick(id){
        document.getElementById(id+'_image_tick').show();
        document.getElementById(id+'_image').hide();
        document.getElementById(id+'_check').checked = true;

        var deps = suites[id];
        for (var i=0; i<deps.length; i++) {
            selectPackage(deps[i]);
        }
    }

    function untick(id, update_packages){
        document.getElementById(id+'_image_tick').hide();
        document.getElementById(id+'_image').show();
        document.getElementById(id+'_check').checked = false;

        if (update_packages) {
            var deps = suites[id];
            for (var i=0; i<deps.length; i++) {
                unselectPackage(deps[i], 1);
            }
        }

        for (var suite in suites) {
            var visible = $(suite+'_image_tick').visible();
            if (visible) tick(suite);
        }
    }

    function selected(id) {
      var element = $(id);
      if (element)   {
        return element.hasClassName('package_selected');
      }
      return false;
    }

    function selectPackage(id) {
      var element = $(id);
      if (element) {
         element.addClassName('package_selected');
      }
    }

    function unselectPackage(id, no_update_ticks) {
        var element = $(id);
        if (element) {
           element.removeClassName('package_selected');
           if (!no_update_ticks) updateTicks();
       }
    }

    function togglePackage(id) {
        if (selected(id)) {
            unselectPackage(id);
        } else {
            selectPackage(id);
        }
        updateTicks();
    }

    function updateTicks() {
        // add/remove ticks from suites after package unselection
        for (var suite in suites) {
            var isselected = true;
            for (var i=0; i<suites[suite].length; i++) {
                if (!selected(suites[suite][i])) {
                    untick(suite);
                    isselected = false;
                    break;
                }
            }
            if (isselected) tick(suite);
        }
    }


