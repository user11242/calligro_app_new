import os
import plistlib
import shutil
import json

def decode_nskeyedarchiver_full(filepath):
    """Parse NSKeyedArchiver and extract ALL brush properties + name."""
    try:
        with open(filepath, 'rb') as f:
            archive = plistlib.load(f)
        
        objects = archive.get('$objects', [])
        
        # Collect ALL properties from all dict objects
        properties = {}
        string_values = []
        
        for obj in objects:
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if isinstance(value, (int, float, bool)):
                        properties[key] = value
                    elif isinstance(value, str) and key != '$class' and not key.startswith('$'):
                        properties[key] = value
            elif isinstance(obj, str) and obj != '$null':
                string_values.append(obj)
        
        # The brush name is typically stored as a standalone string in $objects
        # Filter to find Arabic or meaningful names
        name = None
        for s in string_values:
            # Skip internal class names and technical keys
            if s.startswith('NS') or s.startswith('$') or s.startswith('dynamics') or s.startswith('shape') or s.startswith('taper') or s.startswith('grain') or s.startswith('plot') or s.startswith('texture') or s.startswith('blend') or s.startswith('metallic') or s.startswith('lightness') or s.startswith('saturation') or s.startswith('roughness') or s.startswith('height') or s.startswith('dual') or s.startswith('max') or s.startswith('min') or s.startswith('saved') or s.startswith('imported') or s.startswith('oriented') or s.startswith('pencil') or s.startswith('rendering') or s.startswith('wet') or s.startswith('burnt') or s.startswith('stamp') or s.startswith('size') or s.startswith('paint') or s.startswith('erase') or s.startswith('smudge') or s.startswith('preview') or s.startswith('attack') or s.startswith('version') or s.startswith('hue') or s.startswith('jitter') or s.startswith('opacity') or s.startswith('bleed') or s.startswith('gradation') or s.startswith('brightness') or s.startswith('darkness') or s.startswith('secondary') or s.startswith('extended'):
                continue
            if len(s) > 2 and len(s) < 100:
                # Check if it has Arabic characters or looks like a name
                has_arabic = any('\u0600' <= c <= '\u06FF' for c in s)
                if has_arabic:
                    name = s
                    break
        
        # If no Arabic name found, check for any meaningful non-technical string
        if not name:
            for s in string_values:
                if len(s) > 2 and len(s) < 50 and not any(c in s for c in ['$', 'NS', '{', '}', 'bplist']):
                    # Skip known property key names
                    known_keys = {'name', 'root', 'class', 'null', 'archiver', 'top', 'objects', 'version'}
                    if s.lower() not in known_keys and not s[0].islower():
                        name = s
                        break
        
        return properties, name, string_values
    except Exception as e:
        print(f"  Error: {e}")
        return {}, None, []

def main():
    brushes_dir = "/Users/yazanqattous/Desktop/flutter_projects/calligro_app/brushes"
    public_brushes_dir = "/Users/yazanqattous/Desktop/flutter_projects/calligro_app/web_portal/public/brushes"
    os.makedirs(public_brushes_dir, exist_ok=True)
    
    plist_path = os.path.join(brushes_dir, 'brushset.plist')
    with open(plist_path, 'rb') as f:
        brushset = plistlib.load(f)
    
    uuids = brushset.get('brushes', [])
    output_data = []
    
    for i, uuid in enumerate(uuids):
        folder_path = os.path.join(brushes_dir, uuid)
        archive_path = os.path.join(folder_path, 'Brush.archive')
        shape_path = os.path.join(folder_path, 'Shape.png')
        thumbnail_path = os.path.join(folder_path, 'QuickLook', 'Thumbnail.png')
        
        props, extracted_name, all_strings = decode_nskeyedarchiver_full(archive_path)
        
        # Print strings for debugging name extraction
        meaningful_strings = [s for s in all_strings if len(s) > 1 and len(s) < 100 and not s.startswith('NS') and not s.startswith('$')]
        print(f"Brush {i+1} ({uuid[:8]}): name={extracted_name}, strings={meaningful_strings[:5]}")
        
        name = extracted_name or f"Brush {i+1}"
        
        # Extract ALL the critical rendering properties
        # shapeAngle is in RADIANS in Procreate
        shape_angle_rad = float(props.get('shapeAngle', 0))
        
        # paintSize is 0-1 normalized, represents default size
        paint_size = float(props.get('paintSize', 0.05))
        
        # maxSize and minSize (0-1 normalized)
        max_size = float(props.get('maxSize', 1.0))
        min_size = float(props.get('minSize', 0.0))
        
        # Spacing between stamps (0 = no gap, 1 = max gap)
        plot_spacing = float(props.get('plotSpacing', 0.0))
        
        # Smoothing/Streamline
        streamline = float(props.get('plotSmoothing', 0.5))
        
        # Taper (how much the stroke tapers at ends)
        taper_size = float(props.get('taperSize', 0.0))
        taper_opacity = float(props.get('taperOpacity', 1.0))
        
        # Opacity
        max_opacity = float(props.get('maxOpacity', 1.0))
        min_opacity = float(props.get('minOpacity', 0.0))
        paint_opacity = float(props.get('paintOpacity', 1.0))
        
        # Shape properties
        shape_roundness = float(props.get('shapeRoundness', 1.0))
        shape_orientation = int(props.get('shapeOrientation', 0))
        
        # Dynamics
        pressure_size = float(props.get('dynamicsPressureSize', 0.0))
        speed_size = float(props.get('dynamicsSpeedSize', 0.0))
        speed_opacity = float(props.get('dynamicsSpeedOpacity', 1.0))
        
        # Copy shape PNG
        if os.path.exists(shape_path):
            shutil.copy(shape_path, os.path.join(public_brushes_dir, f"{uuid}.png"))
        
        # Copy QuickLook thumbnail
        has_thumb = False
        if os.path.exists(thumbnail_path):
            shutil.copy(thumbnail_path, os.path.join(public_brushes_dir, f"{uuid}_thumb.png"))
            has_thumb = True
        
        brush_entry = {
            "id": uuid,
            "name": name,
            "shapeAngle": shape_angle_rad,
            "paintSize": paint_size,
            "maxSize": max_size,
            "minSize": min_size,
            "spacing": plot_spacing,
            "streamline": streamline,
            "taperSize": taper_size,
            "taperOpacity": taper_opacity,
            "maxOpacity": max_opacity,
            "minOpacity": min_opacity,
            "paintOpacity": paint_opacity,
            "shapeRoundness": shape_roundness,
            "shapeOrientation": shape_orientation,
            "pressureSize": pressure_size,
            "speedSize": speed_size,
            "speedOpacity": speed_opacity,
            "hasThumbnail": has_thumb,
        }
        output_data.append(brush_entry)
    
    with open(os.path.join(public_brushes_dir, 'brushes.json'), 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
    
    print(f"\n=== DONE: Extracted {len(output_data)} brushes with full settings ===")

if __name__ == "__main__":
    main()
