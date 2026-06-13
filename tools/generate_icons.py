import sys
import os
from PIL import Image, ImageOps

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip('#')
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

def is_light_color(rgb):
    # Calculate luminance
    r, g, b = rgb
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    return luminance > 0.5

def generate_icons(bg_color_hex):
    logo_path = 'assets/icons/mobiz_logo.png'
    foreground_path = 'assets/icons/mobiz_logo_foreground.png'
    launcher_path = 'assets/icons/mobiz_logo_launcher.png'
    
    if not os.path.exists(logo_path):
        print(f"Error: {logo_path} not found.")
        sys.exit(1)
        
    print(f"Reading logo from {logo_path}...")
    logo = Image.open(logo_path).convert("RGBA")
    
    # Calculate target dimensions to fit in 66% circular safe zone of a 1024x1024 canvas
    # Safe zone diameter is 1024 * 0.66 = 676 pixels.
    # The logo aspect ratio is 548 / 300 = 1.8267.
    # We want diagonal of logo to be <= 672 pixels.
    # D = 672, r = 1.8267
    # h = D / sqrt(r^2 + 1) = 672 / 2.083 = 322.6 => 323
    # w = r * h = 1.8267 * 323 = 590
    target_w = 590
    target_h = 323
    
    # Resize the logo using Lanczos interpolation
    logo_resized = logo.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # 1. Generate transparent foreground image
    print("Generating transparent foreground image...")
    fg_canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    paste_x = (1024 - target_w) // 2
    paste_y = (1024 - target_h) // 2
    fg_canvas.paste(logo_resized, (paste_x, paste_y), logo_resized)
    fg_canvas.save(foreground_path, "PNG")
    print(f"Saved transparent foreground to {foreground_path}")
    
    # 2. Generate launcher image with background color
    bg_rgb = hex_to_rgb(bg_color_hex)
    print(f"Generating launcher image with background color {bg_color_hex} {bg_rgb}...")
    bg_canvas = Image.new("RGBA", (1024, 1024), bg_rgb + (255,))
    
    # If the background is light, we should replace white text in the logo with a dark color
    if is_light_color(bg_rgb):
        print("Light background detected! Converting white text to dark blue/navy...")
        # We will map white-ish pixels to navy blue (0, 0, 80)
        # Let's inspect each pixel and if it's close to white (e.g. r > 200, g > 200, b > 200), we replace it.
        # We also keep red pixels (where r is high and g, b are low) unchanged.
        data = logo_resized.getdata()
        new_data = []
        for item in data:
            r, g, b, a = item
            # If the pixel is white or close to white
            if r > 200 and g > 200 and b > 200:
                # Replace with dark color (navy blue: 0, 0, 80)
                new_data.append((0, 0, 80, a))
            else:
                new_data.append(item)
        logo_resized_colored = Image.new("RGBA", logo_resized.size)
        logo_resized_colored.putdata(new_data)
        logo_to_paste = logo_resized_colored
    else:
        logo_to_paste = logo_resized
        
    bg_canvas.paste(logo_to_paste, (paste_x, paste_y), logo_to_paste)
    # Convert to RGB to discard alpha channel (important for iOS icons)
    bg_canvas_rgb = bg_canvas.convert("RGB")
    bg_canvas_rgb.save(launcher_path, "PNG")
    print(f"Saved launcher icon to {launcher_path}")

if __name__ == '__main__':
    color = '#000080' # default navy blue
    if len(sys.argv) > 1:
        color = sys.argv[1]
    generate_icons(color)
