#!/bin/bash
# GNU/Linux Toolchain build script.
# Derived from Linux From Scratch
#
# only tested using i686! some x86_64 steps have been commented out,
# but you may need to check LFS guide to make sure they're correct.
# please let me know what needs to be changed if you manage to build
# an x86_64 toolchain.

set +h
set -e
umask 022

# parallel jobs compiler option
JOBS='-j2'

#build paths
TOPDIR=$(pwd)
PKGDIR=$(pwd)/system-pkgs
SRCDIR=$(pwd)/toolchain-src
PREFIX=/podhome/toolchain
FAKEROOT=/podhome/newsystem

export TARGET=$(uname -m)-xbuild-linux-gnu
export PATH="$PREFIX/bin:$PREFIX/usr/bin:/bin:/usr/bin"
export LC_ALL=C

mkdir -p $PREFIX
mkdir -p $SRCDIR

GLIBC_KERNELVERSION=4.1.0

# TODO -- generic extract function instead of hardcoding .xz .gz etc
# source packages
BINUTILS=binutils-2.26
GMP=gmp-6.1.0
MPFR=mpfr-3.1.3
MPC=mpc-1.0.3
GCC_VERSION=5.3.0
GCC=gcc-$GCC_VERSION
LINUX=linux-4.6
GLIBC=glibc-2.23
BASH=bash-4.4-rc1
COREUTILS=coreutils-8.25
UTIL_LINUX=util-linux-2.28
DIFFUTILS=diffutils-3.3
FILE=file-5.27
FINDUTILS=findutils-4.6.0
SED=sed-4.2.2
GAWK=gawk-4.1.3
GREP=grep-2.25
BZIP2=bzip2-1.0.6
GZIP=gzip-1.8
PATCH=patch-2.7.5
M4=m4-1.4.17
MAKE=make-4.2
ZLIB=zlib-1.2.8
XZ=xz-5.2.2
TAR=tar-1.29

# for documentation, localization, aka bloat
#TEXINFO=texinfo-6.1
#PERL_VERSION=5.24.0
#PERL=perl-$PERL_VERSION
#GETTEXT=gettext-0.19.7
# i have some slow old hardware so not running these tests right now
#TCL=tcl-8.6.2
#EXPECT=expect.5.45
#DEJAGNU=dejagnu-1.5.1
#CHECK=check-0.9.14

BUILD_START=$(date)
echo "Build started at $BUILD_START"
#disable stuff?
#if [ 5 -eq 7 ]; then


echo "###############################################################"
echo "BINUTILS - PASS 1"
echo "###############################################################"
echo "extracting: $BINUTILS"
tar -xf $PKGDIR/$BINUTILS.tar.gz -C $SRCDIR
mkdir $SRCDIR/$BINUTILS-build
cd $SRCDIR/$BINUTILS-build

../$BINUTILS/configure          \
    --target=$TARGET            \
    --prefix=$PREFIX            \
    --with-lib-path=$PREFIX/lib \
    --with-sysroot=$FAKEROOT    \
    --disable-nls               \
    --disable-werror
make $JOBS

#i'm using i686, don't need this
#if x86_64
#case $(uname -m) in
#    x86_64) mkdir -v /podhome/toolchain/lib && ln -sv lib /tools/lib64 ;;
#esac

make install

cd $TOPDIR
rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build


echo "###############################################################"
echo "GCC - PASS 1"
echo "###############################################################"
echo "extracting: $GCC"
tar -xf $PKGDIR/$GCC.tar.gz -C $SRCDIR
#move math code into expected locations
echo "extracting: $MPFR"
mkdir -v $SRCDIR/$GCC/mpfr
tar --strip-components=1 -xf $PKGDIR/$MPFR.tar.gz -C $SRCDIR/$GCC/mpfr
echo "extracting: $GMP"
mkdir -v $SRCDIR/$GCC/gmp
tar --strip-components=1 -xf $PKGDIR/$GMP.tar.xz -C $SRCDIR/$GCC/gmp
echo "extracting: $MPC"
mkdir -v $SRCDIR/$GCC/mpc
tar --strip-components=1 -xf $PKGDIR/$MPC.tar.gz -C $SRCDIR/$GCC/mpc

