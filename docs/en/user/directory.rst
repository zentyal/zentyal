Directory service (LDAP)
************************

.. sectionauthor:: José A. Calvo <jacalvo@ebox-platform.com>
                   Enrique J. Hernández <ejhernandez@ebox-platform.com>
                   Javier Uruen <juruen@ebox-platform.com>

**Directory services** are used to store and sort the data relating to
organizations (in this case, users and groups). They
enable network administrators to handle access to resources by
users by adding an abstraction layer between the resources and their
users. This service gives a data access interface. It also
acts as a central, common authority through which users can be
securely authenticated.

A directory service can be considered similar to the yellow
pages. Its characteristics include:

* The data is much more often read than written.
* Hierarchical structure that simulates organisational architecture.
* Properties are defined for each type of object, standardized by the IANA [#]_,
  on which access control lists (ACLs) can be defined.

.. [#] *Internet Assigned Numbers Authority* (IANA) is responsible
   for assigning public IP addresses,
   top level domain (TLD) names, etc. http://www.iana.org/

There are many different implementations of the directory service,
including NIS, OpenLDAP, ActiveDirectory, etc. eBox uses
**OpenLDAP** as its directory service with *Samba* technology for
*Windows* domain controller and to share files and printers.

Users and groups
================

Normally, in the management of any size of organization there is
the concept of **user** or **group**. For easier shared
resource administration, the difference is made between
users and their groups. Each one may have different
privileges in relation to the resources of the organization.

Management of users and groups in eBox
--------------------------------------

A group can be created from the :menuselection:`Groups -->
Add group` menu. A group is identified by its name and can contain
a description.

.. image:: images/directory/01-groupadd.png

Through :menuselection:`Groups --> Edit group`, the existing groups
are displayed for edition or deletion.

While a group is being edited, the users belonging to the group can be
chosen. Some options belonging to the installed eBox modules with some
specific configuration for the user groups can be changed too.

.. image:: images/directory/02-groupedit.png

The following are possible with user groups, among others:

* Provide a directory to be shared between users of a group.
* Provide permission for a printer to all users of a group.
* Create an alias for an e-mail account that redirects to all users of a
  group.
* Assign access permission to the different eGroupware applications for
  all users of a group.

The users are created from the :menuselection:`Users -->
Add user` menu, where the following data must be
completed:

.. image:: images/directory/03-useradd.png

User name:
  Name of the user in the system, which will be the name used for
  identification in the authentication processes.
Name:
  User's name.
Surnames:
  User's surnames.
Comments:
  Additional data on the user.
Password:
  Password to be used by the user in the authentication processes.
Group:
  The user can be added to a group during its creation.

From :menuselection:`Users --> Edit user`, a list of users can be
obtained, edited or deleted.

.. image:: images/directory/04-users.png

While a user is being edited, all the previous data can be changed,
except for the user name. The data regarding the installed eBox modules
that have some specific configuration for users can also be changed, as
well as the list of groups to which the user belongs.

.. image:: images/directory/05-useredit.png

It is possible to edit a user to:

* Create an account for the Jabber server.
* Create an account for file or PDC sharing with a customized quota.
* Provide permission for the user to use a printer.
* Create an e-mail account for the user and *aliases* for it.
* Assign access permission to the different eGroupware applications.
* Enable and assign a telephone extension to the user.

.. _usercorner-ref:

User Corner
-----------

The user data can only be modified by the eBox
administrator, which becomes non-scalable when the number of
users managed becomes large. Administration
tasks, such as changing a user's password, may cause the person
responsible to waste a lot of time. Hence
the need for the **user corner**. This
corner is an eBox service that allows users to change their own data.
This function must be enabled like the other
modules. The user corner is listening in another port
through another process to increase system security.

.. image:: images/directory/06-usercorner-server.png
   :scale: 50

Users can enter the user corner through:

  https://<eBox_ip>:<user_corner_port>/

Once users have entered their user name and password, changes can be made
to their personal configuration. For now, the functions provided
are:

* Change current password
* User voicemail configuration

.. image:: images/directory/07-usercorner-user.png
   :scale: 50

Practical example A
^^^^^^^^^^^^^^^^^^^

Create a group in eBox called **accountancy**.

To do so:

#. **Action:** Enable the **users and groups** module. Enter
   :menuselection:`Module status` and enable the module if it is
   not enabled.

   Effect:
     The module is enabled and ready for use.

#. **Action:**
   Access :menuselection:`Groups`. Add **accountancy** as a group. The
   **comments** parameter is optional.

   Effect:
     The **accountancy** group has been created. The changes do not have
     to be saved, as any action on LDAP is instant.

Practical example B
^^^^^^^^^^^^^^^^^^^

Create the user **peter** and add him to the **accountancy** group.

To do so:

#. **Action:**
   Access :menuselection:`Users --> Add user`. Complete
   the different fields for the new user. The user
   **peter** can be added to the **accountancy** group from this screen.

   Effect:
     The user has been added to the system and to the **accountancy** group.

Check from the console that the user has been correctly added:

#. **Action:**
   In the console, run the command::

    # id peter

   Effect:
    The result should be something like this::

     uid=2003(pedro) gid=1901(__USERS__)
     groups=1901(__USERS__) ,2004(accountancy)

.. include:: directory-exercises.rst
