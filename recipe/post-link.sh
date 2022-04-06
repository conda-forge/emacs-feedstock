#!/bin/bash

set -e

if [ "$(uname)" == "Darwin" ]; then
   pdump_file="${PREFIX}/Emacs.app/Contents/MacOS/libexec/Emacs.pdmp"

   if [ ! -s $pdump_file ]; then
      # Empty pdump file, we need to generate it now.
      cd ${PREFIX}/Emacs.app/Contents/Resources/lisp
      rm -f $pdump_file
      ${PREFIX}/Emacs.app/Contents/MacOS/Emacs -batch -l loadup --temacs=pdump >& /dev/null
      # Move the correct pdump file into place
      mv -f ${PREFIX}/Emacs.app/Contents/MacOS/emacs.pdmp $pdump_file
      # Remove extra "versioned" files that were created with the dump call
      rm -f ${PREFIX}/Emacs.app/Contents/MacOS/emacs-*
      echo "Successfully pre-compiled emacs lisp functions." >> "${PREFIX}/.messages.txt"
   fi
fi
