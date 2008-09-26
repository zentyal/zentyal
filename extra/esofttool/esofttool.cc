#include <iostream>
#include <fstream>
#include <sstream>
#include <stdio.h>

#include <set>
#include <sys/stat.h>
#include <apt-pkg/configuration.h>
#include <apt-pkg/init.h>
#include <apt-pkg/md5.h>
#include <apt-pkg/pkgcache.h>
#include <apt-pkg/pkgcachegen.h>
#include <apt-pkg/pkgsystem.h>
#include <apt-pkg/pkgrecords.h>
#include <apt-pkg/policy.h>
#include <apt-pkg/sourcelist.h>
#include <apt-pkg/version.h>

pkgCache *Cache;
pkgRecords *Recs;
pkgSourceList *SrcList = 0;
pkgPolicy *Plcy;
std::ofstream Log;



struct ltstr
{
	  bool operator()(const char *s1, const char *s2) const {
		return strcmp(s1,s2) < 0;
	  }
};

std::set<const char *, ltstr> fetched;
std::set<const char *, ltstr> notfetched;
std::set<const char *, ltstr> visited;

void _initLog() {
  const char *logPath ="/var/log/ebox/esofttool.log";

  Log.open(logPath, std::fstream::trunc);
  if (! Log.is_open()) {
    std::cout << "Cannot open log file " << logPath << ". Aborting" << std::endl;
    exit (1);
  }

  Log << "esofttool process begins" << std::endl;
}


void init() {
	pkgInitConfig(*_config);
	pkgInitSystem(*_config,_system);
	MMap *Map;

        //init logging
	_initLog();

	// Open the cache file
	SrcList = new pkgSourceList;
	SrcList->ReadMainList();

	// Generate it and map it
	OpProgress Prog;
	pkgMakeStatusCache(*SrcList,Prog,&Map,true);

	Cache = new pkgCache(Map);
	Plcy = new pkgPolicy(Cache);
	Recs = new pkgRecords(*Cache);
}



bool _pkgIsFetched(pkgCache::PkgIterator P) {
	if(fetched.find(P.Name()) != fetched.end()){
		return true;
	}

	if(notfetched.find(P.Name()) != notfetched.end()) {
		return false;
	}

	if(visited.find(P.Name()) != visited.end()) {
		return true;
	} else {
		visited.insert(visited.begin(),P.Name());
	}

	for (pkgCache::PrvIterator Prv = P.ProvidesList(); Prv.end() == false; Prv++) {
		bool depFetched = _pkgIsFetched(Prv.OwnerPkg());
		if(depFetched) {
			fetched.insert(fetched.begin(),P.Name());
			return true;
		}
	}

	if (P.VersionList() == 0) {
		notfetched.insert(notfetched.begin(),P.Name());
		Log << P.Name() << " has not any version available" << std::endl;
		
		return false;
	}
	std::string arch ;
	std::string curver;
	pkgCache::VerIterator curverObject;
	if(P.CurrentVer()) {
		curver = P.CurrentVer().VerStr();
		curverObject = P.CurrentVer();
	}

	pkgCache::VerIterator v = Plcy->GetCandidateVer(P);
	if (v.end() != true) {
		curver = v.VerStr();
		arch = v.Arch();
		curverObject = v;
	}

	if(P.CurrentVer()) {
		if(curver.compare(P.CurrentVer().VerStr())==0) {
			fetched.insert(fetched.begin(),P.Name());
			return true;
		}
	}
	//package not installed or upgrade available
	
	std::stringstream file;
	pkgRecords::Parser &Par = Recs->Lookup(curverObject.FileList());
	//Par.Filename() was used previously, but for some (I guess good)
	//reason it was replaced by this handcrafted version
	file << "/var/cache/apt/archives/" << P.Name() << "_" << curver << "_" << arch << ".deb";
	std::string filename = file.str();
	std::string::size_type epoch = filename.find(":",0);
	if(epoch != std::string::npos) filename.replace(epoch,1,"%3a");

	struct stat stats;
	if(stat(filename.c_str(),&stats)!=0){
		notfetched.insert(notfetched.begin(),P.Name());
		
		Log << P.Name() << " has not been fetched. (Cannot found file " 
		    << filename << ")" << std::endl;
		

		return false;
	}

	MD5Summation sum;
	FileFd Fd(filename, FileFd::ReadOnly);
	sum.AddFD(Fd.Fd(), Fd.Size());
	Fd.Close();
	if(sum.Result().Value() != Par.MD5Hash()){
	  Log << P.Name() << " has  a incorrect MD5Sum" << std::endl;
	  return false;
	}

	bool skip = false;
	//package is fetched, check dependencies
	for (pkgCache::DepIterator d = curverObject.DependsList(); d.end() == false; d++) {
		bool isOr = d->CompareOp & pkgCache::Dep::Or;
		if(skip) {
			skip = isOr;
			continue;
		}
		skip = false;
		if((strcmp(d.DepType(),"Depends")!=0) &&
			(strcmp(d.DepType(),"PreDepends")!=0)) {
			continue;
		}
		bool pkgFetched = _pkgIsFetched(d.TargetPkg());
		if(pkgFetched) {
			if(isOr) {
				skip = true;
				continue;
			} 
		} else {
			if(!isOr) {
				notfetched.insert(notfetched.begin(),P.Name());

				Log << P.Name() << " has unresolved dependencies"
				    << std::endl;

				return false;
			}
		}
	}
	fetched.insert(fetched.begin(),P.Name());
	return true;
}

