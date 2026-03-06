set -x

source $RECIPE_DIR/get_cpu_arch.sh

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

if [ "$(uname)" == "Darwin" ]; then
    OPTS="--with-tree-sitter"

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

    OPTS="--x-includes=$PREFIX/include --x-libraries=$PREFIX/lib --with-x-toolkit=gtk3 --with-harfbuzz -with-cairo --with-tree-sitter"
fi

autoreconf -vfi

if [ "$(uname)" != "Darwin" ]; then
    CFLAGS="$CFLAGS -I$PREFIX/lib/emacs/jit/include"
    LDFLAGS="$LDFLAGS -L$PREFIX/lib/emacs/jit/lib -Wl,-rpath,$PREFIX/lib/emacs/jit/lib"
fi

if [ "$(uname)" == "Darwin" ]; then
    # Disable the self-contained NS bundle so that --prefix, --bindir,
    # and --libexecdir are respected
    bash configure --with-modules --prefix=$PREFIX \
        --disable-ns-self-contained \
        $OPTS
else
    bash configure --with-modules --prefix=$PREFIX $OPTS
fi

make -j"${CPU_COUNT}" V=1

# make check
make install

if [ "$(uname)" == "Darwin" ]; then
    mv nextstep/Emacs.app $PREFIX/Emacs.app
    # Replace the standalone binary installed by make install with a
    # wrapper that launches through the app bundle for proper macOS
    # integration (dock icon, menu bar name, etc.)
    rm -f $PREFIX/bin/emacs $PREFIX/bin/emacs-$PKG_VERSION
    cat <<EOF > $PREFIX/bin/emacs-$PKG_VERSION
#!/bin/sh
$PREFIX/Emacs.app/Contents/MacOS/Emacs "\$@"
EOF
    chmod a+x $PREFIX/bin/emacs-$PKG_VERSION
    ln -s $PREFIX/bin/emacs-$PKG_VERSION $PREFIX/bin/emacs
fi
