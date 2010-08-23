DEB_MAKE_INVOKE = $(MAKE) $(DEB_MAKE_FLAGS) -C $(DEB_BUILDDIR)

$(patsubst %,binary-install/%,zentyal-metapackages) :: binary-install/%:

binary-predeb/zentyal-metapackages::
