#!/bin/sh

WHAT_TO_RUN="$1"
BUILD_TRIPLET=`sh ./config/config.guess`
WORKDIR="$PWD"
export MANIFEST_TOOL=:

crosscompile_icu()
{
    # Download & Extract icu
    if [ ! -e "icu4c-57_1-src.tgz" ]; then 
        wget "http://download.icu-project.org/files/icu4c/57.1/icu4c-57_1-src.tgz"
    fi
    echo "976734806026a4ef8bdd17937c8898b9  icu4c-57_1-src.tgz" | md5sum -c || exit 1
    tar xzf "icu4c-57_1-src.tgz" # creates directory "icu"

    # We have to build icu twice: Once for the build system and once for the
    # host system. First the build system:
    mkdir icu_build_build
    cd icu_build_build
    ../icu/source/configure "$@" || exit 1
    make || exit 1

    # Now the host system:
    cd "${WORKDIR}"
    mkdir icu_build_host
    cd icu_build_host

    export CC=${HOST_TRIPLET}-gcc
    export CXX=${HOST_TRIPLET}-g++
    export LD=${HOST_TRIPLET}-ld
    export RANLIB=${HOST_TRIPLET}-ranlib
    export AR=${HOST_TRIPLET}-ar
    ../icu/source/configure --host=${HOST_TRIPLET} --build=${BUILD_TRIPLET} \
                            --with-cross-build="${WORKDIR}/icu_build_build" \
                            --prefix="${WORKDIR}/install" "$@"  || exit 1
    make || exit 1
    make install || exit 1
    cd "${WORKDIR}"
}

fix_icu_dll_filenames()
{
    # The linker will fail to find icu*.dll files if they don't start with lib
    # An easy workaround is to have a copy of each dll (or a soft link) with
    # a different name: icuuc57.dll -> libicuuc57.dll 
    cd "$WORKDIR/install/lib"
    for file in `ls icu*.dll`; do ln -s "$file" "lib"$file; done
    cd "$WORKDIR"
}

crosscompile_portaudio()
{
    # Download & Extract portaudio
    if [ ! -e "pa_stable_v19_20140130.tgz" ]; then 
        wget "http://www.portaudio.com/archives/pa_stable_v19_20140130.tgz"
    fi
    echo "7f220406902af9dca009668e198cbd23  pa_stable_v19_20140130.tgz" | md5sum -c || exit 1
    tar xzf "pa_stable_v19_20140130.tgz" # creates directory "portaudio"
    # Cross compile portaudio:
    mkdir portaudio_build
    cd portaudio_build
    ../portaudio/configure --build="${BUILD_TRIPLET}" \
                           --prefix="$WORKDIR/install" \
                            "$@" || exit 1
    make || exit 1
    make install || exit 1
    cd "${WORKDIR}"
}

crosscompile() 
{
    # Cross compile mimic:
    cd "$WORKDIR" || exit 1
    export PKG_CONFIG_PATH="$WORKDIR/install/lib/pkgconfig/"
    mkdir mimic_build || exit 1
    cd mimic_build || exit 1
    ../configure --build="${BUILD_TRIPLET}" \
                 --prefix="$WORKDIR/install" \
                 "$@" || exit 1
    make || exit 1
    make install || exit 1
    cd "${WORKDIR}"
}

put_dll_in_bindir()
{
    cd "${WORKDIR}"
    # This one is needed from the mingw32-runtime package
    if [ -f /usr/share/doc/mingw32-runtime/mingwm10.dll.gz ]; then
        cat /usr/share/doc/mingw32-runtime/mingwm10.dll.gz | gunzip > "$WORKDIR/install/bin/mingwm10.dll" || exit 1
    else
        # it seems travis does not find it, so we get it directly from the package
        apt-get download mingw32-runtime || exit 1
        ar p mingw32-runtime*.deb data.tar.gz | tar zx || exit 1
        cat usr/share/doc/mingw32-runtime/mingwm10.dll.gz | gunzip > "$WORKDIR/install/bin/mingwm10.dll"
        
    fi
    # ICU libraries are installed into lib. wine can't find them.
    cp "${WORKDIR}/install/lib/"*.dll "${WORKDIR}/install/bin/"
    cd "${WORKDIR}"
}


