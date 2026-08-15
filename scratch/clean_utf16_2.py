import sys

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'rb') as f:
    b = f.read()

# decode and remove null bytes
content = b.decode('utf-8', errors='ignore').replace('\x00', '')

# Also remove any space-separated class names if they got mangled (e.g. c l a s s)
# But null byte removal should fix utf-16 to ascii conversion for standard chars.

idx = content.find("class _AvailableLoadsLabel extends StatelessWidget {")
if idx != -1:
    end_idx = content.find("}\n", content.find("}\n", idx) + 1) + 2
    clean_content = content[:end_idx]
    
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
        f.write(clean_content)
    print("Cleaned!")
else:
    print("Could not find label class after null byte removal. The file might be corrupted differently.")
    
    # Try finding the 'import dart:async' appended part
    idx2 = content.rfind("import 'dart:async';")
    if idx2 != -1 and idx2 > len(content) // 2:
        print("Found appended import block, stripping everything after it.")
        clean_content = content[:idx2]
        with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
            f.write(clean_content)
