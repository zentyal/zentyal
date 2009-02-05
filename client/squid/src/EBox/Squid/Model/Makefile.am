## Process this file with automake to produce Makefile.
SUBDIRS = Report

perldir = @PERLPATH@/EBox/Squid/Model

nobase_perl_DATA = GeneralSettings.pm \
    ObjectPolicy.pm \
    GroupPolicyBase.pm ObjectGroupPolicy.pm GlobalGroupPolicy.pm \
    NoCacheDomains.pm \
    ExtensionFilterBase.pm MIMEFilterBase.pm\
    DomainFilterSettingsBase.pm DomainFilterBase.pm DomainFilterFilesBase.pm DomainFilterCategoriesBase.pm \
    ContentFilterThreshold.pm\
    DomainFilter.pm  DomainFilterSettings.pm  DomainFilterFiles.pm DomainFilterCategories.pm\
    FilterGroup.pm \
    FilterGroupContentFilterThreshold.pm\
    UseDefaultDomainFilter.pm  FilterGroupDomainFilter.pm  FilterGroupDomainFilterSettings.pm  FilterGroupDomainFilterFiles.pm FilterGroupDomainFilterCategories.pm\
    ExtensionFilter.pm MIMEFilter.pm \
    ApplyAllowToAllBase.pm ApplyAllowToAllExtensions.pm ApplyAllowToAllMIME.pm \
    UseDefaultExtensionFilter.pm  UseDefaultMIMEFilter.pm \
    FilterGroupExtensionFilter.pm  FilterGroupMIMEFilter.pm \
    FilterGroupApplyAllowToAllExtensions.pm  FilterGroupApplyAllowToAllMIME.pm 


DISTCLEANFILES =

EXTRA_DIST = $(nobase_perl_DATA)

MAINTAINERCLEANFILES = Makefile.in

