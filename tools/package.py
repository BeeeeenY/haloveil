#!/usr/bin/env python3
"""Package the signed HaloVeil products for end users; no network access."""
from __future__ import annotations

import hashlib
import json
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    release = json.loads((ROOT / "version.json").read_text())
    version, build = release["version"], str(release["build"])
    saver = ROOT / "build/HaloVeil.saver"
    preview = ROOT / "build/HaloVeil Preview.app"
    if not saver.is_dir() or not preview.is_dir():
        raise SystemExit("Run ./build.command before packaging.")

    for bundle in (saver, preview, preview / "Contents/PlugIns/HaloVeil.saver"):
        subprocess.run(
            ["codesign", "--verify", "--deep", "--strict", str(bundle)],
            check=True,
        )
        info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
        if (info["CFBundleShortVersionString"], info["CFBundleVersion"]) != (version, build):
            raise SystemExit(f"Version mismatch: {bundle.name}")
        executable = bundle / "Contents/MacOS" / info["CFBundleExecutable"]
        if not executable.is_file():
            raise SystemExit(f"Missing executable: {executable}")
        architectures = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split()
        if set(architectures) != {"arm64", "x86_64"}:
            raise SystemExit(f"Expected universal binary: {executable}")

    resources = saver / "Contents/Resources"
    for notice in ("LICENSE", "NOTICE"):
        if (resources / notice).read_bytes() != (ROOT / notice).read_bytes():
            raise SystemExit(f"Rebuild to include the current {notice}.")
    manifest = json.loads((resources / "manifest.json").read_text())
    for name, expected in manifest.items():
        if not name.startswith("web/") or ".." in Path(name).parts:
            raise SystemExit("Invalid manifest path.")
        if digest(resources / name) != expected or digest(ROOT / name) != expected:
            raise SystemExit(f"Rebuild: changed web resource {name}")

    readme = f"""# HaloVeil {version} · 光幕

Silent offline macOS screen saver / 无声离线 macOS 屏幕保护程序

## Install / 安装

1. Double-click `HaloVeil.saver` and choose **Install for this user**.
   双击 `HaloVeil.saver`，选择 **仅为此用户安装**。
2. Open **System Settings → Screen Saver → Other → HaloVeil**.
   打开 **系统设置 → 屏幕保护程序 → 其他 / Other → HaloVeil** 切换。
3. On versions with grouped settings, use **System Settings → Wallpaper → Screen Saver → Custom → Other → HaloVeil**.
   如果该版本将屏保放在墙纸中，进入 **系统设置 → 墙纸 → 屏幕保护程序 → 自定 / Custom → 其他 / Other → HaloVeil**。
4. Use **Preview** or a screen saver Hot Corner to start it. Reopen System Settings if HaloVeil has not appeared.
   点击 **预览** 或使用屏保触发角启动；暂时看不到时，退出并重新打开系统设置。

Installing alone may not switch the active saver. Select **HaloVeil under Other**.
安装文件不等于已切换屏保，安装后请务必在 **Other** 中选中 HaloVeil。

Startup prepares resources before a short fade-in. Telemetry is simulated. The screen saver does not replace the password-entry interface or desktop wallpaper.
启动先预热资源再淡入；数据为演示，尚未连接真实 agent，不替换密码输入界面或桌面壁纸。

The build targets macOS 12+ and is ad-hoc signed, not Apple-notarized.
编译目标为 macOS 12 及以上，使用本地签名，未经 Apple 公证。

`HaloVeil Preview.app` runs the same saver in a window without installing it.
直接打开预览 App 可在窗口中查看，无需安装。

## License / 许可

Modified from **HALOFLUX by Ryder191 (RYDER CODE / Ms MAIKEBAIs CAT)**.
Source / 原作来源：https://github.com/Ryder191/haloflux

**Noncommercial use only. Not MIT. / 仅限非商业使用，不是 MIT 许可。**
Read the included LICENSE and NOTICE. / 请阅读随附的完整许可与署名说明。
"""

    downloads = ROOT / "downloads"
    downloads.mkdir(exist_ok=True)
    archive = downloads / f"HaloVeil-{version}.zip"
    prefix = f"HaloVeil-{version}/"
    with tempfile.TemporaryDirectory(prefix="package-", dir=ROOT / "build") as temporary:
        output = Path(temporary) / archive.name
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
            for bundle in (saver, preview):
                for path in sorted(bundle.rglob("*")):
                    if path.name == ".DS_Store" or path.name.startswith("._"):
                        continue
                    if path.is_symlink():
                        raise SystemExit(f"Unexpected symlink: {path}")
                    zipped.write(path, prefix + bundle.name + "/" + str(path.relative_to(bundle)))
            for name in ("LICENSE", "NOTICE"):
                zipped.write(ROOT / name, prefix + name)
            zipped.writestr(prefix + "README.md", readme)

        with zipfile.ZipFile(output) as zipped:
            if zipped.testzip() is not None:
                raise SystemExit("ZIP CRC check failed.")
            for bundle in (saver, preview):
                for path in bundle.rglob("*"):
                    if not path.is_file() or path.name == ".DS_Store" or path.name.startswith("._"):
                        continue
                    name = prefix + bundle.name + "/" + str(path.relative_to(bundle))
                    if hashlib.sha256(zipped.read(name)).hexdigest() != digest(path):
                        raise SystemExit(f"Archive differs from signed product: {name}")
            executable_info = zipped.getinfo(prefix + "HaloVeil.saver/Contents/MacOS/HaloVeil")
            if not (executable_info.external_attr >> 16) & 0o111:
                raise SystemExit("Executable permissions were not preserved.")
        output.replace(archive)

    (downloads / "SHA256SUMS").write_text(f"{digest(archive)}  {archive.name}\n")
    print(f"Packaged {archive.name}: {archive.stat().st_size:,} bytes")
    print(f"SHA256 {digest(archive)}")


if __name__ == "__main__":
    main()
