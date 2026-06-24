import sys
from PIL import Image

def get_edge_color(image_path):
    img = Image.open(image_path).convert('RGB')
    w, h = img.size
    
    # Sample top center, bottom center, left center, right center
    samples = [
        img.getpixel((w//2, 10)),
        img.getpixel((w//2, h-10)),
        img.getpixel((10, h//2)),
        img.getpixel((w-10, h//2))
    ]
    
    for i, s in enumerate(samples):
        print(f"Sample {i}: rgb({s[0]}, {s[1]}, {s[2]}) -> #{s[0]:02x}{s[1]:02x}{s[2]:02x}")

get_edge_color(sys.argv[1])
