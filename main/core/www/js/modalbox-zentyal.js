// This files modifies Modalbox to force zentyal styles
Modalbox._setPosition =  Modalbox.show.wrap(function (origFunc) {
                                     Modalbox.MBwindow.setStyle({'left' : 'auto'});
                                   });
