"""
Small script to do a binary replacement in every file in a directory

Usage
-----

python binary_replace.py old_string new_string directory/
"""

import sys
import os

def main():
    if len(sys.argv) != 4:
        sys.exit("Usage: binary_replace.py old_string new_string directory/")

    old = sys.argv[1]
    new = sys.argv[2]
    directory = sys.argv[3]

    old, new = old.encode('utf-8'), new.encode('utf-8')

    if len(old) != len(new):
        sys.exit("Error: The old and new strings must be of the same length")

    for dirpath, _, filenames in os.walk(directory):
        for file in filenames:
            replace(old, new, os.path.join(dirpath, file))

def replace(old, new, file):
    with open(file, 'br') as f:
        txt = f.read()
        new_txt = txt.replace(old, new)

    if new_txt != txt:
        print("Performing replacement in", file)
        with open(file, 'bw') as f:
            f.write(new_txt)

if __name__ == '__main__':
    exit(main())
