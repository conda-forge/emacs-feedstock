if [ "$(uname)" == "Darwin" ]; then
    OPTS=""
    # The build has a hard time finding libtinfo, which is separated fro
    # libncurses. See
    # https://github.com/conda-forge/emacs-feedstock/pull/16#issuecomment-334241528
    export LDFLAGS="${LDFLAGS} -ltinfo"
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
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/ctags $PREFIX/bin/ctags
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/ebrowse $PREFIX/bin/ebrowse
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/emacsclient $PREFIX/bin/emacsclient
    ln -s $PREFIX/Emacs.app/Contents/MacOS/bin/etags $PREFIX/bin/etags

    # Replace the work directory with the prefix in Emacs.app (including in
    # binary files). See the comments in .travis.yml.

    LC_ALL=C grep -rl "$CONDA_BLD_PATH/work/emacs-25.2/nextstep" $PREFIX/Emacs.app | xargs sed -i'' -e "s:$CONDA_BLD_PATH/work/emacs-25.2/nextstep:$PREFIX:g"
fi