cd $SRCDIR/$GCC
echo "adjusting paths."
for file in \
    $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/podhome/toolchain&@g' \
        -e 's@/usr@/podhome/toolchain@g' $file.orig > $file
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/podhome/toolchain/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
    echo $file
done



mkdir $SRCDIR/$GCC-build
cd $SRCDIR/$GCC-build

../$GCC/configure                                               \
    --target=$TARGET                                            \
    --prefix=$PREFIX                                    	\
    --with-glibc-version=2.11					\
    --with-sysroot=$FAKEROOT                                    \
    --with-newlib                                       	\
    --without-headers                                   	\
    --with-native-system-header-dir=$PREFIX/include		\
    --with-local-prefix=$PREFIX                         	\
    --disable-nls                                       	\
    --disable-shared                                    	\
    --disable-multilib                                  	\
    --disable-decimal-float                             	\
    --disable-threads                                   	\
    --disable-libatomic                                 	\
    --disable-libgomp                                   	\
    --disable-libquadmath                               	\
    --disable-libssp						\
    --disable-libvtv                                    	\
    --disable-libstdcxx                                 	\
    --disable-libitm                                    	\
    --disable-libcilkrts                                	\
    --disable-libsanitizer                              	\
    --enable-languages=c,c++

make $JOBS
make install

cd $TOPDIR

rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/$GCC-build


