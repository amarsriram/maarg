import re

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add missing imports
if "package:firebase_core/firebase_core.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", 
                              "import 'package:flutter/material.dart';\nimport 'package:firebase_core/firebase_core.dart';")

if "core/utils/load_formatters.dart" not in content:
    content = content.replace("import 'package:flutter/material.dart';", 
                              "import 'package:flutter/material.dart';\nimport '../../../../core/utils/load_formatters.dart';")

# 2. Fix the 3-argument call to _buildStateWorkspace
# Look for: _buildStateWorkspace(state, isDark, loads),
content = content.replace("_buildStateWorkspace(state, isDark, loads),", "_buildStateWorkspace(state, isDark, loads, activeTrip, hasTripError),")

# Also, the variables hasLoadError and hasTripError were marked unused. But they are used in:
# hasLoadError ? _buildLoadErrorHome(isDark) : _buildStateWorkspace(state, isDark, loads, activeTrip, hasTripError)
# Let's ensure the `build` method is correct.

# I will write back the content
with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)
