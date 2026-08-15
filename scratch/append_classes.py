with open('scratch/active_trip_composer.dart', 'r', encoding='utf-8') as f:
    composer_content = f.read()

classes_part = composer_content[composer_content.find('class _ActiveTripWorkspace extends ConsumerStatefulWidget {'):]

with open('lib/features/truck_owner/presentation/tabs/truck_owner_home_tab.dart', 'a', encoding='utf-8') as f:
    f.write("\n\n" + classes_part)
