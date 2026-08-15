import sys

# Try to read the file, handling potential encoding issues
try:
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-16le') as f:
        content = f.read()
except UnicodeDecodeError:
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

index = content.rfind("import 'dart:async';")
if index != -1 and index > len(content) // 2:
    # Remove the imports but keep the class
    class_index = content.find("class _ActiveTripWorkspace extends ConsumerStatefulWidget {", index)
    if class_index != -1:
        new_content = content[:index] + content[class_index:]
        with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Cleaned up appended imports.")
    else:
        print("Class not found.")
else:
    print("Imports not found near the end.")
