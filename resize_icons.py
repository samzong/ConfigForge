#!/usr/bin/env python3
import os

from PIL import Image

# 源图片路径
source_image_path = 'ConfigForge/Assets.xcassets/Logo.imageset/logo.png'
# 输出目录
output_dir = 'ConfigForge/Assets.xcassets/AppIcon.appiconset'

# 确保输出目录存在
os.makedirs(output_dir, exist_ok=True)

# 定义 macOS 应用图标所需的尺寸
icon_sizes = [
    (16, 16, '16x16', '1x'),
    (32, 32, '16x16', '2x'),
    (32, 32, '32x32', '1x'),
    (64, 64, '32x32', '2x'),
    (128, 128, '128x128', '1x'),
    (256, 256, '128x128', '2x'),
    (256, 256, '256x256', '1x'),
    (512, 512, '256x256', '2x'),
    (512, 512, '512x512', '1x'),
    (1024, 1024, '512x512', '2x')
]

# 打开源图片
source_image = Image.open(source_image_path)

# 生成不同尺寸的图标
for width, height, size_name, scale in icon_sizes:
    # 调整图片大小
    resized_image = source_image.resize((width, height), Image.LANCZOS)
    
    # 保存调整后的图片
    output_filename = f'icon_{size_name}_{scale}.png'
    output_path = os.path.join(output_dir, output_filename)
    resized_image.save(output_path)
    print(f'已生成: {output_path} ({width}x{height})')

# 更新 Contents.json 文件
contents_json = {
    "images": [],
    "info": {
        "author": "xcode",
        "version": 1
    }
}

for width, height, size_name, scale in icon_sizes:
    image_entry = {
        "filename": f"icon_{size_name}_{scale}.png",
        "idiom": "mac",
        "scale": scale,
        "size": size_name
    }
    contents_json["images"].append(image_entry)

# 将更新后的 Contents.json 写入文件
import json

with open(os.path.join(output_dir, 'Contents.json'), 'w') as f:
    json.dump(contents_json, f, indent=2)

print('Contents.json 已更新。')
print('所有图标已生成完成。') 