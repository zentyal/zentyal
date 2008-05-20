// This code is heavily inspired by Chris Pederick (useragentswitcher) install.js
// Contributors: Philip Chee, deathburger
//
// Philip Chee: Added installation of prefs, components, and locales.
// deathburger: Refactored to move all changable items to the top of the file.

// Editable Items Begin
var displayName         = "RMD"; // The name displayed to the user (don't include the version)
var version             = "1.4.6";
var name                = "remember-mismatch"; // The leafname of the JAR file (without the .jar part)

// The following three sets of variables tell this installer script how your
// extension directory structure looks.
// If your jar file contains content/packagename use the second packageDir
// variable. Same rule applies for skinDir and localeDir. I set them up
// independent of each other just in case an extension layout is wacky.
var packageDir           = "/"
//var packageDir           = "/" + name + "/"
//var skinDir           = "/"
//var skinDir           = "/" + name + "/"
var localeDir           = "/"
//var localeDir           = "/" + name + "/"

var locales             = new Array( "cs-CZ",
				     "da-DK", 
				     "de-DE",
				     "el-GR",
				     "en-US", 
				     "es-AR",
				     "es-ES",
				     "fi-FI",
				     "fr-FR",
				     "hr-HR", 
				     "it-IT",
				     "ja-JP",
				     "ko-KR", 
				     "nb-NO", 
				     "nl-NL",
				     "pl-PL",
				     "pt-BR", 
				     "ru-RU", 
				     "tr-TR",
				     "uk-UA",
				     "zh-CN" );
var skins               = new Array(  ); // "modern"
var prefs               = new Array(  );
var components          = new Array( "rmdBadCertHandler.js", "rmdIBadCertHandler.xpt" ); // platform specific components are individually added below
var searchPlugins       = new Array(  );

// Mozilla Suite/Seamonkey stores all pref files in a single directory
// under the application directory.  If the name of the preference file(s)
// is/are not unique enough, you may override other extension preferences.
// set this to true if you need to prevent this.
var disambiguatePrefs   = true;

// Editable Items End

var jarName             = name + ".jar";
var jarFolder           = "content" + packageDir
var error               = null;

var folder              = getFolder("Profile", "chrome");
var prefFolder          = getFolder(getFolder("Program", "defaults"), "pref");
var compFolder          = getFolder("Components");
var searchFolder        = getFolder("Plugins");

var existsInApplication = File.exists(getFolder(getFolder("chrome"), jarName));
var existsInProfile     = File.exists(getFolder(folder, jarName));

var contentFlag         = CONTENT | PROFILE_CHROME;
var localeFlag          = LOCALE | PROFILE_CHROME;
var skinFlag            = SKIN | PROFILE_CHROME;

// If the extension exists in the application folder or it doesn't exist
// in the profile folder and the user doesn't want it installed to the
// profile folder
if(existsInApplication ||
    (!existsInProfile &&
      !confirm( "Do you want to install the " + displayName +
                " extension into your profile folder?\n" +
                "(Cancel will install into the application folder)")))
{
    contentFlag = CONTENT | DELAYED_CHROME;
    folder      = getFolder("chrome");
    localeFlag  = LOCALE | DELAYED_CHROME;
    skinFlag    = SKIN | DELAYED_CHROME;
}

initInstall(displayName, name, version);
setPackageFolder(folder);
error = addFile(name, version, "chrome/" + jarName, folder, null);

