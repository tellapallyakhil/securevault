import os
from pathlib import Path
from PIL import Image

src_img_path = r"C:\Users\tella\.gemini\antigravity-ide\brain\c68fdf98-8460-44b4-a265-f98dc95c5064\securevault_app_icon_1789916271727.jpg"
res_dir = Path(r"c:\Users\tella\securevault\mobile\android\app\src\main\res")

# Target icon sizes for Android mipmap
sizes = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

# Also save high-res assets copy
assets_icon_dir = Path(r"c:\Users\tella\securevault\mobile\assets\icon")
assets_icon_dir.mkdir(parents=True, exist_ok=True)

img = Image.open(src_img_path)
img.save(assets_icon_dir / "app_icon.png")
print("Saved high-res icon to mobile/assets/icon/app_icon.png")

for folder, size in sizes.items():
    target_folder = res_dir / folder
    target_folder.mkdir(parents=True, exist_ok=True)
    target_path = target_folder / "ic_launcher.png"
    
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(target_path, "PNG")
    print(f"Generated {size[0]}x{size[1]} icon in {target_path}")

print("\nALL ANDROID APP LAUNCHER ICONS SUCCESSFULLY UPDATED!")
