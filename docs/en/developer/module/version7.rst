=======================
Version 0.7: composites
=======================

So far we have three different models with three different menu entries that help us to show their default views. It would be nice to be able to tell the framework to render the some modules together, using a given layout. That's where *Composites* come in handy. *Composites* help us to group our model views.

Composite view
==============

There is already a default composite created with *emoddev*. This composite is configured with a top-bottom layout. However, its model list is empty. We will have to populate it with our models. The default composite lives in *src/EBox/Composite/Composite.pm*. We should add our models to *components* and set *printableName* to *Apache2 configuration*. This is how this file should then look::

    #!perl
    # Class: EBox::Apache2::Composite::Composite
    #
    #   TODO
    #

    package EBox::Apache2::Composite::Composite;

    use base 'EBox::Model::Composite';

    use strict;
    use warnings;

    ## eBox uses
    use EBox::Gettext;

    # Group: Public methods

    # Constructor: new
    #
    #         Constructor for composite
    #
    sub new
      {

          my ($class, @params) = @_;

          my $self = $class->SUPER::new(@params);

          return $self;

      }

    # Group: Protected methods

    # Method: _description
    #
    # Overrides:
    #
    #     <EBox::Model::Composite::_description>
    #
    sub _description
      {

          my $description =
            {
             components      => [
                            '/apache2/Settings',
                            '/apache2/Modules',
                            '/apache2/VirtualHosts',
                                ],
             layout          => 'top-bottom',
             name            => 'Composite',
             printableName   => __('Apache2 configuration'),
             compositeDomain => 'Apache2',
    #         help            => __(*),
            };

          return $description;

      }

    1;

Build and install the package. Go to the URL */ebox/Apache2/Composite/Composite* and you will see something like:

.. image:: images/composite-1.png

If you just change the layout from *top-bottom* to *tabbed* you will get:

.. image:: images/composite-2.png
