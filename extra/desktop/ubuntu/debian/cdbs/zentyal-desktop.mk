DEB_MAKE_INVOKE = $(MAKE) $(DEB_MAKE_FLAGS) -C $(DEB_BUILDDIR)

$(patsubst %,binary-install/%,zentyal-desktop) :: binary-install/%:

binary-predeb/zentyal-desktop::
