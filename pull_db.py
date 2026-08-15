import subprocess
import os

try:
    cmd = [r"C:\Users\amars\AppData\Local\Android\Sdk\platform-tools\adb.exe", "-s", "emulator-5554", "exec-out", "run-as", "com.maarg.app.maarg", "cat", "cache/firestore.db"]
    result = subprocess.run(cmd, capture_output=True)
    with open("firestore_cache.db", "wb") as f:
        f.write(result.stdout)
    print("DB pulled successfully.")
except Exception as e:
    print("Error:", e)
