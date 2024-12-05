set -x

source $RECIPE_DIR/get_cpu_arch.sh

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

if [ "$(uname)" == "Darwin" ]; then
    OPTS="--with-tree-sitter --with-json"

    # The build has a hard time finding libtinfo, which is separated from
    # libncurses. See
    # https://github.com/conda-forge/emacs-feedstock/pull/16#issuecomment-334241528
    export LDFLAGS="${LDFLAGS} -ltinfo"
else
    # Build libgccjit for the native compilation
    mkdir gcc-jit
    pushd gcc-jit
    ../gcc/configure \
        --host=$HOST \
        --target=$HOST \
        --enable-host-shared \
        --enable-languages=jit \
        --disable-bootstrap \
        --disable-multilib \
        --enable-libquadmath \
        --enable-libquadmath-support \
        --enable-long-long \
        --disable-libgomp \
        --without-isl \
        --disable-libssp \
        --disable-libmudflap \
        --disable-nls \
        --with-build-sysroot=${CONDA_BUILD_SYSROOT} \
        --with-sysroot=${PREFIX}/${HOST}/sysroot \
        --prefix=$PREFIX/lib/emacs/jit
    make -j"${CPU_COUNT}"
    make install-strip

    # ${HOST}-gcc-${GCCJIT_VERSION} needs to be in $PATH to make
    # libgccjit work
    GCCJIT_PREFIX=${PREFIX}/lib/emacs/jit
    GCCJIT_VERSION=$(${GCCJIT_PREFIX}/bin/gcc -dumpversion)

    rm -rf "${GCCJIT_PREFIX}"/libexec
    rm -rf "${GCCJIT_PREFIX}"/share
    rm -rf "${GCCJIT_PREFIX}"/lib/gcc/${HOST}/${GCCJIT_VERSION}/include
    rm -rf "${GCCJIT_PREFIX}"/lib/gcc/${HOST}/${GCCJIT_VERSION}/include-fixed
    rm -rf "${GCCJIT_PREFIX}"/lib/gcc/${HOST}/${GCCJIT_VERSION}/plugin

    for FN in "${GCCJIT_PREFIX}"/bin/* ; do
        if [[ $FN == "${GCCJIT_PREFIX}"/bin/${HOST}-gcc-${GCCJIT_VERSION} ]] ; then
            cp -s "$FN" "$PREFIX"/bin/
        else
            rm "$FN"
        fi
    done

    # Generate and install the GCC specs file
    SPECSFILE=${PREFIX}/lib/emacs/jit/lib/gcc/${HOST}/${GCCJIT_VERSION}/specs
    ${PREFIX}/bin/${HOST}-gcc-${GCCJIT_VERSION} -dumpspecs > ${SPECSFILE}

    # Point the sysroot and C runtime object paths to the Conda
    # sysroot
    cat ${SPECSFILE} | sed -E "\
s@:crt1.o@:${PREFIX}/${HOST}/sysroot/usr/lib/crt1.o@g
s@ crti.o@ ${PREFIX}/${HOST}/sysroot/usr/lib/crti.o@g
s@ crtn.o@ ${PREFIX}/${HOST}/sysroot/usr/lib/crtn.o@g
s@--sysroot=%R@--sysroot=${PREFIX}/${HOST}/sysroot@g
" > ${SPECSFILE}.new
    mv ${SPECSFILE}.new ${SPECSFILE}
    popd

    OPTS="--x-includes=$PREFIX/include --x-libraries=$PREFIX/lib --with-x-toolkit=gtk3 --with-harfbuzz -with-cairo --with-tree-sitter --with-json"
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
    make -j"${CPU_COUNT}" V=1

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

if [ "$(uname)" != "Darwin" ]; then
    CFLAGS="$CFLAGS -I$PREFIX/lib/emacs/jit/include"
    LDFLAGS="$LDFLAGS -L$PREFIX/lib/emacs/jit/lib -Wl,-rpath,$PREFIX/lib/emacs/jit/lib"
    OPTS="$OPTS --with-native-compilation=yes"
fi

bash configure --with-modules --prefix=$PREFIX $OPTS

make -j"${CPU_COUNT}" V=1

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
        touch $PREFIX/Emacs.app/Contents/MacOS/libexec/Emacs.pdmp
    fi
fi
