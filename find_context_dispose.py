import os

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            with open(os.path.join(root, file)) as f:
                content = f.read()
                start_idx = 0
                while True:
                    idx = content.find('void dispose()', start_idx)
                    if idx == -1:
                        break
                    
                    brace_start = content.find('{', idx)
                    if brace_start != -1:
                        count = 0
                        brace_end = -1
                        for i in range(brace_start, len(content)):
                            if content[i] == '{':
                                count += 1
                            elif content[i] == '}':
                                count -= 1
                                if count == 0:
                                    brace_end = i
                                    break
                        
                        if brace_end != -1:
                            body = content[brace_start:brace_end]
                            if 'context' in body:
                                print(f'Match found in {os.path.join(root, file)}')
                                print(body)
                    
                    start_idx = idx + 14