echo "###############################################################"
echo "LINUX API HEADER"
echo "###############################################################"
echo "installing linux headers"
tar xf $PKGDIR/$LINUX.tar.xz -C $SRCDIR
cd $SRCDIR/$LINUX
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rfv dest/include/* $PREFIX/include
cd $TOPDIR
rm -rf $SRCDIR/$LINUX




echo "###############################################################"
echo "GLIBC"
echo "###############################################################"
echo "extracting: $GLIBC"
tar -xf $PKGDIR/$GLIBC.tar.xz -C $SRCDIR
mkdir $SRCDIR/$GLIBC-build

cd $SRCDIR/$GLIBC

patch -Np1 -i $PKGDIR/glibc-2.23-upstream_fixes-1.patch

cd $SRCDIR/$GLIBC-build


../$GLIBC/configure                             \
    --prefix=$PREFIX                            \
    --host=$TARGET                              \
    --build=$("../$GLIBC/scripts/config.guess") \
    --disable-profile                           \
    --with-headers=$PREFIX/include              \
    --enable-kernel=$GLIBC_KERNELVERSION        \
    libc_cv_forced_unwind=yes                   \
    libc_cv_ctors_header=yes                    \
    libc_cv_c_cleanup=yes
#these libc_cv flags are to disable tests for features
#that will fail untill second pass binutils is completed


make $JOBS
make install


# hacks on top of hacks!
mkdir -p $FAKEROOT/$PREFIX
rm -rf $FAKEROOT/$PREFIX
ln -sf $PREFIX $FAKEROOT/$PREFIX


cd $SRCDIR/$GLIBC-build

echo -e "\n\n\n**************************************************\n\
    running readelf binary test\nconfirm that this is the toolchain dynamic linker\n\
    eg /podhome/toolchain/lib/ld-linux.so.2\n\
    **************************************************"
echo 'int main(int argc, char *argv[]){return 0;}' > dummy.c
echo "CALLING GCC"
echo "PATH($PATH)"
$TARGET-gcc  -v dummy.c
echo "BUILT"
readelf -l a.out
echo "press the any key"
#read -n 1 -s anykey
rm -rf a.out
rm -rf dummy.c
cd $TOPDIR



rm -rf $SRCDIR/$GLIBC
rm -rf $SRCDIR/$GLIBC-build


echo "extracting fresh gcc sources"
tar -xf $PKGDIR/$GCC.tar.gz -C $SRCDIR
echo "building libstdc++-v3"
echo "###############################################################"
echo "LIBSTDC++"
echo "###############################################################"
mkdir $SRCDIR/libstdc++-build
cd $SRCDIR/libstdc++-build

CCP=$TARGET-ccp                 \
CC=$TARGET-gcc			\
AR=$TARGET-ar			\
AS=$TARGET-as			\
RANLIB=$TARGET-ranlib		\
../$GCC/libstdc++-v3/configure  \
    --host=$TARGET              \
    --prefix=$PREFIX            \
    --disable-multilib          \
    --disable-nls               \
    --disable-libstdcxx-threads \
    --disable-libstdcxx-pch     \
    --with-gxx-include-dir=$PREFIX/$TARGET/include/c++/$GCC_VERSION
##--disable-shared            \
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/libstdc++-build


echo "###############################################################"
echo "BINUTILS - PASS 2"
echo "###############################################################"

echo "binutils pass 2"
echo "extracting: $BINUTILS"
tar -xf $PKGDIR/$BINUTILS.tar.gz -C $SRCDIR
mkdir $SRCDIR/$BINUTILS-build
cd $SRCDIR/$BINUTILS-build

CC=$TARGET-gcc			\
AR=$TARGET-ar			\
RANLIB=$TARGET-ranlib		\
../$BINUTILS/configure		\
    --prefix=$PREFIX            \
    --with-sysroot		\
    --with-lib-path=$PREFIX/lib \
    --disable-nls               \
    --disable-werror

make $JOBS
#make $JOBS -k check
#echo "press the any key"
#read -n 1 -s anykey

make install

# prepare a new linker for re-adjusting phase later on.
make -C ld clean
make -C ld LIB_PATH=/lib:/usr/lib
cp -vf ld/ld-new $PREFIX/bin

cd $TOPDIR

rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build


echo "###############################################################"
echo "GCC - PASS 2"
echo "###############################################################"
echo "extracting: $GCC"
tar -xf $PKGDIR/$GCC.tar.gz -C $SRCDIR
#move math code into expected location
echo "extracting: $MPFR"
mkdir -v $SRCDIR/$GCC/mpfr
tar --strip-components=1 -xf $PKGDIR/$MPFR.tar.gz -C $SRCDIR/$GCC/mpfr
echo "extracting: $GMP"
mkdir -v $SRCDIR/$GCC/gmp
tar --strip-components=1 -xf $PKGDIR/$GMP.tar.xz -C $SRCDIR/$GCC/gmp
echo "extracting: $MPC"
mkdir -v $SRCDIR/$GCC/mpc
tar --strip-components=1 -xf $PKGDIR/$MPC.tar.gz -C $SRCDIR/$GCC/mpc

echo "fixing limits"
cd $SRCDIR/$GCC
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($TARGET-gcc -print-libgcc-file-name)`/include-fixed/limits.h

#do some voodoo to change hardcoded linker to new tools linker
echo "modifying paths."
for file in \
    $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/podhome/toolchain&@g' \
        -e 's@/usr@/podhome/toolchain@g' $file.orig > $file
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/podhome/toolchain/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
    #echo $file
done
#uncomment to make sure paths were modified
#echo "done.  press the any key"
#read -n 1 -s anykey

cd $SRCDIR/$GCC
mkdir $SRCDIR/$GCC-build
cd $SRCDIR/$GCC-build

#set cross compiler
#build it normally with the toolchain we just built
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
RANLIB="$TARGET-ranlib"                                 \
../$GCC/configure                                       \
    --prefix=$PREFIX                                    \
    --with-local-prefix=$PREFIX                         \
    --with-native-system-header-dir=$PREFIX/include     \
    --disable-libstdcxx-pch                             \
    --disable-multilib                                  \
    --disable-bootstrap                                 \
    --disable-libgomp                                   \
    --enable-languages=c,c++
# note: c++ is required to boot strap gcc >= 4.8

make $JOBS
#make $JOBS -k check

#echo "press the any key"
#read -n 1 -s anykey

make install

##symlink for any packages that use cc
ln -sv gcc $PREFIX/bin/cc


#read the elf and verify correctness.
echo -e "\n\n\n**************************************************\n\
    running readelf binary test\nconfirm that this is the toolchain dynamic linker\n\
    eg /podhome/toolchain/lib/ld-linux.so.2\n\
**************************************************"
echo 'int main(int argc, char *argv[]){return 0;}' > dummy.c
cc dummy.c
readelf -l a.out
echo "press the any key"
#read -n 1 -s anykey

rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/$GCC-build


echo "###############################################################"
echo "BASH"
echo "###############################################################"
echo "extracting: $BASH"
tar -xf $PKGDIR/$BASH.tar.gz -C $SRCDIR

cd $SRCDIR/$BASH

CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure                                             \
    --prefix=$PREFIX                                    \
    --without-bash-malloc

make $JOBS
make install

#symlink bash to sh!!
ln -sv bash $PREFIX/bin/sh
cd $TOPDIR

rm -rf $SRCDIR/$BASH
rm -rf $SRCDIR/$BASH-build


echo "###############################################################"
echo "BZIP2"
echo "###############################################################"
echo "extracting: $BZIP2"
tar -xf $PKGDIR/$BZIP2.tar.gz -C $SRCDIR

cd $SRCDIR/$BZIP2
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
make $JOBS
make PREFIX=$PREFIX install

cd $TOPDIR
rm -rf $SRCDIR/$BZIP2
rm -rf $SRCDIR/$BZIP2-build



echo "###############################################################"
echo "COREUTILS"
echo "###############################################################"
echo "extracting: $COREUTILS"
tar -xf $PKGDIR/$COREUTILS.tar.xz -C $SRCDIR

cd $SRCDIR/$COREUTILS

CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure                                             \
    --prefix=$PREFIX                                    \
    --enable-install-program=hostname

make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$COREUTILS
rm -rf $SRCDIR/$COREUTILS-build



echo "###############################################################"
echo "DIFFUTILS"
echo "###############################################################"
echo "extracting: $DIFFUTILS"
tar -xf $PKGDIR/$DIFFUTILS.tar.xz -C $SRCDIR

cd $SRCDIR/$DIFFUTILS
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX

make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$DIFFUTILS
rm -rf $SRCDIR/$DIFFUTILS-build

echo "###############################################################"
echo "FILE"
echo "###############################################################"
echo "extracting: $FILE"
tar -xf $PKGDIR/$FILE.tar.gz -C $SRCDIR

cd $SRCDIR/$FILE
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$FILE
rm -rf $SRCDIR/$FILE-build

echo "###############################################################"
echo "FINDUTILS"
echo "###############################################################"
echo "extracting: $FINDUTILS"
tar -xf $PKGDIR/$FINDUTILS.tar.gz -C $SRCDIR

cd $SRCDIR/$FINDUTILS
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$FINDUTILS
rm -rf $SRCDIR/$FINDUTILS-build


echo "###############################################################"
echo "GAWK"
echo "###############################################################"
echo "extracting: $GAWK"
tar -xf $PKGDIR/$GAWK.tar.xz -C $SRCDIR

cd $SRCDIR/$GAWK
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GAWK
rm -rf $SRCDIR/$GAWK-build


echo "###############################################################"
echo "GREP"
echo "###############################################################"
echo "extracting: $GREP"
tar -xf $PKGDIR/$GREP.tar.xz -C $SRCDIR

cd $SRCDIR/$GREP
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GREP
rm -rf $SRCDIR/$GREP-build



echo "###############################################################"
echo "GZIP"
echo "###############################################################"
echo "extracting: $GZIP"
tar -xf $PKGDIR/$GZIP.tar.xz -C $SRCDIR

cd $SRCDIR/$GZIP
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GZIP
rm -rf $SRCDIR/$GZIP-build



echo "###############################################################"
echo "M4"
echo "###############################################################"
echo "extracting: $M4"
tar -xf $PKGDIR/$M4.tar.xz -C $SRCDIR

cd $SRCDIR/$M4
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$M4
rm -rf $SRCDIR/$M4-build



echo "###############################################################"
echo "MAKE"
echo "###############################################################"
echo "extracting: $MAKE"
tar -xf $PKGDIR/$MAKE.tar.gz -C $SRCDIR

cd $SRCDIR/$MAKE
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure             \
    --prefix=$PREFIX    \
    --without-guile
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$MAKE
rm -rf $SRCDIR/$MAKE-build


echo "###############################################################"
echo "PATCH"
echo "###############################################################"
echo "extracting: $PATCH"
tar -xf $PKGDIR/$PATCH.tar.xz -C $SRCDIR

cd $SRCDIR/$PATCH
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$PATCH
rm -rf $SRCDIR/$PATCH-build



echo "###############################################################"
echo "TAR"
echo "###############################################################"
echo "extracting: $TAR"
tar -xf $PKGDIR/$TAR.tar.xz -C $SRCDIR

cd $SRCDIR/$TAR
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$TAR
rm -rf $SRCDIR/$TAR-build


echo "###############################################################"
echo "XZ"
echo "###############################################################"
echo "extracting: $XZ"
tar -xf $PKGDIR/$XZ.tar.gz -C $SRCDIR

cd $SRCDIR/$XZ
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$XZ
rm -rf $SRCDIR/$XZ-build


echo "###############################################################"
echo "SED"
echo "###############################################################"
echo "extracting: $SED"
tar -xf $PKGDIR/$SED.tar.gz -C $SRCDIR

cd $SRCDIR/$SED
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$SED
rm -rf $SRCDIR/$SED-build



set +e
echo "removing cross compiler"
find . -iname "*$TARGET*" -exec rm -rfv {} \;
set -e

echo "strip debug info from binaries? (faster compression time)  y / n ]"
ack="y"
#read -n 1 -s ack
if [ "$ack" == "y" ] || [ "$ack" == "Y" ]; then
	cd $PREFIX
	find -type f -exec $PREFIX/bin/strip --strip-debug {} \;
	cd $PREFIX/bin
	find -type f -exec $PREFIX/bin/strip --strip-unneeded {} \;
	cd $PREFIX/sbin
	find -type f -exec $PREFIX/bin/strip --strip-unneeded {} \;

	cd $TOPDIR
fi


echo "strip extras (documentation, share data) y / n ]"
ack="y"
#read -n 1 -s ack
if [ "$ack" == "y" ] || [ "$ack" == "Y" ]; then
	cd $PREFIX
	rm -rfv $PREFIX/share/{info,man,doc}
	cd $TOPDIR
fi

cd $TOPDIR
echo "compressing toolchain (very slow if not stripped)"
$PREFIX/bin/tar -cJf toolchain.xz toolchain

echo "------------ generating checksums --------------"
echo "md5..."
$PREFIX/bin/md5sum toolchain.xz
echo ""
echo "sha1....."
$PREFIX/bin/sha1sum toolchain.xz
echo ""
echo "sha256........."
$PREFIX/bin/sha256sum toolchain.xz
echo ""
echo "sha384.........................."
$PREFIX/bin/sha384sum toolchain.xz
echo ""
echo "sha512..................................."
$PREFIX/bin/sha512sum toolchain.xz
echo ""
echo "------------------------------------------------"
echo "write these down and store somewhere secure :) "
echo "------------------------------------------------"

BUILD_END=$(date)
echo ""
echo ""
echo "Build was started at $BUILD_START"
echo "Completed at $BUILD_END"
echo ""
echo "Toolchain is ready for use"

