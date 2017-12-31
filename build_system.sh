#/bin/bash
# (C) 2017 GPLv3+ (GNU gpl version 3 or later)
# Derived from Linux From Scratch
# For use with jettison PODROOT_HOME_OVERRIDE special build.
# TODO add option to run tests
set -e
set +h
umask 022

GLIBC_KERNELVERSION=3.10

# compiler parallel jobs
JOBS='-j2'

TOPDIR=/podhome
INSTPREFIX=/usr
TOOLCHAIN=/podhome/toolchain
SRCDIR=/podhome/system-src
PKGDIR=/podhome/system-pkgs
CHKLOG=system-buildtest-logs

export LC_ALL=C
export PATH=/bin:/usr/bin:$TOOLCHAIN/bin

# CORE SYSTEM
BINUTILS=binutils-2.29
GMP=gmp-6.1.2
MPFR=mpfr-3.1.6
MPC=mpc-1.0.3
GCC_VERSION=7.2.0
GCC=gcc-$GCC_VERSION
LINUX=linux-4.14.8
GLIBC=glibc-2.26
BASH=bash-4.4
COREUTILS=coreutils-8.28
DIFFUTILS=diffutils-3.6
SED=sed-4.4
GAWK=gawk-4.1.4
GREP=grep-3.0
M4=m4-1.4.18
FINDUTILS=findutils-4.6.0
GZIP=gzip-1.8
PATCH=patch-2.7.5
MAKE=make-4.2.1
TAR=tar-1.30
UTIL_LINUX=util-linux-2.31
ZLIB=zlib-1.2.11
XZ=xz-5.2.3
BZIP2=bzip2-1.0.6
FILE=file-5.30
E2FSPROGS=e2fsprogs-1.43.7
KMOD=kmod-24

#TCL=tcl-8.6.2
#EXPECT=expect.5.45
#DEJAGNU=dejagnu-1.5.1
#CHECK=check-0.9.14
#PERL_VERSION=5.24.0
#PERL=perl-$PERL_VERSION

mkdir -pv $SRCDIR

# arg 1: filepath, arg 2: destination directory, arg 3: additional arguments
decompress()
{
	if [ -z "$1" ]; then
		echo "decompress missing file parameter"
		exit -1
	fi
	if [ -z "$2" ]; then
		echo "decompress missing destination directory"
		exit -1
	fi
	DEST=$2
	OPTS=""
	if [ -n "$3" ]; then
		OPTS="$3"
	fi

	if [ -e $PKGDIR/$1.tar.xz ]; then
		PKG="$1.tar.xz"
	elif [ -e $PKGDIR/$1.tar.gz ]; then
		PKG="$1.tar.gz"
	elif [ -e $PKGDIR/$1.tar.bz2 ]; then
		PKG="$1.tar.bz2"
	else
		echo "archive not found or not recognized: $PKG"
		exit -1
	fi
	echo "decompressing $PKG"
	tar $OPTS -xf $PKGDIR/$PKG -C $DEST
}



#disable already installed packages using this if check
#if [ 1 -eq 99 ]; then
#TODO -- test tools, tcl expect, perl



##############################################################
# LINUX API HEADERS
##############################################################
echo "extracting linux headers"
decompress $LINUX $SRCDIR
cd $SRCDIR/$LINUX
make mrproper
echo "installing linux headers"
make INSTALL_HDR_PATH=dest headers_install
#find dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv dest/include/* $INSTPREFIX/include
#cd $INSTPREFIX/include
#find -name '*.install*' -exec rm -v ./{} \;
cd $TOPDIR
rm -rf $SRCDIR/$LINUX



##############################################################
# GLIBC
##############################################################
echo "extracting: $GLIBC"
decompress $GLIBC $SRCDIR
cd $SRCDIR/$GLIBC
mkdir $SRCDIR/$GLIBC-build
cd $SRCDIR/$GLIBC-build


../$GLIBC/configure                             \
    --prefix=$INSTPREFIX                        \
    --disable-profile                           \
    --enable-kernel=$GLIBC_KERNELVERSION	\
    --enable-stackguard-randomization		\
    --enable-stack-protector=strong		\
    --enable-bind-now

# --enable-lock-elision=yes/no -- some intel specific TSX hack for pthread mutex.
# --enable-bind-now resolve PLT on DSO load, instead of on demand via trampoline
# i think this removes a level of indirection, have not confirmed the inner workings.

make $JOBS
#this test is considered critical
#make check > $TESTDIR/$GLIBC.make-test

cd $SRCDIR/$GLIBC-build


