from PIL import Image, ImageDraw

def remove_dark_box(img_path):
    img = Image.open(img_path)
    pixels = img.load()
    width, height = img.size
    
    # We are looking for a dark box with a yellow circle on the left side.
    # The background is mostly white.
    # We will scan the left half of the image (x from 0 to width//3, y from 0 to height//2).
    # We find the bounding box of dark pixels (r < 100, g < 100, b < 100).
    
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    
    for x in range(0, width//3):
        for y in range(0, height//2):
            r, g, b, a = img.getpixel((x, y))
            # Dark gray or black
            if r < 80 and g < 80 and b < 80:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
                
    if min_x < max_x and min_y < max_y:
        print(f"Found dark box in {img_path} at ({min_x}, {min_y}) to ({max_x}, {max_y})")
        # Expand the box slightly to cover shadows
        padding = 40
        min_x = max(0, min_x - padding)
        min_y = max(0, min_y - padding)
        max_x = min(width, max_x + padding)
        max_y = min(height, max_y + padding)
        
        # Get background color from just outside the box
        bg_color = img.getpixel((max_x + 10, min_y - 10))
        
        draw = ImageDraw.Draw(img)
        draw.rectangle([min_x, min_y, max_x, max_y], fill=bg_color)
        img.save(img_path)
        print(f"Removed box and saved {img_path}")
    else:
        print(f"No dark box found in {img_path}")

remove_dark_box('calligro_paint.png')
remove_dark_box('calligro_board.png')
