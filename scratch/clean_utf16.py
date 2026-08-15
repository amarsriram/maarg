import sys

try:
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-16le') as f:
        content = f.read()
except:
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

# The clean file ends around class _AvailableLoadsLabel.
# Let's find the string class _AvailableLoadsLabel extends StatelessWidget {
idx = content.find("class _AvailableLoadsLabel extends StatelessWidget {")

if idx != -1:
    end_idx = content.find("}\n", content.find("}\n", idx) + 1) + 2
    clean_content = content[:end_idx]
    
    # Write back as utf-8
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
        # We also need to strip any null bytes that were introduced by utf-16 conversion if it was read as utf-8
        clean_content = clean_content.replace('\x00', '')
        f.write(clean_content)
    print("Cleaned!")
else:
    print("Could not find label class")
