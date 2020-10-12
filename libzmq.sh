#!/bin/sh
# A script to download and build libzmq for iOS, including arm64
# Adapted from https://raw2.github.com/seb-m/CryptoPill/master/libsodium.sh

set -e

LIBNAME="libzmq.a"
ROOTDIR=`pwd`

#libsodium
LIBSODIUM_DIST="${ROOTDIR}/libsodium-ios/libsodium_dist/"
echo "Building dependency 'libsodium-ios'..."
cd libsodium-ios
bash libsodium.sh
cd $ROOTDIR

ARCHS=${ARCHS:-"armv7 armv7s arm64 x86_64"}
DEVELOPER=$(xcode-select -print-path)
LIPO=$(xcrun -sdk iphoneos -find lipo)
#LIPO=lipo
# Script's directory
SCRIPTDIR=$( (cd -P $(dirname $0) && pwd) )
# libsodium root directory
LIBDIR="libzeromq"
mkdir -p $LIBDIR
LIBDIR=$( (cd "${LIBDIR}"  && pwd) )
# Destination directory for build and install
DSTDIR=${SCRIPTDIR}
BUILDDIR="${DSTDIR}/libzmq_build"
DISTDIR="${DSTDIR}/libzmq_dist"
DISTLIBDIR="${DISTDIR}/lib"
TARVER=4.3.3
TARNAME="zeromq-$TARVER"
TARFILE=${TARNAME}.tar.gz
TARURL=https://github.com/zeromq/libzmq/releases/download/v$TARVER/$TARFILE

# http://libwebp.webm.googlecode.com/git/iosbuild.sh
# Extract the latest SDK version from the final field of the form: iphoneosX.Y
SDK=$(xcodebuild -showsdks \
    | grep iphoneos | sort | tail -n 1 | awk '{print substr($NF, 9)}'
    )

IOS_VERSION_MIN=12.0
OTHER_LDFLAGS=""
OTHER_CFLAGS="-Os -Qunused-arguments"
# Enable Bitcode
OTHER_CPPFLAGS="-Os -I${LIBSODIUM_DIST}/include -fembed-bitcode"
OTHER_CXXFLAGS="-Os"

# Download and extract ZeroMQ
rm -rf $LIBDIR
set -e
curl -O -L $TARURL
tar xzf $TARFILE
rm $TARFILE
mv $TARNAME $LIBDIR



# Cleanup
if [ -d $BUILDDIR ]
then
    rm -rf $BUILDDIR
fi
if [ -d $DISTDIR ]
then
    rm -rf $DISTDIR
fi
mkdir -p $BUILDDIR $DISTDIR

# Generate autoconf files
cd ${LIBDIR}
#cd ${LIBDIR}; ./autogen.sh

# Iterate over archs and compile static libs
for ARCH in $ARCHS
do
    BUILDARCHDIR="$BUILDDIR/$ARCH"
    mkdir -p ${BUILDARCHDIR}

    case ${ARCH} in
		armv7)
	    PLATFORM="iPhoneOS"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS}"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT}"
            ;;
        armv7s)
	    PLATFORM="iPhoneOS"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} ${OTHER_CFLAGS}"
	    export LDFLAGS="-mthumb -arch ${ARCH} -isysroot ${ISDKROOT}"
            ;;
        arm64)
	    PLATFORM="iPhoneSimulator"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=${SDK} ${OTHER_CFLAGS}"
	    export LDFLAGS="-m32 -arch ${ARCH}"
            ;;
        x86_64)
	    PLATFORM="iPhoneSimulator"
	    HOST="${ARCH}-apple-darwin"
	    export BASEDIR="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	    export ISDKROOT="${BASEDIR}/SDKs/${PLATFORM}${SDK}.sdk"
	    export CFLAGS="-arch ${ARCH} -isysroot ${ISDKROOT} -miphoneos-version-min=${SDK} ${OTHER_CFLAGS}"
	    export LDFLAGS="-arch ${ARCH}"
            ;;
        *)
		echo "LDFLAGS $LDFLAGS"
	    echo "Unsupported architecture ${ARCH}"
	    exit 1
            ;;
    esac

    export PATH="${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin:${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/sbin:$PATH"

    echo "Configuring for ${ARCH}..."
    set +e
    cd ${LIBDIR} && make distclean
    set -e
    ${LIBDIR}/configure \
	--prefix=${BUILDARCHDIR} \
	--disable-shared \
	--enable-static \
	--host=${HOST}\
	--with-libsodium=${LIBSODIUM_DIST}

    echo "Building ${LIBNAME} for ${ARCH}..."
    cd ${LIBDIR}
    
    make -j8 V=0
    make install

    LIBLIST+="${BUILDARCHDIR}/lib/${LIBNAME} "
done

# Copy headers and generate a single fat library file
mkdir -p ${DISTLIBDIR}
${LIPO} -create ${LIBLIST} -output ${DISTLIBDIR}/${LIBNAME}
for ARCH in $ARCHS
do
    cp -R $BUILDDIR/$ARCH/include ${DISTDIR}
    break
done

# Cleanup
rm -rf ${BUILDDIR}