touch /etc/ld.so.conf
make install

#install conf and runtime dir for ncsd
cp -vf ../$GLIBC/nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd

#configure dynamic loader
echo "# Begin /etc/ld.so.conf
/usr/local/lib

"> /etc/ld.so.conf



#echo "creating nsswitch.conf"
#echo "# Begin /etc/nsswitch.conf
#passwd: files
#group:  files
#shadow: files
#
#hosts:    files dns
#networks: files
#
#protocols: files
#services:  files
#ethers:    files
#rpc:       files
#
## End /etc/nsswitch.conf
#"> /etc/nsswitch.conf




###############################################################
# ADJUST TOOLCHAIN
###############################################################

echo "adjusting the toolchain"

#we want to use the 2'nd linker that has /lib interp path
mv -vf $TOOLCHAIN/bin/{ld,ld-old}
mv -vf $TOOLCHAIN/$(gcc -dumpmachine)/bin/{ld,ld-old}
mv -vf $TOOLCHAIN/bin/{ld-new,ld}

ln -sfv $TOOLCHAIN/bin/ld $TOOLCHAIN/$(gcc -dumpmachine)/bin/ld

#change gcc specs
gcc -dumpspecs | sed -e 's@/podhome/toolchain@@g'               \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs

echo "inspect specs file and verify no references to toolchain exists"
echo "$(gcc --print-libgcc-file-name)/specs"
#echo "press any key to continue"
#read -n 1 -s anykey


#run sanity check, make sure it's using the right linker
echo -e "\n\n**************************************************************\n\
    running readelf binary test\nconfirm that this is the toolchain dynamic linker\n\
    eg: /lib/ld-linux.so.2\n\
    **************************************************************"

echo 'int main(){return 0;}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out
echo ""
echo "*** verify there are 3 messages below here ***"
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
echo ""
echo "*** verify include search starts with/contains /usr/include ***"
grep -B1 '^ /usr/include' dummy.log
echo ""
echo "*** verify search dirs /usr/lib && /lib ***"
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
echo ""
echo "*** verify /lib/libc.so.6 ***"
grep "/lib.*/libc.so.6 " dummy.log
echo ""
#if building 64bit,  lib64 is expected
echo "*** verify ld-linux.so.2 at /lib/ld-linux.so.2***"
grep found dummy.log
echo "if all of these checks seem ok, you may continue"
echo "press the any key to continue"
#read -n 1 -s anykey

cd $TOPDIR

rm -rf $SRCDIR/$GLIBC
rm -rf $SRCDIR/$GLIBC-build


###############################################################
# ZLIB
###############################################################
echo "extracting $ZLIB"
decompress $ZLIB $SRCDIR
cd $SRCDIR/$ZLIB

./configure --prefix=/usr
make $JOBS
#make check > $TESTDIR/$ZLIB.make-check
make install

#echo "moving lib and symlink"
#mv -v /usr/lib/libz.so.* /lib
#ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
cd $TOPDIR
rm -rf $SRCDIR/$ZLIB



###############################################################
# FILE
###############################################################
echo "extracting $FILE"
decompress $FILE $SRCDIR
cd $SRCDIR/$FILE

./configure --prefix=/usr
make $JOBS
#make check > $TESTDIR/$FILE.make-check
make install

cd $TOPDIR
rm -rf $SRCDIR/$FILE



###############################################################
# BINUTILS
###############################################################
echo "extracting: $BINUTILS"
decompress $BINUTILS $SRCDIR
cd $SRCDIR/$BINUTILS
#TODO testing, verify expect works
#expect -c "spawn ls"

#suppress outdated standards.info file
#rm -fv etc/standards.info
#sed -i.bak '/^INFO/s/standards.info //' etc/Makefile.in

mkdir $SRCDIR/$BINUTILS-build
cd $SRCDIR/$BINUTILS-build

../$BINUTILS/configure     \
    --prefix=/usr          \
    --enable-shared        \
    --disable-werror       \
    --enable-libssp	   \
    --enable-vtable-verify \
    --with-system-zlib

#    --enable-gold

make $JOBS
#make $JOBS tooldir=/usr
#make -k check > $TESTDIR/$BINUTILS.make-check
make install
#make tooldir=/usr install

cd $TOPDIR
rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build


###############################################################
# GMP
###############################################################
echo "extracting $GMP"
mkdir $SRCDIR/$GMP
decompress $GMP $SRCDIR
cd $SRCDIR/$GMP

#ABI flag is for building 32bit abi on 64bit hardware
#if building 64bit, you may omit this variable
ABI=32              \
./configure         \
    --prefix=/usr