/*
  Function: _escapeQuote

      Escape single quotes with \\' from a string without modifying it

  Parameters:
      str - const std::string the string to escape quotes from

  Returns:
  
      std::string - the string with the quotes escaped

 */
std::string _escapeQuote(const std::string str) {

         uint pos;
         std::string retStr(str);
         pos = retStr.find("'",0);
         while (pos != std::string::npos){
           retStr.replace(pos,1,"\\'");
           pos = retStr.find("'",pos+2);
         }

         return retStr;

}

/*
  Function: _distributionId

      The distribution identifier following the LSB conventions

  Returns:
  
      std::string the string with the quotes escaped

 */
std::string _distributionId () {

        std::ifstream lsbReleaseFile;
        std::string line;

        lsbReleaseFile.open("/etc/lsb-release", std::ifstream::in);
        if (! lsbReleaseFile.is_open() ) {
                Log << "No file /etc/lsb-release" << std::endl;
                return NULL;
        }
        lsbReleaseFile >> line;
        size_t foundPos = line.find('=');
        if (foundPos == std::string::npos) {
                Log << "No = is found" << std::endl;
                return NULL;
        }
        std::string distroId = line.substr(foundPos + 1, std::string::npos);
        return distroId;
        
}

/*
  Function: _securityUpdate

      Check if the given package file is a security update or not

  Parameters:
      pkgFile - pkgCache::PkgFileIterator the package file to check

  Returns:
  
      bool - true if it is a security update, false otherwise

 */
bool _securityUpdate(pkgCache::PkgFileIterator pkgFile) {

        std::string distroId(_distributionId());
        bool retValue;
        if ( distroId.compare("Ubuntu") == 0 ) {
          retValue = strstr(pkgFile.Archive(), "-security") != NULL; 
        } else if ( distroId.compare("Debian") == 0 ) {
          retValue = strstr(pkgFile.Site(), "security.debian.org") != NULL;
        }
        return retValue;
 
}

/*
  Function: _changeLog

      The changelog from the installed version till the version stored
      in given fileName

  Parameters:
      fileName - const std::string the file path name to check the
      changelog from

      versionStr - const std::string the version string element

  Returns:
  
      std::string - the paragraphs with the changelog

 */
