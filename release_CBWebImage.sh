XCODEBUILD=xcodebuild

# Echoes a progress message to stderr
function progress_message() {
    echo "$@" >&2
}

# Any script that includes common.sh must call this once if it finishes
# successfully.
function common_success() { 
#    pop_common
    return 0
}

# Call this when there is an error.  This does not return.
function die() {
  echo ""
  echo "FATAL: $*" >&2
  show_summary
  exit 1
}

if [ "$#" -lt 5 ]; then
    echo "Usage: $0 BUILD_NUMBER PRODUCT_NAME PROFILE_UUID CODE_SIGN_IDENTITY"
    echo "  BUILD_NUMBER         build number to place in bundle"
	echo "  TARGET_NAME          build target"
    echo "  PRODUCT_NAME         name of the final .ipa package (e.g., Scrumptious.ipa)"
    echo "  PROFILE_UUID         UUID of the provisioning profile"
    echo "  CODE_SIGN_IDENTITY   name of the code sign identity"
    die 'Invalid arguments'
fi

BUILD_NUMBER="$1"
TARGET_NAME="$2"
FINAL_PRODUCT_NAME="$3"
PROFILE_UUID="$4"
CODE_SIGN_IDENTITY="$5"


# -----------------------------------------------------------------------------
# Build Scrumptious
#

#-------------------------------------------------
PRODUCT_NAME="CBWebImage"
PROJECT_NAME="CBWebImage"
CONFIGURATION="Debug"
SDK="iphoneos"
APP_NAME="$PRODUCT_NAME.app"

# BUILD_NUMBER="1.0"
# FINAL_PRODUCT_NAME="${PRODUCT_NAME}.ipa"
# only UUID not file path
# PROFILE_UUID="FE08FF5A-1572-42BC-869B-69A5EC3899C9"
# CODE_SIGN_IDENTITY="iPhone Distribution: Cardinal Blue Software, Inc"
# PROFILE_UUID="DE3302C7-1455-4977-BD7F-0827484D2D89"
# CODE_SIGN_IDENTITY="iPhone Developer: David Liu"
#-------------------------------------------------

OUTPUT_DIR=`mktemp -d -t "${PRODUCT_NAME}-inhouse"`
RESULTS_DIR="$OUTPUT_DIR"/"$CONFIGURATION"-"$SDK"

REPO_PATH="/Users/davidliu/Repositories"
cd "$REPO_PATH/${PRODUCT_NAME}"

$XCODEBUILD \
  -target ${PRODUCT_NAME} \
  -sdk "$SDK" \
  -configuration "$CONFIGURATION" \
  -arch "armv7 armv6" \
  SYMROOT="$OUTPUT_DIR" \
  OBJROOT="$OUTPUT_DIR" \
  CURRENT_PROJECT_VERSION="$FB_SDK_VERSION_FULL" \
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  PROVISIONING_PROFILE="$PROFILE_UUID" \
  FB_BUNDLE_VERSION="$BUILD_NUMBER" \
  clean build \ 


#  || die "XCode build failed for Pic Collage (Distribution)."

# -----------------------------------------------------------------------------
# Build .ipa package
#
progress_message Building Package

#PACKAGE_DIR=`mktemp -d -t ${PRODUCT_NAME}-inhouse-pkg`
PACKAGE_DIR="/Users/davidliu/Desktop/${PRODUCT_NAME}-inhouse-pkg"
`mkdir "$PACKAGE_DIR"`
echo $PACKAGE_DIR

pushd "$PACKAGE_DIR" >/dev/null
PAYLOAD_DIR="Payload"
`mkdir "$PAYLOAD_DIR"`
`cp -a "$RESULTS_DIR"/"$APP_NAME" "$PAYLOAD_DIR"`
`rm -f "$FINAL_PRODUCT_NAME"`

zip -y -r "$FINAL_PRODUCT_NAME" "$PAYLOAD_DIR"
progress_message ...Package at: "$PACKAGE_DIR"/"$FINAL_PRODUCT_NAME"


#------------------------------------------------------------------------------
# iUploader - upload IPA file to iUploader server with parameters
# app_name -
# identifier -
# version -
progress_message Uploading IPA file to iUploader

IUPLOADER_SERVER="http://web1.tunnlr.com:11193"
IDENTIFIER="com.cardinalblue.CBWebImage"

curl -X POST -F "ipa=@${FINAL_PRODUCT_NAME}" "${IUPLOADER_SERVER}/apps?app_name=${PRODUCT_NAME}&identifier=${IDENTIFIER}&version=${BUILD_NUMBER}"


# -----------------------------------------------------------------------------
# Validate .ipa package
#
#progress_message Validating Package

# Apple's Validation tool exits with error code 0 even on error, so we have to search the output.
VALIDATION_TOOL="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/Validation"
VALIDATION_RESULT=`"$VALIDATION_TOOL" -verbose -errors "$FINAL_PRODUCT_NAME"`
if [[ "$VALIDATION_RESULT" == *error:* ]]; then
    echo "Validation failed: $VALIDATION_RESULT"
    exit 1
fi

popd >/dev/null

# -----------------------------------------------------------------------------
# Archive the build and .dSYM symbols
progress_message Archiving build and symbols

BUILD_ARCHIVE_DIR=~/iossdkarchive/"$PRODUCT_NAME"/"$BUILD_NUMBER"
mkdir -p "$BUILD_ARCHIVE_DIR"

pushd "$RESULTS_DIR" >/dev/null

ARCHIVE_PATH="$BUILD_ARCHIVE_DIR"/Archive-"$BUILD_NUMBER".zip
zip -y -r "$ARCHIVE_PATH" "$APP_NAME" "$APP_NAME".dSYM
progress_message ...Archive at: "$ARCHIVE_PATH"

popd >/dev/null

# -----------------------------------------------------------------------------
# Done
#
common_success
