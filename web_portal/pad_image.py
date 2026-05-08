from PIL import Image

# Open the square v8 generated image
img_path = "/Users/yazanqattous/.gemini/antigravity/brain/fd2254e5-7591-4da1-a638-959c2b68d33b/web_hero_en_v8_widescreen_final_1778255237571.png"
img = Image.open(img_path)

width, height = img.size
new_width = int(height * 16 / 9)

# Create a new blank image
new_img = Image.new('RGB', (new_width, height))

# Paste the original image on the left
new_img.paste(img, (0, 0))

# Crop a vertical strip from the right edge of the original image (e.g., last 100 pixels)
strip_width = 100
strip = img.crop((width - strip_width, 0, width, height))

# Tile the strip to fill the remaining width
current_x = width
while current_x < new_width:
    new_img.paste(strip, (current_x, 0))
    current_x += strip_width

# Save the padded image
new_img.save("/Users/yazanqattous/Desktop/flutter_projects/calligro_app/web_portal/public/assets/images/web-hero-en.jpeg")
print("Image padded successfully to 16:9 aspect ratio.")
