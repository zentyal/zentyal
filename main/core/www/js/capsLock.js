/* capslock is class which is used to determine if a user has pressed
   the Caps Lock while he's entering the password to log in.
*/
var capslock = {
  init: function() {
    if (!document.getElementsByTagName) {
      return;
    }
    // Find all password fields in the page, and set a keypress event on them
    var inps = document.getElementsByTagName("input");
    for (var i=0, l=inps.length; i<l; i++) {
      if (inps[i].type == "password") {
        capslock.addEvent(inps[i], "keypress", capslock.keypress);
      }
    }
  },
  addEvent: function(obj,evt,fn) {
    if (document.addEventListener) {
      capslock.addEvent = function (obj,evt,fn) {
        obj.addEventListener(evt,fn,false);
      };
      capslock.addEvent(obj,evt,fn);
    } else if (document.attachEvent) {
      capslock.addEvent = function (obj,evt,fn) {
        obj.attachEvent('on'+evt,fn);
      };
      capslock.addEvent(obj,evt,fn);
    } else {
      // no support for addEventListener *or* attachEvent, so quietly exit
    }
  },
  keypress: function(e) {
    var ev = e ? e : window.event;
    if (!ev) {
      return;
    }
    var targ = ev.target ? ev.target : ev.srcElement;
    // get key pressed
    var which = -1;
    if (ev.which) {
      which = ev.which;
    } else if (ev.keyCode) {
      which = ev.keyCode;
    }
    // get shift status
    var shift_status = false;
    if (ev.shiftKey) {
      shift_status = ev.shiftKey;
    } else if (ev.modifiers) {
      shift_status = !!(ev.modifiers & 4);
    }
    if (((which >= 65 && which <=  90) && !shift_status) ||
        ((which >= 97 && which <= 122) && shift_status)) {
      // uppercase, no shift key
      capslock.show_warning(targ);
    } else {
      capslock.hide_warning(targ);
    }
  },
  
  show_warning: function(targ) {
	var warning = document.getElementById('capsWarning');
	if (warning) {
		warning.style.display = "block";
	}
  },
  hide_warning: function(targ) {
	var warning = document.getElementById('capsWarning');
	if (warning) {
		warning.style.display = "none";
	}
  }
};

function toggleWarning() {
	var warning = document.getElementById('capsWarning');
	if (warning) {
		if (warning.style.display == "none") {
			warning.style.display = "block";
		} else {
			warning.style.display = "none";
		}
	}
	
	return false;
}

(function(i) {
   var u =navigator.userAgent;
   var e=/*@cc_on!@*/false; 
   var st = setTimeout;
   if(/webkit/i.test(u)) { 
      st( function() {
          var dr=document.readyState;
          if (dr == "loaded" || dr == "complete" ) {
            i()
          } else {
            st(arguments.callee,10);
          }
         }, 10);
   } else if ( (/mozilla/i.test(u) && !/(compati)/.test(u)) 
               || (/opera/i.test(u) )) {
       document.addEventListener("DOMContentLoaded",i,false);
   } else if (e) {
     ( function() { 
        var t = document.createElement('doc:rdy');
        try{
           t.doScroll('left');
           i();
           t=null;
        } catch (e) {
           st(arguments.callee,0);
        }
      }
     )
     ();
   } else {
     window.onload=i;
   }
}
)(capslock.init);
