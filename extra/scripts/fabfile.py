from fabric.api import local, put, run, sudo
import os.path, re

def pbuild(pkgs):
    local('../extra/scripts/zpr ../extra/zbuildtools/zentyal-package %s' % ' '.join(pkgs))

def install(pkg):
    version = __get_version(pkg)
    put('debs-ppa/zentyal-%s*%s*deb' % (pkg, version), '~')
    sudo('dpkg -i zentyal-%s*%s*deb' % (pkg, version))

def binstall(pkgstr):
    """
    Build and install Zentyal packages in the target hosts

    The packages are separated by ;. For instance, binstall:"core;remoteservices"
    """
    build(pkgstr)
    pkgs = pkgstr.split(';')
    for pkg in pkgs:
        install(pkg)

def build(pkgstr):
    """
    Build Zentyal packages and stored in ./debs-ppa directory

    The packages are separated by ;. For instance, binstall:"core;remoteservices"
    """
    pkgs = pkgstr.split(';')
    pbuild(pkgs)

def copy(path):
    """
    Copy the given Perl file to the target host
    """
    bname = os.path.basename(path)
    class_path = '/'.join(os.path.dirname(path).split('/')[2:])
    put(path, '~')
    perl_path = "/usr/share/perl5/%s/" % class_path
    sudo('mv ~/%s %s' % (bname, perl_path))
    out = run('perl -c %s%s' % (perl_path, bname))
    if re.search('OK', out):
        sudo('/etc/init.d/zentyal webadmin restart')

def script_copy(path):
    """ Copy the script file to the target host """
    bname = os.path.basename(path)
    module_name = os.path.dirname(path).split('/')[0]
    put(path, '~')
    script_target_path = "/usr/share/zentyal-%s" % module_name
    sudo('mv ~/%s %s' % (bname, script_target_path))

# Private functions
def __get_version(pkg):
    output = local('head -n 1 %s/debian/changelog | grep -o -P " \((.*?)\)" | tr -d "()[:space:]"' % pkg, capture=True)
    head   = local('head -n 1 %s/ChangeLog' % pkg, capture=True)
    if head == 'HEAD':
	major, minor, mminor = output.split('.')
	mminor = int(mminor) + 1
	output = "%s.%s.%d" % (major, minor, mminor)
    return output
