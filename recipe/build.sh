set -x

if [ "$(uname)" == "Darwin" ]; then
    OPTS=""
    # The build has a hard time finding libtinfo, which is separated from
    # libncurses. See
    # https://github.com/conda-forge/emacs-feedstock/pull/16#issuecomment-334241528
    export LDFLAGS="${LDFLAGS} -ltinfo"
else
    OPTS="--x-includes=$PREFIX/include --x-libraries=$PREFIX/lib"
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
fi
