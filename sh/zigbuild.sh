#!/usr/bin/env bash

DIR=$(realpath $0) && DIR=${DIR%/*/*}
cd $DIR

set -ex

meta=$(cargo metadata --format-version=1 --no-deps)
installed=$(rustup target list --installed)
ver=$(echo $meta | jq -r '.packages[0].version')

unameOut="$(uname -s)"

target_list=$(rustup target list | awk '{print $1}')

case "${unameOut}" in
Linux*) TARGET_LI=$(echo $target_list | grep "linux-" | grep -E "i686|x86|arch64" | grep -E "[musl|gun]$") ;;
Darwin*) TARGET_LI=$(echo "$target_list" | grep "apple-" | grep -v "\-ios") ;;
Windows*) TARGET_LI=$(echo "$target_list" | grep windows | grep msvc | grep -v "i586-" | awk '{print $1}') ;;
esac

if ! command -v cargo-zigbuild &>/dev/null; then
  cargo install cargo-zigbuild
fi

TARGET=$DIR/target
BIN=$TARGET/bin
rm -rf $BIN

build_mv() {
  cargo zigbuild -Z unstable-options --target $1 --release
  name=$ver.$1
  out=$BIN/$name
  mkdir -p $out
  find $TARGET/$1/release -maxdepth 1 -type f -perm +u=x | while read file; do
    mv "$file" $out/
    strip $out/$(basename $file)
  done
  cd $DIR
}

for target in ${TARGET_LI[@]}; do
  echo $installed | grep -q $target || rustup target add $target
  rustup update nightly
  build_mv $target
done

if [ "$unameOut" == "Darwin" ]; then
  build_mv universal2-apple-darwin
fi