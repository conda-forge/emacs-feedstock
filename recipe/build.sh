if [ "$(uname)" == "Darwin" ]; then
    OPTS=""
else
    OPTS="--x-includes=$PREFIX/include --x-libraries=$PREFIX/lib"
fi

bash configure  --prefix=$PREFIX $OPTS

make
make check
make install

if [ "$(uname)" == "Darwin" ]; then
    mv nextstep/Emacs.app $PREFIX/Emacs.app
    mkdir -p $PREFIX/bin
    ln -s $PREFIX/Emacs.app/Contents/MacOS/Emacs $PREFIX/bin/emacs-25.1
    ln -s $PREFIX/bin/emacs-25.1 $PREFIX/bin/emacs
    ln -s $PREFIX/Emacs.app/Contents/MacOS/Emacs/bin/ctags $PREFIX/bin/ctags
    ln -s $PREFIX/Emacs.app/Contents/MacOS/Emacs/bin/ebrowse $PREFIX/bin/ebrowse
    ln -s $PREFIX/Emacs.app/Contents/MacOS/Emacs/bin/emacsclient $PREFIX/bin/emacsclient
    ln -s $PREFIX/Emacs.app/Contents/MacOS/Emacs/bin/etags $PREFIX/bin/etags
fi
