// Copyright (C) 2008-2013 Zentyal S.L. licensed under the GPLv2


/* *
 * * Bytes formatter for flot library
 * * @param float val  : the value to format
 * * @param axis  axis : flot axis object with information about the axis
 * */
function getBytesFormatter(val, axis) {
    if (typeof axis == "undefined") {
        precision = 2;
    } else {
        precision = axis.tickDecimals;
    }
    return getBytes(val, precision);
}

/* *
 * * Get the human-readable size for an amount of bytes
 * * @param int  size      : the number of bytes to be converted
 * * @param int  precision : number of decimal places to round to;
 * *                         optional - defaults to 2
 * * @param bool long_name : whether or not the returned size tag should
 * *                         be unabbreviated (ie "Gigabytes" or "GB");
 * *                         optional - defaults to true
 * * @param bool real_size : whether or not to use the real (base 1024)
 * *                         or commercial (base 1000) size;
 * *                         optional - defaults to true
 * * @return string        : the converted size
 * */
function getBytes(size,precision,longName,realSize) {
   if (typeof precision=="undefined") {
      precision=2;
   }
   if (typeof longName=="undefined") {
      longName=false;
   }
   if (typeof realSize=="undefined") {
      realSize=true;
   }
   var base=realSize?1024:1000;
   var pos=0;
   while (size>base) {
      size/=base;
      pos++;
   }
   var prefix=getSizePrefix(pos);
   var sizeName=longName?prefix+"bytes":prefix.charAt(0)+'B';
   sizeName=sizeName.charAt(0).toUpperCase()+sizeName.substring(1);
   var num=Math.pow(10,precision);
   return (Math.round(size*num)/num)+' '+sizeName;
}

/* *
 * * @param int pos : the distence along the metric scale relitive to 0
 * * @return string : the prefix
 * */
function getSizePrefix(pos) {
   switch (pos) {
      case  0: return "";
      case  1: return "kilo";
      case  2: return "mega";
      case  3: return "giga";
      case  4: return "tera";
      case  5: return "peta";
      case  6: return "exa";
      case  7: return "zetta";
      case  8: return "yotta";
      case  9: return "xenna";
      default: return "?-";
   }
}

function getDegrees(degrees) {
    return degrees + "°";
}

function getTimeDiff(milliseconds) {
    var pos = 0;
    var base = 1000;
    var timeDiff = milliseconds;
    while ( timeDiff > base ) {
        timeDiff /= base;
        pos++;
        if ( pos >= 1 ) {
            base = 60;
        }
        if ( pos > 2 ) {
            break;
        }
    }
    var num = Math.pow(10, 2);
    return ( Math.round( timeDiff * num) / num) + ' ' + getTimeDiffSuffix(pos);
    
}

function getTimeDiffSuffix(pos) {
    switch (pos) {
    case 0 : return "ms";
    case 1 : return "s";
    case 2 : return "min";
    default: return "h";
    }
}

// 8.toTimeDiffString()
// Example: 3700.toTimeDiffString() => 1 h 1 m 40 s
Number.prototype.toTimeDiffString = function() {
    var d = this;
    var h = Math.floor(d / 3600);
    var m = Math.floor(d % 3600 / 60);
    var s = Math.floor(d % 3600 % 60);
    return ((h > 0 ? h + " h " : "") + (m > 0 ? + m + " m " : (s > 0 ? "0 m " : "")) + (s > 0 ? + s + " s" : ""));
};

function getBytesPerSec(bps, axis) {
    return getBytesFormatter(bps, axis) + '/s';
}

function getTime(seconds) {
    var d = new Date(seconds * 1000);
    return d.toLocaleTimeString();
}

function getDate(seconds) {
    var d = new Date(seconds * 1000);
    return d.toLocaleDateString();
}

function getFullDate(seconds) {
    var d = new Date(seconds * 1000);
    return d.toLocaleString();
}

function getDateTime(seconds) {
    var d = new Date(seconds * 1000);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString();
}