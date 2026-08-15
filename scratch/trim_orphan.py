with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the orphaned block: it starts with a blank line followed by "    return Column("
# after the closing "}" of the new _ActiveTripWorkspaceState class.
# We know the file ends with "}}" on line 1096-1097 (the class close + file end),
# then orphaned code follows.

# Strategy: find the SECOND occurrence of "class _ActiveTripWorkspaceState" 
# or find "}\n}\n\n    return Column" pattern and truncate there.

content = ''.join(lines)

# The new class ends with "}}\n" (method close + class close)
# Then we have a blank line and "    return Column(" (the orphan)
# Find the position of the orphan start
orphan_marker = "}\n\n    return Column("
idx = content.find(orphan_marker)

if idx != -1:
    # Keep everything up to and including the "}}\n" part
    clean_content = content[:idx + 2]  # include the two closing braces + newline
    with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
        f.write(clean_content)
    print(f"Truncated at index {idx}. File now has {len(clean_content.splitlines())} lines.")
else:
    print("Orphan marker not found. Manual inspection needed.")
    # Print last 10 lines
    print('\n'.join(lines[-20:]))
