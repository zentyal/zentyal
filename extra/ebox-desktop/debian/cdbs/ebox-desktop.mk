DEB_MAKE_INVOKE = $(MAKE) $(DEB_MAKE_FLAGS) -C $(DEB_BUILDDIR)

$(patsubst %,binary-install/%,ebox-desktop) :: binary-install/%:

binary-predeb/ebox-desktop::