std::string _changeLog(const std::string fileName, const std::string versionStr) {

        /*
          If the package is debian native, the version string has not - char
          and the changelog file is only in changelog.gz
        */
        std::string changelogPath;
        if ( versionStr.find('-') == std::string::npos ) {
               changelogPath = "changelog.gz";
        } else {
               // Not native
               changelogPath = "changelog.Debian.gz";
        }
  
        std::string cmd("dpkg-deb --fsys-tarfile " + fileName
                        + " | tar x --wildcards *" + changelogPath + " -O | zcat "
                        + "| /usr/lib/dpkg/parsechangelog/debian "
                        + " - | sed -n -e /Changes/,//p | sed -n -e '4,$p'");
        std::string outputStr("");
        FILE * output = popen(cmd.c_str(), "r");
        if ( output == NULL ) {
               perror("popen");
               Log << "Couldn't popen command" << std::endl;
               return "";
        }

        while( ! feof(output) ) {
               char tmpStr[256];
               fgets(tmpStr, 256, output);
               outputStr.append(tmpStr);
        }

        int retVal = pclose(output);
        if ( retVal == -1 ) {
               perror("pclose");
               Log << "Couldn't close popen stream" << std::endl;
               return "";
        }
        return outputStr;
}

bool pkgIsFetched(pkgCache::PkgIterator P) {
	visited.clear();
	return _pkgIsFetched(P);
}

void listEBoxPkgs() {
	init();

	Log << "Listing eBox packages.." << std::endl;
	

	std::cout << "my $result = [" << std::endl;
	for (pkgCache::PkgIterator P = Cache->PkgBegin(); P.end() == false; P++){
		std::string name;
		bool removable;
		std::string version;
		std::vector<std::string> depends;
		std::string available;
		std::string description;

		if((!strncmp(P.Name(),"ebox",4))
                   || (!strncmp(P.Name(),"libebox",7))) {
			name = P.Name();

			Log << " Processing " << name << std::endl;

			removable = !((name == "ebox") || (name=="ebox-software"));
			//if there are no versions at all, continue
			if(P.VersionList() == 0) {
			  Log << name << " has not any available version" << std::endl;
			  
			  continue;
			}
			


			//if the only version available is a removed one ( ==
			// there are no candidates and P.CurrentVer() is null),
			// continue

			pkgCache::VerIterator curverObject = Plcy->GetCandidateVer(P);
			if (!P.CurrentVer() && (curverObject.end() == true)){
			  Log << name << " only version available is a removed one" << std::endl;
			  continue;
			}
			

			std::cout << "{";
			std::cout << "'name' => '" << name << "'," << std::endl;
			if(removable) {
				std::cout << "'removable' => " << 1 << "," << std::endl;
			} else {
				std::cout << "'removable' => " << 0 << "," << std::endl;
			}
			std::string curver;
			if(P.CurrentVer()) {
				//get current package version
				curver = P.CurrentVer().VerStr();
				version = curver;
				std::cout << "'version' => '" << curver << "'," << std::endl;
			}
			if (curverObject.end() != true) {
				curver = curverObject.VerStr();
			}
			std::cout << "'depends' => [" << std::endl;
			for (pkgCache::DepIterator d = curverObject.DependsList(); d.end() == false; d++) {
				if((strcmp(d.DepType(),"Depends")!=0) &&
					(strcmp(d.DepType(),"PreDepends")!=0)) {
					continue;
				}
				depends.insert(depends.begin(),d.TargetPkg().Name());
				std::cout << "\t'" << d.TargetPkg().Name()  << "'," << std::endl;
			}
			std::cout << "]," << std::endl;
			if(pkgIsFetched(P)){
				available = curver;
			}else{
				if(!version.empty()){
					available = version;
				}
			}
			std::cout << "'avail' => '" << available << "'," << std::endl;
			pkgRecords::Parser &P = Recs->Lookup(curverObject.FileList());
			description = P.ShortDesc();

                        description = _escapeQuote(description);
		
			std::cout << "'description' => '" << description << "'" << std::endl;
			std::cout << "}," << std::endl;
		}
	}
	std::cout << "];" << std::endl;
	std::cout << "return $result;" << std::endl;
}