#    --enable-cxx
make $JOBS

#requires perl
#make html

#make check 2>&1 | tee gmp-check-log
#make check > $TESTDIR/$GMP.make-check
#awk '/tests passed/{total+=$2} ; END{print total}' gmp-check-log
#should be all(188) tests passed
make install
#make install-html

cd $TOPDIR
rm -rf $SRCDIR/$GMP



###############################################################
# MPFR
###############################################################
echo "extracting $MPFR"
decompress $MPFR $SRCDIR
cd $SRCDIR/$MPFR

./configure                 \
    --prefix=/usr
#    --enable-thread-safe
make $JOBS
#make html
#make check > $TESTDIR/$MPFR.make-check
make install
#make install-html

cd $TOPDIR
rm -rf $SRCDIR/$MPFR



###############################################################
# MPC
###############################################################
echo "extracting $MPC"
decompress $MPC $SRCDIR
cd $SRCDIR/$MPC

./configure                 \
    --prefix=/usr
make $JOBS
#make html
#make check > $TESTDIR/$MPC.make-check
make install
#make install-html

cd $TOPDIR
rm -rf $SRCDIR/$MPC



###############################################################
# GCC
###############################################################
echo "extracting: $GCC"
decompress $GCC $SRCDIR
cd $SRCDIR/$GCC

# i have no idea what this one does...
# sed -i 's/if \((code.*))\)/if (\1 \&\& \!DEBUG_INSN_P (insn))/' gcc/sched-deps.c

mkdir $SRCDIR/$GCC-build
cd $SRCDIR/$GCC-build

#set sed to avoid a hardcoded path to /podhome/toolchain/bin/sed
SED=sed                         \
../$GCC/configure               \
    --prefix=/usr               \
    --disable-multilib          \
    --disable-bootstrap         \
    --with-system-zlib          \
    --disable-lto		\
    --enable-languages=c,c++
#    --disable-libvtv		\
#    --disable-libsanitizer	\

make $JOBS

echo "resuming gcc test"
cd $SRCDIR/$GCC-build

#one test suite is known to exhaust stack?
#ulimit -s 32768

#make -k check | grep -A7 "Summ." > $TESTDIR/$GCC.make-check
#for summary
#../$GCC/contrib/test_summary
#for only summaries | grep -A7 Summ.
#can compare with linuxfromscratch.org/lfs/build-logs/7.6/
#gcc.gnu.org/ml/gcc/testresults/

#echo "press the any key"
#read -n 1 -s anykey

make install

#cc symlink
ln -sv gcc /usr/bin/cc

#read the elf and verify correctness.
echo -e "\n\n\n**************************************************\n\
    running readelf binary test\nconfirm that this is the toolchain dynamic linker\n\
    eg /lib/ld-linux.so.2\n\
    **************************************************"
echo 'int main(){return 0;}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out

echo ""
echo "*** verify there are 3 messages below here ***"
echo " eg: /usr/lib/gcc/i686-pc-linux-gnu/4.9.1/../../../crt1.o succeeded"
echo "------------------------------------------------------------------"
grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log
echo ""
echo "*** verify include search starts with/contains /usr/include ***"
grep -B4 '^ /usr/include' dummy.log
echo ""
echo "*** verify search dirs ***"
echo "SEARCH_DIR(/usr/i686-pc-linux-gnu/lib32)"
echo "SEARCH_DIR(/usr/local/lib32)"
echo "SEARCH_DIR(/lib32)"
echo "SEARCH_DIR(/usr/lib32)"
echo "SEARCH_DIR(/usr/i686-pc-linux-gnu/lib)"
echo "SEARCH_DIR(/usr/local/lib)"
echo "SEARCH_DIR(/lib)"
echo "SEARCH_DIR(/usr/lib);"
echo "-----------------------------------------"
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
echo ""
echo "*** verify /lib/libc.so.6 ***"
grep "/lib.*/libc.so.6 " dummy.log
echo ""
# if building 64bit,  lib64 is expected
echo "*** verify ld-linux.so.2 at /lib/ld-linux.so.2***"
grep found dummy.log
echo "if all of these checks seem ok, you may continue"


echo "press the any key"
#read -n 1 -s anykey

cd $TOPDIR


rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/$GCC-build


##############################################################
# adjust gcc specs
# e.g: https://wiki.gentoo.org/wiki/Hardened/Toolchain
##############################################################

# enable relro linker flag by default
gcc -dumpspecs | sed 's#%{pie:-pie}#%{pie:-pie} %{!norelro: -z relro} %{relro: }#' > \
			`dirname $(gcc --print-libgcc-file-name)`/specs

