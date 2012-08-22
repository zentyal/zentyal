// This files modifies Modalbox to force zentyal styles
Modalbox.show = Modalbox.show.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     Modalbox.MBwindow.addClassName('MB_dialog');
                                   });
Modalbox._setPosition = function() {
                                     Modalbox.MBwindow.setStyle({'left' : 'auto'});
                                   };