// If adding the JAR file succeeded
if(error == SUCCESS)
{
    folder = getFolder(folder, jarName);

    registerChrome(contentFlag, folder, jarFolder);
    for (var i = 0; i < locales.length; i++) {
      var err = registerChrome(localeFlag, folder, "locale/" + locales[i] + localeDir);
	if (err != SUCCESS) alert("chrome registration error " + "locale/" + locales[i] + localeDir);
    }

    for (var i = 0; i < skins.length; i++) {
        registerChrome(skinFlag, folder, "skin/" + skins[i] + skinDir);
    }

    for (var i = 0; i < prefs.length; i++) {
        if (!disambiguatePrefs) {
            addFile(name + " Defaults", version, "defaults/preferences/" + prefs[i],
                prefFolder, prefs[i], true);
        } else {
            addFile(name + " Defaults", version, "defaults/preferences/" + prefs[i],
                prefFolder, name + "-" + prefs[i], true);
        }
    }

    for (var i = 0; i < components.length; i++) {
        addFile(name + " Components", version, "components/" + components[i],
            compFolder, components[i], true);
    }


	// platform specific --> linux-gnu_x86_64-gcc3
    addFile(name + " Components",
	    version,
	    "platform/linux-gnu_x86_64-gcc3/components/rmdBadCertListener.so", 
	    "platform/linux-gnu_x86_64-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

	// platform specific --> linux-gnu_x86-gcc3
    addFile(name + " Components",
	    version,
	    "platform/linux-gnu_x86-gcc3/components/rmdBadCertListener.so", 
	    "platform/linux-gnu_x86-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

	// platform specific --> Linux_x86_64-gcc3
    addFile(name + " Components",
	    version,
	    "platform/Linux_x86_64-gcc3/components/rmdBadCertListener.so", 
	    "platform/Linux_x86_64-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

	// platform specific --> Linux_x86-gcc3
    addFile(name + " Components",
	    version,
	    "platform/Linux_x86-gcc3/components/rmdBadCertListener.so", 
	    "platform/Linux_x86-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

	// platform specific --> WINNT_x86-msvc
    addFile(name + " Components",
	    version,
	    "platform/WINNT_x86-msvc/components/rmdBadCertListener.dll", 
	    "platform/WINNT_x86-msvc/components/rmdBadCertListener.dll", 
	    "rmdBadCertListener.dll", 
	    true);

	// platform specific --> Darwin_x86-gcc3
    addFile(name + " Components",
	    version,
	    "platform/Darwin_x86-gcc3/components/rmdBadCertListener.so", 
	    "platform/Darwin_x86-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

	// platform specific --> Darwin_ppc-gcc3
    addFile(name + " Components",
	    version,
	    "platform/Darwin_ppc-gcc3/components/rmdBadCertListener.so", 
	    "platform/Darwin_ppc-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

	// platform specific --> Linux_ppc-gcc3
    addFile(name + " Components",
	    version,
	    "platform/Linux_ppc-gcc3/components/rmdBadCertListener.so", 
	    "platform/Linux_ppc-gcc3/components/rmdBadCertListener.so", 
	    "rmdBadCertListener.so", 
	    true);

    for (var i = 0; i < searchPlugins.length; i++) {
        addFile(name + " searchPlugins", version, "searchplugins/" + searchPlugins[i],
            searchFolder, searchPlugins[i], true);
    }

    error = performInstall();

    // If the install failed
    if(error != SUCCESS && error != REBOOT_NEEDED)
    {
        displayError(error);
    	cancelInstall(error);
    }
    else
    {
        alert("The installation of the " + displayName + " extension succeeded.");
    }
}
else
{
    displayError(error);
	cancelInstall(error);
}

// Displays the error message to the user
function displayError(error)
{
    // If the error code was -215
    if(error == READ_ONLY)
    {
        alert("The installation of " + displayName +
            " failed.\nOne of the files being overwritten is read-only.");
    }
    // If the error code was -235
    else if(error == INSUFFICIENT_DISK_SPACE)
    {
        alert("The installation of " + displayName +
            " failed.\nThere is insufficient disk space.");
    }
    // If the error code was -239
    else if(error == CHROME_REGISTRY_ERROR)
    {
        alert("The installation of " + displayName +
            " failed.\nChrome registration failed.");
    }
    else
    {
        alert("The installation of " + displayName +
            " failed.\nThe error code is: " + error);
    }
}
