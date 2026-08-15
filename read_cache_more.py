import sqlite3
import re

try:
    conn = sqlite3.connect('firestore_cache.db')
    cursor = conn.cursor()
    cursor.execute("SELECT path, contents FROM remote_documents WHERE path LIKE 'loads%' LIMIT 20")
    rows = cursor.fetchall()
    
    for row in rows:
        readable = re.sub(rb'[^a-zA-Z0-9_,:.\-\{\}\[\]\" ]', b' ', row[1]).decode('utf-8', errors='ignore')
        readable = re.sub(r' +', ' ', readable)
        
        m1 = re.search(r'pickupLocation(.*?)providerUid', readable)
        m2 = re.search(r'dropLocation(.*?)cargo', readable)
        if not m2:
            m2 = re.search(r'dropLocation(.*?)weight', readable)
            
        print(row[0])
        if m1:
            print(f'  pickup: {m1.group(1).strip()}')
        if m2:
            print(f'  drop: {m2.group(1).strip()}')
except Exception as e:
    pass
