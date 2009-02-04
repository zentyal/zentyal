=============================
Version 0.3: custom data type
=============================

The next step is providing our apache module rows with a new field that shows
the current state of the module at every moment. This means that the value
will not be stored on disk, hence it will not be retrieved from disk
either. This value will be computed every time the row is rendered.

To provide this functionality we need to introduce how eBox types
work and how we can create our own type to achieve this behavior. In a
nutshell, eBox types provide a convenient way to store and represent
certain data. Most of them are stored and automatically retrieved from our
persistence backend, being LDAP or GConf.

Data model
==========

We will use *emoddev* to create a custom type. Run the following command::

    ebox-moddev-type  --main-class Apache2 --name CurrentStatus --parent EBox::Types::Boolean

The above command *ebox-moddev-type* will need to know a few things: main class, the name of the new type, in this case *CurrentStatus*, and *--parent* is used to tell which is the parent class our new type will inherit from.

Now you will have a stub type in *src/EBox/Types/CurrentStatus.pm*. Modify this file to have the following code::

    #!perl
    # Class: EBox::Types::Apache2::CurrentStatus;
    #
    #   TODO
    #
    package EBox::Apache2::Types::CurrentStatus;
    use strict;
    use warnings;

    use base 'EBox::Types::Boolean';

    use EBox::Exceptions::MissingArgument;

    sub new
    {
        my $class = shift;
        my %opts = @_;
        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
    }

    # Method: optional
    #
    #   Overrides <EBox::Types::Boolean::optional>.
    #
    sub optional
    {
        my ($self) = @_;

        return 1;
    }

    # Method: value
    #
    #   Overrides <EBox::Types::Boolean::value>.
    #
    #   Here is where we can compute or return stuff that we want to report
    #   to the user.
    sub value
    {
        my ($self) = @_;

        # Fetch row instance, return if we don't have any.
        my $row = $self->row();
        return undef unless ($row);

        # Fetch module's name. This is stored in the field "module" of our row
        my $name = $row->valueByName('module');

        # Check if the module is enabled by checking if the file
        # "/etc/apache2/mods-enabled/$name.load" exits.
        return ( -f "/etc/apache2/mods-enabled/$name.load" );
    }


    # Method: printableValue
    #
    #   Overrides <EBox::Types::Boolean::printableValue>.
    #
    #   We don't need to do fancy stuff with the value returned in a printable
    #   way, so we just spit out what value() returns.
    sub printableValue
    {
        my ($self) = @_;

        return $self->value();
    }

    # Method: restoreFromHash
    #
    #   Overrides <EBox::Types::Boolean::restoreFromHash>
    #
    #   We don't need to restore anything from disk so we leave this method empty
    #
    sub restoreFromHash
    {

    }

    # Method: storeInGConf
    #
    #   Overrides <EBox::Types::Basic::storeInGConf>
    #
    #   Following the same reasoning as restoreFromHash, we don't need to store
    #   anything in GConf.
    #
    sub storeInGConf
    {

    }

    1;

The only relevant method that is worth commenting  with a few lines is *value()*. *storeInGconf()* and *restoreFromHash()* are only  overridden to provide an empty implementation, while *printableValue()* just calls *value()*.

In *value* we have to do the following: we need to return true or false depending on if the apache module is enabled or disabled. This method will be called for every row in the table. First question is: how do we know what apache module we have to check? Take a look at the code::

    #!perl
    sub value
    {
        my ($self) = @_;

        # Fetch row instance, return if we don't have any.
        my $row = $self->row();
        return undef unless ($row);

        # Fetch module's name. This is stored in the field "module" of our row
        my $name = $row->valueByName('module');

        # Check if the module is enabled by checking if the file
        # "/etc/apache2/mods-enabled/$name.load" exits.
        return ( -f "/etc/apache2/mods-enabled/$name.load" );
    }

Remember that the method *value()* belongs to a field, that is a class implementing *EBox::Types::Abstract*. A row is composed of several fields. In our model, these fields are: *module*, *enabled* and a new field *current* of type *EBox::Types::CurrentStatus* that we are creating now. We are interested in fetching the value of the field *module* within the field *current*. The method *row()* within a given field returns *undef* or the row this field belongs to, once we have the row we get the value of the field *module* in that row by running *valueByName('module')* from the row object.

