import os
import glob

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Find "AutoTranslatedText(" followed by spaces/newlines and "CourseUtils.getLocalizedCourseName"
    import re
    # We only want to replace AutoTranslatedText when it wraps CourseUtils
    new_content = re.sub(
        r'AutoTranslatedText\(\s*CourseUtils\.getLocalizedCourseName',
        r'Text(CourseUtils.getLocalizedCourseName',
        content
    )
    
    if new_content != content:
        print(f"Fixed {filepath}")
        with open(filepath, 'w') as f:
            f.write(new_content)

for filepath in glob.glob('lib/**/*.dart', recursive=True):
    fix_file(filepath)

