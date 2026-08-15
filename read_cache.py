import sqlite3
import re

try:
    conn = sqlite3.connect('firestore_cache.db')
    cursor = conn.cursor()
    cursor.execute("SELECT path, contents FROM remote_documents WHERE path LIKE 'loads%' LIMIT 2")
    rows = cursor.fetchall()
    
    if not rows:
        print('No loads found in cache.')
    for row in rows:
        path_str = str(row[0])
        content_bytes = row[1]
        
        readable = re.sub(rb'[^a-zA-Z0-9_,:.\-\{\}\[\]\" ]', b' ', content_bytes).decode('utf-8', errors='ignore')
        readable = re.sub(r' +', ' ', readable)
        
        print(f'Path: {path_str}')
        
        # Look for the structure
        print('Raw Strings:', readable)
        
        import ast
        
        # Let's just find pickupLocation followed by something, up to dropLocation
        m1 = re.search(r'pickupLocation(.*?)providerUid', readable)
        m2 = re.search(r'dropLocation(.*?)cargo', readable)
        if not m2:
            m2 = re.search(r'dropLocation(.*?)(?:weight|createdAt)', readable)
            
        if m1:
            print(f'pickupLocation raw: {m1.group(1).strip()}')
        if m2:
            print(f'dropLocation raw: {m2.group(1).strip()}')
            
        print('---')
except Exception as e:
    print('Error:', e)
