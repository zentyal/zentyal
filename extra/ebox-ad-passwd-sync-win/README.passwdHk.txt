Kervin Pierre
kervin@blueprint-tech.com
11JUN02
Florida Tech, Information Technology Department

The programs and source code in this package and supplied by this package is made available under the LGPL license.  Please see LICENSE.txt in this package for more information.

For the latest packages and more information, please see http://acctsync.sourceforge.net/ .



1. Introduction
2. Security
3. Install instructions
4. Registry values
5. Upgrading Issues




1. Intro
========

'passwdhk.dll' is a Windoows password filter DLL.  This means that if registered in the registry, and the correct domain security policy is enabled, then this dll will be notified whenever a user tries to change their password.  This allows external user account databases to be kept in synch with windows.  The 'passwdhk.dll' allows the administrator to register any script that can take the user's name and password as arguments to be called at the event that a user changes their password.  For instance, the BAT script that comes with this package can be registered to be called, see the 'passwd.bat' file.  Any script or execute can be registered.

This DLL *should* be able to be used on NT but has ONLY BEEN TESTED ON WIN2K.  Even then care should be taken to make sure that it works in your environment.  Please report software defects on the mailing list at http://acctsync.sourceforge.net/



2. Security
===========

It is strongly recommended that the 'urlencode' option be used.  Without this a user would be able to run a progam with administrator priviledges with a carefully crafted password.  This is because the "CreateProcess()" function starts your script in a valid shell.  Windows does not give the programmer anyway of escaping those shell variables, hence a password that contains shell code can be executed as code.  The urlencode option prevents this.  With urlencode, special characters are passed as their ascii values prefixed with a "%".  The passwd script would have to be able to urldecode those, but that's not too difficult.  The following line of PERL code...

 $pass =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;

urldecodes a password that was passed as a urlencoded string.



3. Setup
========

Manual
******

(i) Copy 'passwdhk.dll' to c:\winnt\system32

(ii) Set 'Domain Security Policy>Windows Settings>Security Settings>Account Policies>Password Policy>Passwords must meet complexity requirements' to enabled.

(iii)Edit 'HKEY_LOCAL_MACHINE>SYSTEM>CurrentControlSet>Control>Lsa>Notification Packages' registry key and add 'passwdhk' in the list of names there.  Pay attension how the others are listed.  This is 2 byte so there should be a zero after every letter and the null terminating character is 2 zeros at the end.

(iv) Edit 'passwdhk.reg' to suit your environment and then import it into the registry by double-clicking that file.

(v)Reboot.


Auto
****

Use the installer, use passwdhk_config.exe to edit the DLL's options and do step (ii) from above.



4. Registry values
==================

(i)   preChangeProg - String  - This is the program that will be called *before* the user's password change executes on Windows. If this script returns anything but a zero '0' as the exit condition, then the password change will be denied.  This gives us a good way to allow/deny password changes based on a particular programs result.  

It's important to note that in case of many scripting languages, this should be the interpreter, not the script itself.  For example, if you are using a perl script for the user password changes then the value should be the command for the perl interpreter, "perl.exe", or the full path the the perl executeable.  If your password change program is an executeable or a BAT file, then that program or script should be listed here, and the "preChangeProgArgs" value can be left blank.  The reason for this is that this value will be the application called, can thus can not have any arguments.

This should be an empty string if you do not want to filter passwords.


(ii)  preChangeProgArgs - String - This value stores the arguments to the "preChangeProg" program.  If left blank, the password changing program will be called with the user's name and password as it's only two arguments.  

For example, if I were using a java program to change user passwords then the "preChangeProg" value, as explained above, would be set to "jre" or "C:\Program Files\Java\bin\jre.exe", etc. and the "preChangeProgArgs" value would be sent to any arguments I would like to pass to the java runtime and the class I would like to run eg., '-cp "C:\Program Files\MyJavaClasses" passwd'.  Using this example, when a user changes their password, the full command line executed will be...

"C:\Program Files\Java\bin\jre.exe" -cp "C:\Program Files\MyJavaClasses" passwd username password

It's important to only supply the interpreter as the "preChangeProg" value because the CreateProcess function needs that value to be a real executeable and not an executable and arguments.  Hence the arguments go in "preChangeArgs".


(iii) postChangeProg - String  - This program will be called *after* the user's password has been changed on Windows.  The rules pertaining to "preChangeProg" also apply here.


(iv)  postChangeProgArgs - String  - Arguments if any for the "postChangeProg" program or script.


(i)   loglevel - Numeric - A loglevel of '0' zero disables logging.  The other levels are 1 ( ERROR ), 2 ( DEBUG ), and 3 ( ALL ).  The 'ALL' level stores user passwords in the log file as with other data, so use this option with care.  Setting this value to above zero and *not* specifying a valid log file may have unpredictable results.

(ii)  maxlogsize - Numeric - Specifies the maximum size in kilobytes which the log file can grow to.  After which the log file is truncated to 25% of this size, with the most recent log entries kept.  The old log file is renamed with a '.bak' extension.  To disable log trucation, set this value to zero '0'.



5. Upgrade Issues
=================

If you are upgrading the PasswdHk package, the DLL must be disabled and the system rebooted before the upgrade.  This is because the Win2k LSA ( Local Security Authority ) locks the DLL file until the DLL has been disabled and the system rebooted.  Therefore to overwrite with the newer DLL file, the system has to go through the unlocking step.