case "${WHAT_TO_RUN}" in
  osx)
    brew install pkg-config portaudio icu4c || exit 1
    export ICU_CFLAGS="-I/usr/local/opt/icu4c/include"
    export ICU_LIBS="-L/usr/local/opt/icu4c/lib"

    ./configure || exit 1
    make || exit 1
    make check || exit 1
    ;;
  coverage)
    ./autogen.sh
    # for ubuntu precise in travis, that does not provide pkg-config:
    pkg-config --exists icu-uc || export CFLAGS="$CFLAGS -I/usr/include/x86_64-linux-gnu"
    pkg-config --exists icu-uc || export LDFLAGS="$LDFLAGS -licuuc -licudata"
    ./configure  CFLAGS="$CFLAGS --coverage --no-inline" LDFLAGS="$LDFLAGS --coverage" || exit 1
    make || exit 1
    make check || exit 1
    ./do_gcov.sh
    ;;
  shared)
    ./autogen.sh
    # for ubuntu precise in travis, that does not provide pkg-config:
    pkg-config --exists icu-uc || export CFLAGS="$CFLAGS -I/usr/include/x86_64-linux-gnu"
    pkg-config --exists icu-uc || export LDFLAGS="$LDFLAGS -licuuc -licudata"
    ./configure  --enable-shared || exit 1
    make || exit 1
    make check || exit 1
    ;;
  arm-linux-gnueabihf-gcc)
    export HOST_TRIPLET="arm-linux-gnueabihf"
    crosscompile_icu
    export CC=${HOST_TRIPLET}-gcc
    export CXX=${HOST_TRIPLET}-g++
    export LD=${HOST_TRIPLET}-ld
    export RANLIB=${HOST_TRIPLET}-ranlib
    export AR=${HOST_TRIPLET}-ar
    ./autogen.sh
    crosscompile --host="${HOST_TRIPLET}" --with-audio=none    
    ;;
  winbuild)
    export HOST_TRIPLET="i586-mingw32msvc"
    # export HOST_TRIPLET="i686-w64-mingw32"
    crosscompile_icu
    export CC=${HOST_TRIPLET}-gcc
    export CXX=${HOST_TRIPLET}-g++
    export LD=${HOST_TRIPLET}-ld
    export RANLIB=${HOST_TRIPLET}-ranlib
    export AR=${HOST_TRIPLET}-ar
    ./autogen.sh
    #crosscompile_portaudio --host=${HOST_TRIPLET} --enable-shared
    crosscompile --host=${HOST_TRIPLET} --with-audio=none
    # Test mimic:
    cd "$WORKDIR" || exit 1
    xvfb-run wine "install/bin/mimic.exe" -voice ap -t "hello world" "hello_world_winbuild.wav" || exit 1
    ;;
  winbuild_shared)
    export HOST_TRIPLET="i586-mingw32msvc"
    crosscompile_icu --enable-shared
    fix_icu_dll_filenames
    export CC=${HOST_TRIPLET}-gcc
    export CXX=${HOST_TRIPLET}-g++
    export LD=${HOST_TRIPLET}-ld
    export RANLIB=${HOST_TRIPLET}-ranlib
    export AR=${HOST_TRIPLET}-ar
    ./autogen.sh
    #crosscompile_portaudio --host=${HOST_TRIPLET} --enable-shared
    crosscompile --host="${HOST_TRIPLET}" --enable-shared --with-audio=none
    put_dll_in_bindir
    # Test mimic:
    cd "$WORKDIR" || exit 1
    xvfb-run wine "install/bin/mimic.exe" -voice ap -t "hello world" "hello_world_winbuild_shared.wav" || exit 1
    ;;
  *)
    echo "Unknown WHAT_TO_RUN: ${WHAT_TO_RUN}"
    exit 1
    ;;
esac


