#/bin/bash

../cmake.sh . -DZLIB_COMPAT=ON -DZLIB_ENABLE_TESTS=OFF

make install -j4