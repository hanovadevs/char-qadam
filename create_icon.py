import os
# pyrefly: ignore [missing-import]
from PIL import Image, ImageDraw, ImageFont

def create_stepsy_icon():
    os.makedirs('mobile/assets/icon', exist_ok=True)
    size = 1024
    img = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    # 1. Outer Swiss Frame
    margin = 48
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=48,
        fill=(245, 241, 232, 255),  # Swiss Warm Beige #F5F1E8
        outline=(212, 212, 212, 255),  # Hairline Border #D4D4D4
        width=6
    )

    # 2. Main High-Contrast Black Geometric Card
    box_w = 640
    box_h = 640
    box_left = (size - box_w) // 2
    box_top = (size - box_h) // 2 - 40
    draw.rounded_rectangle(
        [box_left, box_top, box_left + box_w, box_top + box_h],
        radius=32,
        fill=(0, 0, 0, 255),  # Deep Black #000000
    )

    # 3. Dynamic Walking Silhouette (White Vector Geometry)
    center_x = size // 2 - 10
    head_cy = box_top + 140
    head_r = 44

    # Head
    draw.ellipse(
        [center_x - head_r, head_cy - head_r, center_x + head_r, head_cy + head_r],
        fill=(255, 255, 255, 255)
    )

    # Torso (Forward stride slant)
    torso_top = (center_x - 5, head_cy + 55)
    torso_bottom = (center_x - 35, head_cy + 230)
    draw.line([torso_top, torso_bottom], fill=(255, 255, 255, 255), width=42)

    # Forward Leg (Stride)
    knee_f = (center_x + 85, torso_bottom[1] + 65)
    foot_f = (center_x + 130, torso_bottom[1] + 175)
    draw.line([torso_bottom, knee_f], fill=(255, 255, 255, 255), width=36)
    draw.line([knee_f, foot_f], fill=(255, 255, 255, 255), width=36)

    # Back Leg
    knee_b = (center_x - 105, torso_bottom[1] + 45)
    foot_b = (center_x - 155, torso_bottom[1] + 160)
    draw.line([torso_bottom, knee_b], fill=(255, 255, 255, 255), width=36)
    draw.line([knee_b, foot_b], fill=(255, 255, 255, 255), width=36)

    # Arms
    arm_shoulder = (center_x - 10, head_cy + 85)
    arm_f = (center_x + 95, head_cy + 165)
    arm_b = (center_x - 105, head_cy + 150)
    draw.line([arm_shoulder, arm_f], fill=(255, 255, 255, 255), width=32)
    draw.line([arm_shoulder, arm_b], fill=(255, 255, 255, 255), width=32)

    # 4. "Save" Tag Accent Badge (Taupe/Gold accent in top-right of black box)
    badge_x = box_left + box_w - 90
    badge_y = box_top + 90
    badge_r = 52
    draw.ellipse(
        [badge_x - badge_r, badge_y - badge_r, badge_x + badge_r, badge_y + badge_r],
        fill=(179, 139, 109, 255)  # Swiss Taupe #B38B6D
    )
    # White Percent / Save Symbol in Badge
    draw.line([(badge_x - 22, badge_y + 22), (badge_x + 22, badge_y - 22)], fill=(255, 255, 255, 255), width=8)
    draw.ellipse([badge_x - 24, badge_y - 26, badge_x - 10, badge_y - 12], fill=(255, 255, 255, 255))
    draw.ellipse([badge_x + 10, badge_y + 12, badge_x + 24, badge_y + 26], fill=(255, 255, 255, 255))

    # 5. Swiss Architectural Bottom Bar: "STEPSY"
    bar_y = box_top + box_h + 50
    bar_w = 480
    bar_h = 56
    bar_x = (size - bar_w) // 2
    draw.rounded_rectangle(
        [bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
        radius=12,
        fill=(0, 0, 0, 255)
    )

    # Accent decorative dots on bottom bar
    draw.ellipse([bar_x + 30, bar_y + 22, bar_x + 42, bar_y + 34], fill=(179, 139, 109, 255))
    draw.ellipse([bar_x + bar_w - 42, bar_y + 22, bar_x + bar_w - 30, bar_y + 34], fill=(179, 139, 109, 255))

    output_path = 'mobile/assets/icon/app_icon.png'
    img.save(output_path, 'PNG')
    print(f"Stepsy app icon created successfully at {output_path} ({size}x{size})")

if __name__ == '__main__':
    create_stepsy_icon()