###############################################################
# BASH
###############################################################
echo "extracting $BASH"
decompress $BASH $SRCDIR
cd $SRCDIR/$BASH

./configure --prefix=/usr  	             	\
            --bindir=/bin                       \
            --without-bash-malloc		\
	    --disable-rpath			\
	    --disable-net-redirection
make $JOBS

#requires shadow
#chown -Rv nobody .
#su nobody -s /bin/bash -c "PATH=$PATH make tests"
#make check

make install

cd $TOPDIR
rm -rf $SRCDIR/$BASH

###############################################################
# COREUTILS
###############################################################
echo "extracting $COREUTILS"
decompress $COREUTILS $SRCDIR
cd $SRCDIR/$COREUTILS

./configure		\
    --prefix=/usr

#must have shadow installed to su
#make NON_ROOT_USERNAME=nobody check-root
# no shadow installed right now so i commented these out
#echo "dummy:x:1000:nobody" >> /etc/group
#chown -Rv nobody .
#su nobody -s /bin/bash \
#          -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"

make $JOBS
#sed -i '/dummy/d' /etc/group


make install

#Move programs to the locations specified by the FHS:
#mv -vf /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
#mv -vf /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
#mv -vf /usr/bin/{rmdir,stty,sync,true,uname} /bin
#mv -vf /usr/bin/chroot /sbin
#mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
#sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8

#Some of the scripts in the LFS-Bootscripts package depend on head,
#sleep, and nice. As /usr may not be available during the early stages
#of booting, those binaries need to be on the root partition:
#mv -vf /usr/bin/{head,sleep,nice,test,[} /bin


cd $TOPDIR
rm -rf $SRCDIR/$COREUTILS



###############################################################
# BZIP2
###############################################################
echo "extracting $BZIP2"
decompress $BZIP2 $SRCDIR
cd $SRCDIR/$BZIP2


#ensures sumbolic links are relative
#sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile

make $JOBS -f Makefile-libbz2_so
make clean
make $JOBS
make PREFIX=/usr install
# XXX make sure this goes to the right dir (NOT /usr)
#cp -vf bzip2-shared /bin/bzip2
#cp -avf libbz2.so* /lib
#ln -svf ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
#rm -vf /usr/bin/{bunzip2,bzcat,bzip2}
#ln -svf bzip2 /bin/bunzip2
#ln -svf bzip2 /bin/bzcat


cd $TOPDIR
rm -rf $SRCDIR/$BZIP2



###############################################################
# M4
###############################################################
echo "extracting $M4"
decompress $M4 $SRCDIR
cd $SRCDIR/$M4

./configure --prefix=/usr
make $JOBS
#make check
make install

cd $TOPDIR
rm -rf $SRCDIR/$M4



###############################################################
# GREP
###############################################################
echo "extracting $GREP"
decompress $GREP $SRCDIR
cd $SRCDIR/$GREP

./configure --prefix=/usr
make $JOBS
#make check
make install

cd $TOPDIR
rm -rf $SRCDIR/$GREP



###############################################################
# GAWK
###############################################################
echo "extracting $GAWK"
decompress $GAWK $SRCDIR
cd $SRCDIR/$GAWK

./configure --prefix=/usr
make $JOBS
#make check
make install

#docs
#mkdir -v /usr/share/doc/gawk-4.1.1
#cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.1.1

cd $TOPDIR
rm -rf $SRCDIR/$GAWK


###############################################################
# FINDUTILS
###############################################################
echo "extracting $FINDUTILS"
decompress $FINDUTILS $SRCDIR
cd $SRCDIR/$FINDUTILS

./configure --prefix=/usr --localstatedir=/var/lib/locate
make $JOBS
#make check
make install

#startup scripts may need this in /bin
#mv -v /usr/bin/find /bin
#sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb

cd $TOPDIR
rm -rf $SRCDIR/$FINDUTILS



######################################################################
# XZ
######################################################################
echo "extracting $XZ"
decompress $XZ $SRCDIR
cd $SRCDIR/$XZ

./configure --prefix=/usr
make $JOBS
#make check
make install

#move to /bin
#mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
#mv -v /usr/lib/liblzma.so* /lib
#ln -svf /lib/liblzma.so.5 /lib/liblzma.so
#ln -svf ../../lib/liblzma.so.5 /usr/lib/liblzma.so
#ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so

cd $TOPDIR
rm -rf $SRCDIR/$XZ


###############################################################
# GZIP
###############################################################
echo "extracting $GZIP"
decompress $GZIP $SRCDIR
cd $SRCDIR/$GZIP