Once we have the name of the module we only need to check if the file */etc/apache2/mods-enabled/$name.load* exists; this we do in the last line of the method.

Now it's time to modify our *Modules* model to use this new type, so we only have to add a few lines to *src/EBox/Model/Modules.pm*.

First, we need to let Perl know we will be using this type::

    #!perl
    use EBox::Apache2::Types::CurrentStatus;

Second, we extend our table to use this type::

    #!perl
        my @tableHead =
        (
            new EBox::Types::Select(
                'fieldName' => 'module',
                'printableName' => __('Module'),
                'populate' => \&populate_module,
                'unique' => 1,
                'editable' => 1
            ),
            new EBox::Types::Boolean(
                'fieldName' => 'enabled',
                'printableName' => __('Enabled'),
                'editable' => 1
            ),
            new EBox::Apache2::Types::CurrentStatus(
                'fieldName' => 'current',
                'printableName' => __('Current status'),
            ),
        );

The whole file should look like this::

    #!perl
    package EBox::Apache2::Model::Modules;

    use EBox::Gettext;
    use EBox::Validate qw(:all);
    use EBox::Types::Text;
    use EBox::Types::Boolean;
    use EBox::Apache2::Types::CurrentStatus;

    use strict;
    use warnings;

    use base 'EBox::Model::DataTable';

    sub new
    {
            my $class = shift;
            my %parms = @_;

            my $self = $class->SUPER::new(@_);
            bless($self, $class);

            return $self;
    }

    #
    #   Callback function to fill out the values that can
    #   be picked from the <EBox::Types::Select> field module
    #
    # Returns:
    #
    #   Array ref of hash refs containing:
    #
    #
    sub populate_module
    {

            return [
                     {
                            value => 'ssl',
                            printableValue => 'SSL',
                     },
                     {
                            value => 'info',
                            printableValue => 'Info',
                     },
                     {
                            value => 'status',
                            printableValue => 'Status',
                     },
                     {
                            value => 'version',
                            printableValue => 'Version',
                     },
            ];

    }

    sub _table
    {

        my @tableHead =
        (
            new EBox::Types::Select(
                'fieldName' => 'module',
                'printableName' => __('Module'),
                'populate' => \&populate_module,
                'unique' => 1,
                'editable' => 1
            ),
            new EBox::Types::Boolean(
                'fieldName' => 'enabled',
                'printableName' => __('Enabled'),
                'editable' => 1
            ),
            new EBox::Apache2::Types::CurrentStatus(
                'fieldName' => 'current',
                'printableName' => __('Current status'),
            ),
        );
        my $dataTable =
        {
            'tableName' => 'Modules',
            'printableTableName' => __('Modules'),
            'modelDomain' => 'Apache2',
            'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'printableRowName'=> __('Apache module'),
            'sortedBy' => 'module',
            'help' => *, # FIXME
        };

        return $dataTable;
    }

    1;

Menu
====

The current entry menu for our module is still pointing to the *Settings* model that is created by default by *emoddev*. It would be nice to have a menu entry to access our *modules* model.

The process to build the eBox menu works as follows: the framework will ask every main class in run-time to return a data structure by calling the method *menu()*. This data structure can contain a single menu entry with its name and URL, or it might be a bit more complex and return a folder with no URLs and several entries with URLs contained in that folder.

Let's see an example of how to return a folder called *Apache2* and two entries pointing to *Settings* and *Modules*. The method to modify is *menu()* in *src/EBox/Apache2.pm*, and it should look like this::

    #!perl
    # Method: menu
    #
    #       Overrides EBox::Module method.
    #
    #
    sub menu
    {
        my ($self, $root) = @_;

        my $folder = new EBox::Menu::Folder('name' => 'Apache2',
        'text' => __('Apache2'));

        my $settings = new EBox::Menu::Item(
        'url' => 'Apache2/View/Settings',
        'text' => __('Settings'));

        my $modules = new EBox::Menu::Item(
        'url' => 'Apache2/View/Modules',
        'text' => __('Modules'));

        $folder->add($settings);
        $folder->add($modules);

        $root->add($folder);
    }

After these modifications, when you click on the entry menu labeled *Apache2* you will see:

.. image:: images/menu.png
