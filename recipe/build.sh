set -x

# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* ./build-aux

case "$(uname)" in
    Darwin)
	OPTS="--with-tree-sitter --with-json"

	# The build has a hard time finding libtinfo, which is separated from
	# libncurses. See
	# https://github.com/conda-forge/emacs-feedstock/pull/16#issuecomment-334241528
	export LDFLAGS="${LDFLAGS} -ltinfo"
	;;
    *MSYS*)
	# Pulled from MSYS2 PKGBUILD
	local CYGWIN_CHOST="${CHOST/-msys/-cygwin}"

	CPPFLAGS="-DNDEBUG"
	CFLAGS="-pipe -O3 -fomit-frame-pointer -funroll-loops"
	LDFLAGS="-s -Wl,-s"
	OPTS="--prefix=/usr --build='${CYGWIN_CHOST}' --with-x-toolkit=no"
	OPTS+=" --with-sound=yes --with-modules --without-compress-install"
	;;
    *MINGW*)
	# Pulled from MINGW PKGBUILD
	# Required for nanosleep with clang
	LDFLAGS="${LDFLAGS} -lpthread"
	# -D_FORTIFY_SOURCE breaks build
	CFLAGS=${CFLAGS//"-Wp,-D_FORTIFY_SOURCE=2"}
	# -foptimize-sibling-calls breaks native compilation (GCC 13.1)
	# TODO, fixed upstream now: https://git.savannah.gnu.org/cgit/emacs.git/commit/?id=19c983ddedf083f82008472c13dfd08ec94b615f
	CFLAGS+=" -fno-optimize-sibling-calls"
	# configure script can not deal with the warnings that were turned
	# into errors in GCC 14
	# TODO, fixed upstream now: https://git.savannah.gnu.org/cgit/emacs.git/commit/?id=5216903ae6c3f91ebefb1152af40753f723cbc39
	CFLAGS+=" -Wno-error=implicit-function-declaration"

	OPTS="--prefix='${MINGW_PREFIX}' --host='${MINGW_CHOST}' --build='${MINGW_CHOST}'"
	OPTS+=" --with-modules  --without-dbus --without-compress-install --with-tree-sitter --with-json"
	;;
    *)
	OPTS="--x-includes=$PREFIX/include --x-libraries=$PREFIX/lib --with-x-toolkit=gtk3 --with-harfbuzz -with-cairo --with-tree-sitter --with-json"
	;;
esac

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
    make V=1

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

make V=1

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
