// This files modifies Modalbox to allow zentyal styles



Modalbox.show = Modalbox.show.wrap(function (origFunc) {
                                     var args = Array.prototype.slice.call(arguments, 1);
                                     origFunc.apply(Modalbox, args);
                                     Modalbox.MBwindow.setStyle({'left' : 'auto'});
                                     Modalbox.MBwindow.addClassName('MB_dialog');
                                   });

