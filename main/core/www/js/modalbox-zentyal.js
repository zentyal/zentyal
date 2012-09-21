// This files modifies Modalbox to force zentyal styles
Modalbox.show = Modalbox.show.wrap(function (origFunc) {
//                                     var original = arguments[2].original;
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.original) {
                                           Modalbox.MBwindow.addClassName('MB_dialog');
                                     }
                                   });
Modalbox._setPosition = function() {
                                     Modalbox.MBwindow.setStyle({'left' : 'auto'});
                                   };
Modalbox.resize = Modalbox.resize.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.original) {
                                        Modalbox.MBwindow.setStyle({'height' : 'auto'});
                                      }
                                   });
Modalbox._putContent = Modalbox._putContent.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.original) {
                                          Modalbox.MBwindow.setStyle({'height' : 'auto'});
                                     }
                                   });
Modalbox._setWidth = Modalbox._setWidth.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     if (!this.options.original) {
                                         Modalbox.MBwindow.setStyle({'height' : 'auto'});
                                     }
                                   });