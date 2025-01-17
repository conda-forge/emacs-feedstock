# 
1 i set -x
/^set\s+".*"$/ {
  s/^set "([^=]+)=(.*)"$/\1=\2/
  h
  s/^([^=]+)=.*$/\1/
  # handle special cases
  /[(|)]/ {
    s/[(|)]/_/g
  }
  /^PATH$/ {
    s/^PATH$/BUILD_BAT_PATH/
  }
  x
  s/^([^=]+)=(.*)$/\2/
  s/(\$|"|\\|`)/\\\1/g
  s/%([^%]+)%/${\1}/g
  s|^[A-Z]:\\.*$|$(/usr/bin/cygpath -p "\0")|
  s/^.*$/"\0"/
  x
  G
  s/\n/=/
  s/^.*$/export \0/
  p
  d
}
/^@echo(\s.*)?$/ d
/^call\s+([^ ].*)\s*$/ {
  s/^call\s+(\S.*)\s*$/\1/
  /^"?(.*)conda_hook\.bat"?(\s.*)?$/ {
    s|^"?(.*)conda_hook\.bat"?(\s+(\S.*)?)?$|ask_conda="$(eval "$(realpath "$(cygpath '\1')"/../Scripts/conda.exe)" shell.posix hook\2)"\neval "$ask_conda"|p
    # prevent any duplicate copies of MSYS-2.0.dll from PATH taking precedence
	i PATH="$(echo "$PATH" | sed -E 's|:([^:]+/Library/usr/bin):|:|g')"
    d
  }
  /^"?(.*)conda\.bat"?\s+activate(\s.*)?$/ {
    s|^"?(.*)conda\.bat"?\s+activate(\s+(\S.*)?)?$|\3|
    h
    z
    s/^$/\n/
    x
    : loop
    # If remaining unprocessed contains no words, we
    # are done with this command
    /^\s*$/ {
      z
      s/^$/conda activate/
      G
      s/\n/ /g
      s/ $//
      p
      # prevent any duplicate copies of MSYS-2.0.dll from PATH taking precedence
      i PATH="$(echo "$PATH" | sed -E 's|:([^:]+/Library/usr/bin):|:|g')"
      d
    }
    # at start of loop, there is no unproceesd data in hold space,
    # all remaining unprocessed line is in pattern space
    H
    # hold space is \n(<processed word>\n)*\n<unprocessed data>
    # so \n\n always separates processed from unprocessed
    x
    /^(.*)\n\n"[^"]+"\s*$/ {
       s/^(.*)\n\n"[^"]+"\s*$/\1\n\n/
       x
       s/^"([^"]+)"\s*$/\1/
       b got_first
    }
    /^(.*)\n\n"[^"]+"\s+(\S.*)$/ {
       s/^(.*)\n\n"[^"]+"\s+(\S.*)$/\1\n\n\2/
       x
       s/^"([^"]+)"\s.*$/\1/
       b got_first
    }
    /^(.*)\n\n\S+\s*$/ {
       s/^(.*)\n\n\S+\s*$/\1\n\n/
       x
       s/^(\S+)\s*$/\1/
       b got_first
    }
    /^(.*)\n\n\S+\s+\S.*$/ {
       s/^(.*)\n\n\S+\s+(\S.*)$/\1\n\n\2/
       x
       s/^(\S+)\s.*$/\1/
       b got_first
    }
    # something is wrong
    i Unexpected processing state
    Q1
    : got_first
    s/(\$|"|\\|`)/\\\1/g
    s/%([^%]+)%/${\1}/g
    s|^[A-Z]:\\.*$|$(/usr/bin/cygpath -p "&")|
    s/^.*$/"&"/
    G
    # Note the first word is in quotes, so not empty
    # Retrieve processed words in correct order, discard unprocessed tail
    s/^([^\n]+)\n(.*)\n\n(.*)$/\2\n\1\n/
    # put processed words back in hold space
    x
    # Now get unprocessed tail
    /^(.*)\n\n(.*)/! {
      i Unexpected processing state
      Q1
    }
    s/^(.*)\n\n(.*)/\2/
    b loop
  }
}

