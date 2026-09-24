import os
import re
import shutil

src = r'C:\Users\atubt\OneDrive\Desktop\App projects\Vitanet\bot_temp'
dst = r'C:\Users\atubt\Downloads\TradingBotCode'

if not os.path.exists(dst):
    os.makedirs(dst)

patterns = [
    (r'(?i)(api_?key\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(password\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(login\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(server\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(secret\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(token\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    # MT5 / Exness specific variables
    (r'(?i)(mt5_?login\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(mt5_?password\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
    (r'(?i)(mt5_?server\s*[:=]\s*[\'\"])(.*?)([\'\"])', r'\g<1>REDACTED\g<3>'),
]

# Specifically clean .env file entirely or just keys
def clean_content(content):
    for pattern, repl in patterns:
        content = re.sub(pattern, repl, content)
    
    # Also clean numeric assignments without quotes for logins
    content = re.sub(r'(?i)(login\s*[:=]\s*)\d+', r'\g<1>000000', content)
    content = re.sub(r'(?i)(mt5_?login\s*[:=]\s*)\d+', r'\g<1>000000', content)
    
    return content

processed = 0
for root, dirs, files in os.walk(src):
    if '__pycache__' in dirs: dirs.remove('__pycache__')
    if 'fxalexg_bot_backup' in root: continue
    
    for f in files:
        if f.endswith(('.db', '.log', '.zip', '.exe', '.gz')): continue
        src_file = os.path.join(root, f)
        rel_path = os.path.relpath(src_file, src)
        dst_file = os.path.join(dst, rel_path)
        
        os.makedirs(os.path.dirname(dst_file), exist_ok=True)
        
        try:
            with open(src_file, 'r', encoding='utf-8') as file:
                content = file.read()
                
            content = clean_content(content)
                
            with open(dst_file, 'w', encoding='utf-8') as file:
                file.write(content)
            processed += 1
        except UnicodeDecodeError:
            shutil.copy2(src_file, dst_file)

print(f"Successfully processed {processed} files and saved to {dst}")
