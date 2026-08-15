import sqlite3

try:
    conn = sqlite3.connect('firestore_cache.db')
    cursor = conn.cursor()
    cursor.execute("SELECT path FROM remote_documents LIMIT 20")
    rows = cursor.fetchall()
    
    print('Paths in cache:')
    for row in rows:
        print(row[0])
except Exception as e:
    print('Error:', e)