void listUpgradablePkgs() {
	init();

	Log << "Listing non-eBox upgradables packages on "
            << _distributionId() << " .." << std::endl;

	std::cout << "my $result = [" << std::endl;

	for (pkgCache::PkgIterator P = Cache->PkgBegin(); P.end() == false; P++){
		if((!strncmp(P.Name(),"ebox",4))
                    || (!strncmp(P.Name(),"kernel-image",12))
                    || (!strncmp(P.Name(),"linux-image",11))
                    || (!strncmp(P.Name(),"libebox",7))) {
			continue;
		}
		if(P->SelectedState != pkgCache::State::Install) {
			continue;
		}
		std::string name = P.Name();
		std::string description;
                std::string security("0");
                std::string changelog("");
		std::string arch;
		std::string curver = P.CurrentVer().VerStr();
		pkgCache::VerIterator curverObject = P.CurrentVer();

		Log << " Processing " << name << std::endl;		

		for(pkgCache::VerIterator v = P.VersionList(); v.end() == false; v++) {
			if(Cache->VS->CmpVersion(curver,v.VerStr()) < 0){
				curver = v.VerStr();
				curverObject = v;
				arch = v.Arch();
			}
		}
		if(curver.compare(P.CurrentVer().VerStr())==0) {
		  Log << name << " has not any available version" << std::endl;
		  continue;
		}

		std::stringstream file;
		file << "/var/cache/apt/archives/" << P.Name() << "_" << curver << "_" << arch << ".deb";

		std::string filename = file.str();
                uint pos = filename.find(':');
                if ( pos != std::string::npos ) {
                  filename.replace(pos, 1, "%3a");
                }

                for(pkgCache::VerFileIterator verFile = curverObject.FileList();
                    verFile.end() == false; verFile++) {
                  if ( _securityUpdate(verFile.File()) ) {
                    security.assign("1");
                    changelog = _changeLog(filename, curver);
                  }
                }

		std::string::size_type epoch = filename.find(":",0);
		if(epoch != std::string::npos) filename.replace(epoch,1,"%3a");
		struct stat stats;
		if(stat(filename.c_str(),&stats)!=0){
		  Log << P.Name() << " has not been fetched. (Cannot found file " 
		      << filename << ")" << std::endl;
			continue;
		}

		pkgRecords::Parser &Par = Recs->Lookup(curverObject.FileList());

		MD5Summation sum;
		FileFd Fd(filename, FileFd::ReadOnly);
		sum.AddFD(Fd.Fd(), Fd.Size());
		Fd.Close();
		if(sum.Result().Value() != Par.MD5Hash()){
        		  Log << P.Name() << " has  a incorrect MD5Sum" 
			      << std::endl;
			continue;
		}

		description = Par.ShortDesc();

                // Escape quotes
                description = _escapeQuote(description);
                changelog   = _escapeQuote(changelog);
		
		std::cout << "{";
		std::cout << "'name' => '" << name << "'," << std::endl;
		std::cout << "'description' => '" << description << "'," << std::endl;
                std::cout << "'version' => '" << curver << "'," << std::endl;
                std::cout << "'security' => '" << security << "'," << std::endl;
                std::cout << "'changelog' => '" << changelog << "'" << std::endl;
		std::cout << "}," << std::endl;

	}
	std::cout << "];" << std::endl;
	std::cout << "return $result;" << std::endl;
}

int main(int argc, char *argv[]){
	if((argc != 2) || (argv[1][0] != '-')) {
		std::cerr << "Usage: " << argv[0] << " [-i|-u]" << std::endl;
		return 1;
	}
	if(argv[1][1] == 'i') {
		listEBoxPkgs();
	} else {
		listUpgradablePkgs();
	}

	Log << "esofttool ended" << std::endl;
	
	Log.close();
}
