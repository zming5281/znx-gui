#! /bin/sh

# -- Install dependencies.

apt-get -qq -y update > /dev/null
apt-get -qq -y install wget patchelf file libcairo2 git --no-install-recommends > /dev/null
apt-get -qq -y install busybox-static kde-baseapps-bin --no-install-recommends > /dev/null

wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
wget -q https://raw.githubusercontent.com/luis-lavaire/bin/master/copier

chmod +x appimagetool
chmod +x copier
chmod +x appdir/znx-gui


# -- Write the commit that generated this build.

sed -i "s/@TRAVIS_COMMIT@/${1:0:7}/" appdir/znx-gui


# -- Populate appdir.

mkdir -p appdir/bin

printf \
'[Desktop Entry]
Type=Application
Name=znx-gui
Exec=znx-gui
Icon=znx-gui
Comment="Graphical frontend for znx."
Terminal=false
Categories=Utility;
' > appdir/znx-gui.desktop


# -- Create a wrapper script.

printf \
'#! /bin/sh

export LD_LIBRARY_PATH=$APPDIR/usr/lib:$LD_LIBRARY_PATH
export PATH=$PATH:$APPDIR/bin:$APPDIR/sbin:$APPDIR/usr/bin:$APPDIR/usr/sbin
exec $APPDIR/znx-gui
' > appdir/AppRun

chmod a+x appdir/AppRun


# -- Install busybox.

./copier busybox appdir
/bin/busybox --install -s appdir/bin


# -- Copy binaries and its dependencies to appdir.

./copier kdialog appdir


# -- Include znx.

ZNX_TMP_DIR=$(mktemp -d)
git clone https://github.com/Nitrux/znx $ZNX_TMP_DIR

(
	cd $ZNX_TMP_DIR

	bash build.sh

	rm \
		appdir/znx.desktop \
		appdir/znx.png \
		appdir/AppRun

)

cp -r $ZNX_TMP_DIR/appdir .


# -- Generate the AppImage.

(
	cd appdir

	wget -q https://raw.githubusercontent.com/AppImage/AppImages/master/functions.sh
	chmod +x functions.sh
	. ./functions.sh
	delete_blacklisted
	rm functions.sh

	wget -qO runtime https://github.com/AppImage/AppImageKit/releases/download/continuous/runtime-x86_64
	chmod a+x runtime

	find lib/x86_64-linux-gnu -type f -exec patchelf --set-rpath '$ORIGIN/././' {} \;
	find bin -type f -exec patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu' {} \;
	find sbin -type f -exec patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu' {} \;
	find usr/bin -type f -exec patchelf --set-rpath '$ORIGIN/../../lib/x86_64-linux-gnu' {} \;
	find usr/sbin -type f -exec patchelf --set-rpath '$ORIGIN/../../lib/x86_64-linux-gnu' {} \;
)

wget -q https://raw.githubusercontent.com/Nitrux/appimage-wrapper/master/appimage-wrapper
chmod a+x appimage-wrapper

mkdir out
ARCH=x84_64 ./appimage-wrapper appimagetool appdir out/znx-gui
