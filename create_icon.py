#!/usr/bin/env python3
"""Generate FieldPay app icon"""

from PIL import Image, ImageDraw, ImageFont
import math

def create_fieldpay_icon(size=1024):
    """Create a professional FieldPay app icon"""

    # Create image with gradient background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Create gradient background (teal to blue-green)
    for y in range(size):
        # Gradient from top-left to bottom-right
        ratio = y / size
        r = int(16 + (20 - 16) * ratio)
        g = int(185 + (140 - 185) * ratio)
        b = int(129 + (180 - 129) * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Draw rounded rectangle background (iOS style)
    corner_radius = int(size * 0.22)

    # Create mask for rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [(0, 0), (size-1, size-1)],
        radius=corner_radius,
        fill=255
    )

    # Apply gradient with rounded corners
    gradient = img.copy()
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    img.paste(gradient, mask=mask)
    draw = ImageDraw.Draw(img)

    # Calculate positions
    center_x = size // 2
    center_y = size // 2

    # Draw a stylized "F" with a payment card/checkmark concept
    # Main shape dimensions
    padding = size * 0.15

    # Draw a white rounded card shape
    card_left = padding
    card_top = padding * 1.3
    card_right = size - padding
    card_bottom = size - padding * 1.3
    card_radius = size * 0.08

    # Card shadow (subtle)
    shadow_offset = size * 0.015
    shadow_color = (0, 80, 60, 60)
    draw.rounded_rectangle(
        [(card_left + shadow_offset, card_top + shadow_offset),
         (card_right + shadow_offset, card_bottom + shadow_offset)],
        radius=int(card_radius),
        fill=shadow_color
    )

    # White card
    draw.rounded_rectangle(
        [(card_left, card_top), (card_right, card_bottom)],
        radius=int(card_radius),
        fill=(255, 255, 255, 255)
    )

    # Draw "F" letter in teal
    f_color = (16, 165, 120, 255)  # Matching the top gradient color

    # F dimensions
    f_left = size * 0.28
    f_top = size * 0.28
    f_width = size * 0.44
    f_height = size * 0.44
    stroke_width = size * 0.10

    # Vertical bar of F
    draw.rectangle(
        [(f_left, f_top), (f_left + stroke_width, f_top + f_height)],
        fill=f_color
    )

    # Top horizontal bar of F
    draw.rectangle(
        [(f_left, f_top), (f_left + f_width, f_top + stroke_width)],
        fill=f_color
    )

    # Middle horizontal bar of F (shorter)
    mid_y = f_top + f_height * 0.42
    draw.rectangle(
        [(f_left, mid_y), (f_left + f_width * 0.75, mid_y + stroke_width * 0.85)],
        fill=f_color
    )

    # Add a small payment indicator (dollar sign or checkmark) at bottom right
    check_x = size * 0.68
    check_y = size * 0.62
    check_size = size * 0.18

    # Draw checkmark circle background
    circle_color = (16, 185, 129, 255)  # Bright teal
    draw.ellipse(
        [(check_x, check_y), (check_x + check_size, check_y + check_size)],
        fill=circle_color
    )

    # Draw checkmark inside
    check_stroke = size * 0.025
    check_padding = check_size * 0.28

    # Checkmark path points
    p1 = (check_x + check_padding, check_y + check_size * 0.52)
    p2 = (check_x + check_size * 0.42, check_y + check_size * 0.7)
    p3 = (check_x + check_size - check_padding, check_y + check_padding * 1.1)

    # Draw checkmark with thick lines
    draw.line([p1, p2], fill=(255, 255, 255, 255), width=int(check_stroke))
    draw.line([p2, p3], fill=(255, 255, 255, 255), width=int(check_stroke))

    return img

def main():
    # Create icon at 1024x1024 (Apple's required size)
    icon = create_fieldpay_icon(1024)

    # Save the main icon
    output_path = "/Users/mitchellthompson/Desktop/fieldpay/fieldpay/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    icon.save(output_path, 'PNG')
    print(f"Created: {output_path}")

    # Also save a copy at the project root for reference
    icon.save("/Users/mitchellthompson/Desktop/fieldpay/AppIcon_1024.png", 'PNG')
    print("Created: AppIcon_1024.png")

if __name__ == "__main__":
    main()
