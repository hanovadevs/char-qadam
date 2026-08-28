import os
from PIL import Image, ImageDraw, ImageFont

def create_qadam_icon():
    os.makedirs('mobile/assets/icon', exist_ok=True)
    size = 1024
    img = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    # 1. Outer Swiss Frame
    margin = 80
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=40,
        fill=(245, 241, 232, 255), # Swiss Beige #F5F1E8
        outline=(212, 212, 212, 255), # Border #D4D4D4
        width=6
    )

    # 2. Geometric Core Block
    box_size = 560
    box_left = (size - box_size) // 2
    box_top = (size - box_size) // 2 - 40
    draw.rounded_rectangle(
        [box_left, box_top, box_left + box_size, box_top + box_size],
        radius=24,
        fill=(0, 0, 0, 255), # Deep Black #000000
    )

    # 3. Geometric Walking Figure Silhouette (White on Black)
    # Head
    head_cx = size // 2 + 10
    head_cy = box_top + 130
    head_r = 45
    draw.ellipse(
        [head_cx - head_r, head_cy - head_r, head_cx + head_r, head_cy + head_r],
        fill=(255, 255, 255, 255)
    )

    # Torso (Forward dynamic stride)
    torso_top = (head_cx - 5, head_cy + 55)
    torso_bottom = (head_cx - 30, head_cy + 220)
    draw.line([torso_top, torso_bottom], fill=(255, 255, 255, 255), width=44)

    # Forward Leg
    knee_f = (head_cx + 80, torso_bottom[1] + 60)
    foot_f = (head_cx + 120, torso_bottom[1] + 160)
    draw.line([torso_bottom, knee_f], fill=(255, 255, 255, 255), width=36)
    draw.line([knee_f, foot_f], fill=(255, 255, 255, 255), width=36)

    # Back Leg
    knee_b = (head_cx - 100, torso_bottom[1] + 40)
    foot_b = (head_cx - 140, torso_bottom[1] + 150)
    draw.line([torso_bottom, knee_b], fill=(255, 255, 255, 255), width=36)
    draw.line([knee_b, foot_b], fill=(255, 255, 255, 255), width=36)

    # Arms
    arm_shoulder = (head_cx - 10, head_cy + 85)
    arm_f = (head_cx + 90, head_cy + 160)
    arm_b = (head_cx - 95, head_cy + 145)
    draw.line([arm_shoulder, arm_f], fill=(255, 255, 255, 255), width=32)
    draw.line([arm_shoulder, arm_b], fill=(255, 255, 255, 255), width=32)

    # 4. Typography "QADAM"
    # Draw geometric text label at the bottom
    text_y = box_top + box_size + 70
    draw.rectangle(
        [(size // 2) - 180, text_y, (size // 2) + 180, text_y + 40],
        fill=(0, 0, 0, 255)
    )

    output_path = 'mobile/assets/icon/app_icon.png'
    img.save(output_path, 'PNG')
    print(f"App icon created successfully at {output_path} ({size}x{size})")

if __name__ == '__main__':
    create_qadam_icon()
