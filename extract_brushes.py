import plistlib, os, json, shutil

brushes_dir = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/brushes'
public_dir = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/web_portal/public/brushes'
os.makedirs(public_dir, exist_ok=True)

with open(os.path.join(brushes_dir, 'brushset.plist'), 'rb') as f:
    brushset = plistlib.load(f)

uuids = brushset.get('brushes', [])
output = []

for uuid in uuids:
    folder = os.path.join(brushes_dir, uuid)
    archive_path = os.path.join(folder, 'Brush.archive')
    shape_path = os.path.join(folder, 'Shape.png')
    thumb_path = os.path.join(folder, 'QuickLook', 'Thumbnail.png')

    try:
        with open(archive_path, 'rb') as f:
            archive = plistlib.load(f)
        objects = archive.get('$objects', [])
        props = {}
        all_strings = []
        for obj in objects:
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if not k.startswith('$'):
                        props[k] = v
            elif isinstance(obj, str) and obj != '$null':
                all_strings.append(obj)

        name = None
        for s in all_strings:
            if any('\u0600' <= c <= '\u06FF' for c in s) and len(s) > 1:
                name = s; break
        if not name:
            name = f"Brush {uuid[:4]}"

        # Copy assets
        if os.path.exists(shape_path):
            shutil.copy(shape_path, os.path.join(public_dir, f"{uuid}.png"))
        has_thumb = os.path.exists(thumb_path)
        if has_thumb:
            shutil.copy(thumb_path, os.path.join(public_dir, f"{uuid}_thumb.png"))

        entry = {
            "id": uuid,
            "name": name,
            # Orientation behavior
            "oriented": bool(props.get('oriented', True)),
            "shapeOrientation": int(props.get('shapeOrientation', 0)),
            # Fixed angle offset from stroke direction (radians)
            "shapeAngle": float(props.get('shapeAngle', 0)),
            # Size
            "paintSize": float(props.get('paintSize', 0.05)),
            "maxSize": float(props.get('maxSize', 1.0)),
            "minSize": float(props.get('minSize', 0.0)),
            # Opacity
            "paintOpacity": float(props.get('paintOpacity', 1.0)),
            "maxOpacity": float(props.get('maxOpacity', 1.0)),
            "minOpacity": float(props.get('minOpacity', 0.0)),
            # Stroke behavior
            "plotSpacing": float(props.get('plotSpacing', 0.0)),
            "plotSmoothing": float(props.get('plotSmoothing', 0.5)),
            # Shape
            "shapeRoundness": float(props.get('shapeRoundness', 1.0)),
            "shapeCount": float(props.get('shapeCount', 0.0)),
            # Taper
            "taperSize": float(props.get('taperSize', 0.0)),
            "taperOpacity": float(props.get('taperOpacity', 1.0)),
            "taperStartLength": float(props.get('taperStartLength', 0.0)),
            "taperEndLength": float(props.get('taperEndLength', 0.0)),
            # Dynamics
            "dynamicsSpeedSize": float(props.get('dynamicsSpeedSize', 0.0)),
            "dynamicsSpeedOpacity": float(props.get('dynamicsSpeedOpacity', 1.0)),
            "dynamicsPressureSize": float(props.get('dynamicsPressureSize', 0.0)),
            "dynamicsPressureOpacity": float(props.get('dynamicsPressureOpacity', 0.0)),
            "hasThumbnail": has_thumb,
        }
        output.append(entry)
        print(f"OK: {name}")
    except Exception as e:
        print(f"ERROR {uuid[:8]}: {e}")

with open(os.path.join(public_dir, 'brushes.json'), 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

print(f"\nDone. {len(output)} brushes.")
