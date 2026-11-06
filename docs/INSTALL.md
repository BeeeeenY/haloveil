# Install HaloVeil

[English](INSTALL.md) · [简体中文](INSTALL.zh-CN.md)

## Download

Download **[HaloVeil-1.0.0.zip](https://raw.githubusercontent.com/BeeeeenY/haloveil/main/downloads/HaloVeil-1.0.0.zip)** from this repository. If the project also has a GitHub Release, its asset with the same name is the installable package. GitHub's automatically generated “Source code” ZIP contains the source project instead.

Unzip the package with Archive Utility. Keep the `.saver` bundle intact; do not open its Contents folder to install individual files. Installing the downloaded saver does not require Xcode, Python, a web server, or Wallpaper Engine.

## Install and select

1. Double-click **HaloVeil.saver**.
2. When macOS offers a choice, select **Install for this user**. Installing for every user may require administrator credentials.
3. Open **Apple menu → System Settings → Screen Saver**.
4. Scroll to **Other** and click **HaloVeil** to switch to it.
5. On macOS versions where Screen Saver is inside Wallpaper, use **System Settings → Wallpaper → Screen Saver → Custom → Other → HaloVeil** instead.
6. Start the full-screen **Preview**, or configure a screen saver Hot Corner in **Desktop & Dock → Hot Corners**.

**Do not stop at installing the file: choose HaloVeil in the Other category.** If you used HALOFLUX previously, HaloVeil is a separate entry; select the new entry explicitly.

Expect a short dark preparation interval before the animation fades in. Move the pointer or press a key to exit, and enter your password normally when required. Lock-screen password timing remains controlled by macOS.

## If HaloVeil does not appear

- Quit and reopen System Settings, then scroll to **Other** again.
- Confirm that you unzipped the installation package, rather than opening the source archive.
- The usual per-user location is `~/Library/Screen Savers/HaloVeil.saver`. In Finder, use **Go → Go to Folder** to open `~/Library/Screen Savers/`. If necessary, copy the complete `.saver` bundle there, then reopen System Settings.

The build targets macOS 12+, and the adaptation was tested on Sonoma 14.4.1. The exact settings layout varies by macOS release. Apple documents both the [Screen Saver settings](https://support.apple.com/en-mn/guide/mac-help/-mchlp1227/mac) and the [Wallpaper → Screen Saver route](https://support.apple.com/en-my/guide/mac-help/-mchl4b68853d/mac).

## Security prompts

The provided build is ad-hoc signed and is **not notarized by Apple**. macOS may ask for confirmation or block the downloaded bundle. Read the actual macOS notice and verify the download's source. The project does not require disabling system security protections.

## Update

Exit the running saver, close System Settings, and install the newer complete `.saver` bundle. Accept the replacement prompt if macOS offers it, reopen System Settings, and select **Other → HaloVeil** again. Do not mix web files or executable files from different versions inside an installed bundle; the build verifies resource consistency.

The web resources travel with the saver, so moving the source project does not affect the installed copy.

## Remove

Choose another screen saver and quit System Settings. In Finder, remove `~/Library/Screen Savers/HaloVeil.saver`. An all-users installation may instead be in `/Library/Screen Savers/`; removing that copy may require administrator credentials.

## Preview without installing

Open **HaloVeil Preview.app** from the download. It runs the same bundled saver in a regular window. Close the window or choose Quit to stop it. A windowed preview does not prove full-screen or lock-screen performance.

## License

Modified from **HALOFLUX by Ryder191 (RYDER CODE / Ms MAIKEBAIs CAT)** — <https://github.com/Ryder191/haloflux>.

Noncommercial use only. Read [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
