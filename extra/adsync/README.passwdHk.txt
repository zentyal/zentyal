Kervin Pierre
kervin@blueprint-tech.com
11JUN02
Florida Tech, Information Technology Department

Modified by:
Brian Clayton
bclayton@clarku.edu
Information Technology Services
Clark University
03APR08

Modified by:
Curtis Robinson
crobinso@fit.edu
02FEB10

The programs and source code in this package and supplied by this package is made available under the LGPL license.  Please see LICENSE.txt in this package for more information.

For the latest packages and more information, please see http://acctsync.sourceforge.net/ .



1. Introduction
2. Security
3. Install instructions
4. Registry values
5. Upgrading Issues




1. Intro
========

PasswdHk is a Windows password filter DLL that facilitates invocation of an external program from Windows password filter events which occur immediately before and immediately after a Windows password change.  A common use for this is to replicate password changes to an external database or directory service.  The batch file "passwd.bat" is included as an example that can be used for testing; it merely writes the username and password to the file "passwd.txt".

Although this filter has been tested on Windows 2000, Windows XP, and Windows Server 2003, care should be taken to make sure that it works in your environment.  Please report software defects at http://sourceforge.net/projects/passwdhk .



2. Security
===========

Password filters run in the security context of the local system account.  Care must be taken to ensure the external program is not replaced or substituted.  It is suggested that permissions be restricted on both the external program itself, and the registry key HKLM->SYSTEM->CurrentControlSet->Control->Lsa->passwdhk.

If the external programs are batch (.bat) files (or launched from batch files), it is strongly recommended that the URL encode password option be used.  Without this a user would be able to run a progam with service priviledges with a carefully crafted password.  This is because the batch files are processed by the command prompt, which gives special functionality to certain characters.  The URL encode option prevents this by encoding all the offending characters.  It is up to the external program to decode the password, but this is often trivial since many programming languages already have routines to perform a URL decode. The following is an example of how to do a URL decode using PERL: $pass =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;



3. Setup
========

(a) Copy "passwdhk.dll" to C:\Windows\system32

(b) Edit the "HKLM->SYSTEM->CurrentControlSet->Control->Lsa->Notification Packages" registry value and add "passwdhk" (without the quotes) to the list of names there (on a new line).

(c) Edit the file "passwdhk.reg" to suit your environment and then import it into the registry by double-clicking that file or use passwdhk_config.exe to configure settings.

(d) Set "Domain Security Policy\Windows Settings\Security Settings\Account Policies\Password Policy\Passwords must meet complexity requirements" to enabled to enable both complexity checking and the password filter.

(e) Reboot.



4. Registry values
==================

All of the registry values below are of type string (REG_SZ).  See passwdhk.reg for examples.


(a) preChangeProg - program that will be called *before* the user's password change executes on Windows. If this script returns anything but a zero '0' as the exit condition, then the password change will be denied.  This gives us a good way to allow/deny password changes based on a particular programs result.  

It's important to note that in case of many scripting languages, this should be the interpreter, not the script itself.  For example, if you are using a perl script for the user password changes then the value should be the command for the perl interpreter, "perl.exe", or the full path the the perl executeable.

This should be an empty string if you do not want to filter passwords.  See "Security" notes above regarding ".bat" files.


(b) preChangeProgArgs - arguments to the "preChangeProg" program.  If left blank, the password changing program will be called with the user's name and password as it's only two arguments.  

For example, to use a java program to change user passwords then the "preChangeProg" value, as explained above, would be set to "jre" or "C:\Program Files\Java\bin\jre.exe", etc. and the "preChangeProgArgs" value would be sent to any arguments I would like to pass to the java runtime and the class I would like to run eg., '-cp "C:\Program Files\MyJavaClasses" passwd'.  Using this example, when a user changes their password, the full command line executed will be...

"C:\Program Files\Java\bin\jre.exe" -cp "C:\Program Files\MyJavaClasses" passwd username password

It's important to only supply the interpreter as the "preChangeProg" value because the CreateProcess function needs that value to be a real executable and not an executable and arguments.  Hence the arguments go in "preChangeArgs".


(c) preChangeProgWait - maximum execution time allowed for pre-change program, in milliseconds


(d) postChangeProg - program that will be called *after* the user's password has been changed on Windows.  The rules pertaining to "preChangeProg" also apply here.


(e) postChangeProgArgs - same as preChangeProgArgs above, except for post-change program.


(f) postChangeProgWait - maximum execution time allowed for post-change program, in milliseconds


(g) logfile - name of the log file.  Will be created if it does not exist.


(h) loglevel - an integer in the range 0-3, meaning the following: 0 - logging disabled, 1 - errors only, 2 - debugging info, 3 - full debugging with passwords (not recommended, use with care!).  A log level greater than zero without a valid log file specified may have unpredictable results.


(i) maxlogsize - specifies the maximum size in kilobytes which the log file can grow to.  After which the log file is truncated to 25% of this size, with the most recent log entries kept.  The old log file is renamed with a '.bak' extension.  To disable log trucation, set this value to zero '0'.


(j) urlencode - toggles URL encoding of password.  Must be "true" or "false".


(k) doublequote - toggles encapsulation of password with double-quotes (").  Must be "true" or "false".  Any double-quote characters within the password itself will be escaped with a preceding backslash (\) unless URL encoding is also enabled, in which case this is unnecessary since the double-quotes within the password are encoded.


(l) output2log - toggles logging of external program output.  Must be "true" or "false".



5. Upgrade Issues
=================

If you are upgrading the PasswdHk package, the DLL must be disabled and the system rebooted before the upgrade.  This is because the Windows LSA ( Local Security Authority ) locks the DLL file until the DLL has been disabled and the system rebooted.  Therefore to overwrite with the newer DLL file, the system has to go through the unlocking step.
