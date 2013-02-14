// This files modifies Modalbox to force zentyal styles
Modalbox.show = Modalbox.show.wrap(function (origFunc) {
                                     "use strict";
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);

                                     if (this.options.wideWindow === true) {
                                       Modalbox.MBwindow.removeClassName('MB_dialog');
                                       Modalbox.MBwindow.addClassName('MB_widedialog');
                                     } else {
                                       Modalbox.MBwindow.removeClassName('MB_widedialog');
                                       Modalbox.MBwindow.addClassName('MB_dialog');
                                     }
                                     window.scrollTo(0, 0);
                                   });
Modalbox._setPosition = function() {
                                     Modalbox.MBwindow.setStyle({'left' : 'auto'});
                                   };
Modalbox.resize = Modalbox.resize.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.wideWindow) {
                                        Modalbox.MBwindow.setStyle({'height' : 'auto'});
                                      }
                                   });
Modalbox._putContent = Modalbox._putContent.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.wideWindow) {
                                          Modalbox.MBwindow.setStyle({'height' : 'auto'});
                                     }
                                   });
Modalbox._setWidth = Modalbox._setWidth.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.wideWindow) {
                                         Modalbox.MBwindow.setStyle({'height' : 'auto'});
                                     }
                                   });


Modalbox._hide =  Modalbox._hide.wrap(function (origFunc) {
                                   "use strict";
                                   var args = Array.prototype.slice.call(arguments, 1);
                                   origFunc.apply(Modalbox, args);
                                   this.options.wideWindow = false;
                                 });