VERSION=3
MIN_VERSION=10
REVISION=3

if [ ! -f gtksourceview-$VERSION.$MIN_VERSION.$REVISION.tar.xz ]; then
   wget https://download.gnome.org/sources/gtksourceview/$VERSION.$MIN_VERSION/gtksourceview-$VERSION.$MIN_VERSION.$REVISION.tar.xz
fi
if [ ! -d gtksourceview-$VERSION.$MIN_VERSION.$REVISION ]; then
   tar -Jxvf gtksourceview-$VERSION.$MIN_VERSION.$REVISION.tar.xz
fi
cd gtksourceview-$VERSION.$MIN_VERSION.$REVISION
./configure --prefix=$(pwd)/../build
make -j3
make install

