set -x

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

if [ "$(uname)" == "Darwin" ]; then
    OPTS=""
    # This magic value corresponds to macos 10.9, the
    if [[ $target_platform == "osx-64" ]]; then
        # This magic value corresponds to macos 10.9, see
        # https://github.com/emacs-mirror/emacs/blob/575c3beb4c001687ce7a4581de005a16d6f2e081/nextstep/INSTALL#L48
        OPTS="${OPTS} -DMAC_OS_X_VERSION_MIN_REQUIRED=1090"
    fi

    # The build has a hard time finding libtinfo, which is separated from
    # libncurses. See
    # https://github.com/conda-forge/emacs-feedstock/pull/16#issuecomment-334241528
    export LDFLAGS="${LDFLAGS} -ltinfo"
else
    OPTS="--x-includes=$PREFIX/include --x-libraries=$PREFIX/lib --with-x-toolkit=gtk3 --with-harfbuzz -with-cairo"
fi

autoreconf -vfi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == 1 ]]; then
  (
    mkdir -p native-build
    pushd native-build

    export CC=$CC_FOR_BUILD
    export AR=($CC_FOR_BUILD -print-prog-name=ar)
    export NM=($CC_FOR_BUILD -print-prog-name=nm)
    export LDFLAGS=${LDFLAGS//$PREFIX/$BUILD_PREFIX}
    export PKG_CONFIG_PATH=${BUILD_PREFIX}/lib/pkgconfig
    export ac_cv_func_aligned_alloc=no
    export host_alias=$build_alias

    bash ../configure --with-modules --prefix=$BUILD_PREFIX $OPTS
    make

    popd
  )
  # And the config variables...
  export gl_cv_func_getgroups_works=yes
  export gl_cv_func_gettimeofday_clobber=no
  export ac_cv_func_getgroups_works=yes
  export ac_cv_func_mmap_fixed_mapped=yes
  export gl_cv_func_working_utimes=yes
  export gl_cv_func_open_slash=no
  export fu_cv_sys_stat_statfs2_bsize=yes
  OPTS="$OPTS --with-pdumper=yes --with-unexec=no --with-dumping=none"
fi

bash configure --with-modules --prefix=$PREFIX $OPTS

make

# make check
make install

if [ "$(uname)" == "Darwin" ]; then
    mv nextstep/Emacs.app $PREFIX/Emacs.app
    mkdir -p $PREFIX/bin
    cat <<EOF > $PREFIX/bin/emacs-$PKG_VERSION
#!/bin/sh
$PREFIX/Emacs.app/Contents/MacOS/Emacs "\$@"
EOF
    chmod a+x $PREFIX/bin/emacs-$PKG_VERSION
    ln -s $PREFIX/bin/emacs-$PKG_VERSION $PREFIX/bin/emacs
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/ctags $PREFIX/bin/ctags
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/ebrowse $PREFIX/bin/ebrowse
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/emacsclient $PREFIX/bin/emacsclient
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/etags $PREFIX/bin/etags
    if [[ "$CONDA_BUILD_CROSS_COMPILATION" == 1 ]]; then
	# Make an empty pdump file as a sentinel to post-link.sh
        touch $PREFIX/Emacs.app/Contents/MacOS/Emacs.pdmp
    fi
fi
