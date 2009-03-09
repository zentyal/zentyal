=================================================
Version 0.9: Making changes take immediate effect
=================================================

In this version you will learn how to create a model that does not store
anything on disk, and commits its configuration changes inmediately. Although
this is not the preferred way to do this, it can be useful for some scenarios.

If you remember, most of the modules in eBox let the user make
configuration changes, and these changes do not take effect on the real
configuration until the user clicks on the *Save changes* button.



Data model
==========


Let's create our new model called *AllModules* by running:::

     ebox-moddev-model  --main-class Apache2 --name AllModules --field module:Text --field enabled:Boolean --model table

This model is going to be used to configure apache modules as well. However,
we will be doing things in a different way. 

First of all, we are going to build our rows in run-time. This approach can be
very useful if you have a read-only table with thousands of rows as its very
memory-efficient. 

We need to create our row identifier vector in run-time. To simplify things, we
will be using the name of the apache modules as row identifiers. We will
override *EBox::Model::DataTable::ids()* to return our row identifier vector
based on the available modules

The code to carry out that task will look like:::

    # Method: ids
    #
    #   Override <EBox::Model::DataTable::ids> to return
    #   row identifiers based on the apache modules that
    #   are available in /etc/apache2/mods-available
    sub ids 
    {
         opendir (my $dh, '/etc/apache2/mods-available');
        my @mods;
        while (defined (my $file = readdir($dh))) {
            next unless ($file =~ /(.*)\.conf$/);
            push (@mods, $1);
        }

        return [ sort @mods ];
    }

The next step is overriding *EBox::Model::DataTable::row* to build and
return a row.::

    # Method: row
    #
    #   Override <EBox::Model::DataTable::row> to return
    #   a row
    sub row
    {
        my ($self, $id) = @_;

        # Check if the module is enabled by checking if the file
        # "/etc/apache2/mods-enabled/$id.load" exits.
        my $enabled = ( -f "/etc/apache2/mods-enabled/$id.load" );
        my $row = $self->_setValueRow( module => $id, enabled => $enabled );
        $row->setId($id);
        return $row;
    }

*row()* receives the row identifier as parameter. As this identifier is the
name of the apache module, we check if the module is enabled or notwith:::

    my $enabled = ( -f "/etc/apache2/mods-enabled/$id.load" );

We build a row using the convenient method
*EBox::Model::DataTable::_setValueRow* with its values. And after setting
its row identifier, we return the row.

We also need to modify the field attributes that make up our table:::

    sub _table
    {

        my @tableHead =
            (
             new EBox::Types::Text(
                 'fieldName' => 'module',
                 'printableName' => __('Module'),
                 'size' => '8',
                 'storer' => sub { },
                 'acquierer' => sub { },

                 ),
             new EBox::Types::Boolean(
                 'fieldName' => 'enabled',
                 'printableName' => __('Enabled'),
                 'editable' => 1,
                 'storer' => \&enableModule,
                 'volatile' => 1,
                 ),
            );
        my $dataTable =
        {
            'tableName' => 'AllModules',
            'printableTableName' => __('Apache modules'),
            'printableRowName' => __('apache module'),
            'modelDomain' => 'Apache2',
            'defaultActions' => ['editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'help' => '', # FIXME
        };

        return $dataTable;
    }

The most relevant part is the use of new attributes: *storer*,	 .
*acquierer*, *volatile*.

*storer* and *acquierer* are attributes that can be set to function			.
pointers. This is a convenience way of changing the behavior of an				.
existing type without extending it.

As we are not storing or restoring anything from disk, we set the *storer*
and *acquierer* attributes of our *module* field to::

    sub { }

The above line gives us a pointer to an empty function. Note that the
module name and its status is set in *row()*.

We do not need to do anything special with the module name. However, we
have to carry out some actions when the module status is changed by the
user. The action we take is enabling or disabling the module depending on
what the user chooses. That is why we set *storer* to a function pointer.
Whenever the user enables or disables a module *enableModule* will be
called.

This method will look like:::

    sub enableModule
    {
        my ($self) = @_;

        my $module = $self->row()->valueByName('module');
        if ($self->value()) {
            EBox::Sudo::root("a2enmod $module");
        } else {
            EBox::Sudo::root("a2dismod $module");
        }
    }

*$self->value()* returns the status that the user would like to set.

There is only one detail left. We have to override a couple of methods in order
to avoid the *Save changes* button turns red. These methods are:
*_checkRowExist* and *_setCacheDirty*.::

    # Method: _checkRowExists
    #
    #   Override <EBox::Model::DataTable::_checkRowExists>
    sub _checkRowExist
    {
            return 1;
    }

    # Method: _setCacheDirty
    #
    #   Override <EBox::Model::DataTable::_setCacheDirty> to
    #   provide an empty implementation
    sub _setCacheDirty
    {

    }

Let's recap how the whole code:::

    package EBox::Apache2::Model::AllModules;

    use EBox::Gettext;
    use EBox::Validate qw(:all);

    use EBox::Types::Text;
    use EBox::Types::Boolean;

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

    sub enableModule
    {
            my ($self) = @_;

            my $module = $self->row()->valueByName('module');
            if ($self->value()) {
                    EBox::Sudo::root("a2enmod $module");
            } else {
                    EBox::Sudo::root("a2dismod $module");
            }
    }


    sub _table
    {

        my @tableHead =
        (
            new EBox::Types::Text(
                'fieldName' => 'module',
                'printableName' => __('Module'),
                'size' => '8',
                'storer' => sub { },
                'acquierer' => sub { },

            ),
            new EBox::Types::Boolean(
                'fieldName' => 'enabled',
                'printableName' => __('Enabled'),
                'editable' => 1,
                'storer' => \&enableModule,
                'volatile' => 1,
            ),
        );
        my $dataTable =
        {
            'tableName' => 'AllModules',
            'printableTableName' => __('Apache modules'),
            'printableRowName' => __('apache module'),
            'modelDomain' => 'Apache2',
            'defaultActions' => ['editField', 'changeView' ],
            'tableDescription' => \@tableHead,
            'help' => '', # FIXME
        };

        return $dataTable;
    }
    # Method: ids
    #
    #   Override <EBox::Model::DataTable::ids> to return
    #   row identifiers based on the apache modules that
    #   are available in /etc/apache2/mods-available
    sub ids
    {
            opendir (my $dh, '/etc/apache2/mods-available');
            my @mods;
            while (defined (my $file = readdir($dh))) {
                    next unless ($file =~ /(.*)\.conf$/);
                    push (@mods, $1);
            }

            return [ sort @mods ];
    }

    # Method: row
    #
    #   Override <EBox::Model::DataTable::row> to return
    #   a row
    sub row
    {
            my ($self, $id) = @_;

            # Check if the module is enabled by checking if the file
            # "/etc/apache2/mods-enabled/$id.load" exits.
            my $enabled = ( -f "/etc/apache2/mods-enabled/$id.load" );
            my $row = $self->_setValueRow( module => $id, enabled => $enabled );
            $row->setId($id);
            return $row;
    }

    # Method: _checkRowExists
    #
    #   Override <EBox::Model::DataTable::_checkRowExists>
    sub _checkRowExist
    {
            return 1;
    }

    # Method: _setCacheDirty
    #
    #   Override <EBox::Model::DataTable::_setCacheDirty> to
    #   provide an empty implementation
    sub _setCacheDirty
    {

    }

    1;


