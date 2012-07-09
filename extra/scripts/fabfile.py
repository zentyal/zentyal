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
    pkgs = pkgstr.split(';')
    pbuild(pkgs)
    for pkg in pkgs:
        install(pkg)

def copy(path):
    """
    Copy the given file to the target host
    """
    bname = os.path.basename(path)
    class_path = '/'.join(os.path.dirname(path).split('/')[2:])
    put(path, '~')
    perl_path = "/usr/share/perl5/%s/" % class_path
    sudo('mv ~/%s %s' % (bname, perl_path))
    out = run('perl -c %s%s' % (perl_path, bname))
    if re.search('OK', out):
        sudo('/etc/init.d/zentyal apache restart')

# Private functions
def __get_version(pkg):
    output = local('head -n 1 %s/debian/precise/changelog | grep -o -P " \((.*?)\)" | tr -d "()[:space:]"' % pkg, capture=True)
    return output
