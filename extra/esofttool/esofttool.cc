#include <iostream>
#include <sstream>
#include <set>
#include <sys/stat.h>
#include <apt-pkg/init.h>
#include <apt-pkg/pkgcache.h>
#include <apt-pkg/pkgsystem.h>
#include <apt-pkg/pkgrecords.h>
#include <apt-pkg/configuration.h>
#include <apt-pkg/version.h>

pkgCache *Cache;
pkgRecords *Recs;

struct ltstr
{
	  bool operator()(const char *s1, const char *s2) const {
		return strcmp(s1,s2) < 0;
	  }
};

std::set<const char *, ltstr> fetched;
std::set<const char *, ltstr> notfetched;
std::set<const char *, ltstr> visited;

void init() {
	pkgInitConfig(*_config);
	pkgInitSystem(*_config,_system);
	MMap *Map;
	Map = new MMap(*new FileFd(_config->FindFile("Dir::Cache::pkgcache"),
		FileFd::ReadOnly),MMap::Public|MMap::ReadOnly);
	Cache = new pkgCache(Map);
	Recs = new pkgRecords(*Cache);
}

bool _pkgIsFetched(pkgCache::PkgIterator P) {
	if(fetched.find(P.Name()) != fetched.end()) return true;

	if(notfetched.find(P.Name()) != notfetched.end()) return false;

	if(visited.find(P.Name()) != visited.end()) return true;
	else {
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
		return false;
	}
	std::string arch ;
	std::string curver;
	pkgCache::VerIterator curverObject;
	if(P.CurrentVer()) {
		curver = P.CurrentVer().VerStr();
		curverObject = P.CurrentVer();
	}
	for(pkgCache::VerIterator v = P.VersionList(); v.end() == false; v++) {
		if(!curver.empty()) {
			curver = v.VerStr();
			arch = v.Arch();
			curverObject = v;
		} else if(Cache->VS->CmpVersion(curver,v.VerStr()) < 0){
			curver = v.VerStr();
			arch = v.Arch();
			curverObject = v;
		}
	}
	if(P.CurrentVer()) {
		if(curver == P.CurrentVer().VerStr()) {
			fetched.insert(fetched.begin(),P.Name());
			return true;
		}
	}
	//package not installed or upgrade available
	
	std::stringstream file;
	//pkgRecords::Parser &Par = Recs->Lookup(curverObject.FileList());
	//Par.Filename() was used previously, but for some (I guess good)
	//reason it was replaced by this handcrafted version
	file << "/var/cache/apt/archives/" << P.Name() << "_" << curver << "_" << arch << ".deb";
	//TODO: if the version has an epoch we should do a $file =~ s/:/%3a/g;

	struct stat stats;
	if(stat(file.str().c_str(),&stats)!=0){
		notfetched.insert(notfetched.begin(),P.Name());
		return false;
	}
	//TODO: check if the md5 is ok

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
				continue;
			} else {
				notfetched.insert(notfetched.begin(),P.Name());
				return false;
			}
		}
	}
	fetched.insert(fetched.begin(),P.Name());
	return true;
}

bool pkgIsFetched(pkgCache::PkgIterator P) {
	visited.clear();
	_pkgIsFetched(P);
}

void listEBoxPkgs() {
	init();

	std::cout << "$result = [" << std::endl;
	for (pkgCache::PkgIterator P = Cache->PkgBegin(); P.end() == false; P++){
		std::string name;
		bool removable;
		std::string version;
		std::vector<std::string> depends;
		std::string available;
		std::string description;

		if(!strncmp(P.Name(),"ebox",4)) {
			std::cout << "{";
			name = P.Name();
			removable = !((name == "ebox") || (name=="ebox-software"));
			std::cout << "'name' => '" << name << "'," << std::endl;
			if(removable) {
				std::cout << "'removable' => " << 1 << "," << std::endl;
			} else {
				std::cout << "'removable' => " << 0 << "," << std::endl;
			}
			if(P.VersionList() == 0) continue;
			std::string curver;
			if(P.CurrentVer()) {
				curver = P.CurrentVer().VerStr();
				version = curver;
			}
			pkgCache::VerIterator curverObject;
			for (pkgCache::VerIterator v = P.VersionList(); v.end() == false; v++) {
				if(!curver.empty()) {
					curver = v.VerStr();
					curverObject = v;
				} else if(Cache->VS->CmpVersion(curver,v.VerStr()) < 0){
					curver = v.VerStr();
					curverObject = v;
				}
			}
			std::cout << "'depends' => [" << std::endl;
			for (pkgCache::DepIterator d = curverObject.DependsList(); d.end() == false; d++) {
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
			pkgRecords::Parser &P = Recs->Lookup(curverObject.FileList());
			description = P.ShortDesc();
			std::cout << "'description' => '" << description << "'" << std::endl;
			std::cout << "}," << std::endl;
		}
	}
	std::cout << "];" << std::endl;
	std::cout << "return $result;" << std::endl;
}

void listUpgradablePkgs() {
	init();

	std::cout << "$result = [" << std::endl;

	for (pkgCache::PkgIterator P = Cache->PkgBegin(); P.end() == false; P++){
		if((!strncmp(P.Name(),"ebox",4)) || (!strncmp(P.Name(),"kernel-image",12)) || (!strncmp(P.Name(),"linux-image",11))) {
			continue;
		}
		if(P->SelectedState != pkgCache::State::Install) {
			continue;
		}
		std::string name = P.Name();
		std::string description;
		std::string arch;
		std::string curver = P.CurrentVer().VerStr();
		pkgCache::VerIterator curverObject = P.CurrentVer();

		for(pkgCache::VerIterator v = P.VersionList(); v.end() == false; v++) {
			if(Cache->VS->CmpVersion(curver,v.VerStr()) < 0){
				curver = v.VerStr();
				curverObject = v;
				arch = v.Arch();
			}
		}
		if(curver.compare(P.CurrentVer().VerStr())==0) {
			continue;
		}
		std::stringstream file;
		file << "/var/cache/apt/archives/" << P.Name() << "_" << curver << "_" << arch << ".deb";
		struct stat stats;
		if(stat(file.str().c_str(),&stats)!=0){
			continue;
		}
		//TODO: check md5
		pkgRecords::Parser &P = Recs->Lookup(curverObject.FileList());
		description = P.ShortDesc();

		std::cout << "{";
		std::cout << "'name' => '" << name << "'," << std::endl;
		std::cout << "'description' => '" << description << "'" << std::endl;
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
}