./configure --prefix=/usr
make $JOBS
#make check
make install

# move these out of /bin
#mv -v /bin/{gzexe,uncompress,zcmp,zdiff,zegrep} /usr/bin
#mv -v /bin/{zfgrep,zforce,zgrep,zless,zmore,znew} /usr/bin

cd $TOPDIR
rm -rf $SRCDIR/$GZIP


################################################################
# KMOD
###############################################################
#echo "extracting $KMOD"
#decompress $KMOD $SRCDIR
#cd $SRCDIR/$KMOD

##these flags are needed if you don't wish to use pkg-config
#liblzma_CFLAGS="-I/usr/include"     \
#liblzma_LIBS="-L/lib -llzma"        \
#zlib_CFLAGS="-I/usr/include"        \
#zlib_LIBS="-L/lib -lz"              \
#./configure --prefix=/usr           \
#            --sysconfdir=/etc       \
#            --with-rootlibdir=/lib  \
#            --with-xz               \
#            --with-zlib

#make $JOBS
##make check
#make install

##create symlinks
##for target in depmod insmod modinfo modprobe rmmod; do
##  ln -sv ../bin/kmod /sbin/$target
##done
##ln -sv kmod /sbin/lsmod

#cd $TOPDIR
#rm -rf $SRCDIR/$KMOD



###############################################################
# MAKE
###############################################################
echo "extracting $MAKE"
decompress $MAKE $SRCDIR
cd $SRCDIR/$MAKE

./configure --prefix=/usr
make $JOBS
#make check
make install

cd $TOPDIR
rm -rf $SRCDIR/$MAKE



###############################################################
# PATCH
###############################################################
echo "extracting $PATCH"
decompress $PATCH $SRCDIR
cd $SRCDIR/$PATCH

./configure --prefix=/usr
make $JOBS
#make check
make install

cd $TOPDIR
rm -rf $SRCDIR/$PATCH



###############################################################
# TAR
###############################################################
echo "extracting $TAR"
decompress $TAR $SRCDIR
cd $SRCDIR/$TAR

./configure --prefix=/usr

make $JOBS
#make check
make install

#make -C doc install-html


cd $TOPDIR
rm -rf $SRCDIR/$TAR



################################################################
## UTIL_LINUX
################################################################
#echo "extracting $UTIL_LINUX"
#decompress $UTIL_LINUX $SRCDIR
#cd $SRCDIR/$UTIL_LINUX


##fixes a regression test?
##sed -e 's/2^64/(2^64/' -e 's/E </E) <=/' -e 's/ne /eq /' \
##    -i tests/ts/ipcs/limits2

#./configure				\
#	--prefix=/usr			\
#	--disable-use-tty-group
#make $JOBS
##make check
##TODO see notes about the tests for this..
#
#make install
##TODO move certain programs to /sbin: mount.
#
#cd $TOPDIR
#rm -rf $SRCDIR/$UTIL_LINUX



###############################################################
# SED
###############################################################
echo "extracting $SED"
decompress $SED $SRCDIR
cd $SRCDIR/$SED

./configure         \
    --prefix=/usr

make $JOBS
#make html
#make check
make install
#make -C doc install-html
cd $TOPDIR
rm -rf $SRCDIR/$SED



###############################################################
# DIFFUTILS
###############################################################
echo "extracting $DIFFUTILS"
decompress $DIFFUTILS $SRCDIR
cd $SRCDIR/$DIFFUTILS

#First fix a file so locale files are installed:
#sed -i 's:= @mkdir_p@:= /bin/mkdir -p:' po/Makefile.in.in


./configure --prefix=/usr
make $JOBS
#make check
make install

cd $TOPDIR
rm -rf $SRCDIR/$DIFFUTILS


################################################################
## E2FSPROGS
################################################################
#echo "extracting $E2FSPROGS"
#decompress $E2FSPROGS $SRCDIR
#cd $SRCDIR/$E2FSPROGS
#mkdir -v build
#cd build
##CFLAGS="-I/usr/include -I/usr/local/include"    \
#PKG_CONFIG=/usr/bin/true		\
#../configure --prefix=/usr              \
#             --with-root-prefix=""
#             #--enable-elf-shlib
#make
#make install
#
#cd $TOPDIR
#rm -rf $SRCDIR/$E2FSPROGS


##############################################################
# TERMCAP FILE
##############################################################
#cp -rv $PKGDIR/termcap /etc/termcap


echo ---------------------------------------------
echo "newroot has been built"
echo ---------------------------------------------

