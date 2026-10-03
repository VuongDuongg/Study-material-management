import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final List<String> subjects;
  final List<String> categories;
  final String selectedSubject;
  final String selectedCategory;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onCategoryChanged;

  const FilterBar({
    super.key,
    required this.subjects,
    required this.categories,
    required this.selectedSubject,
    required this.selectedCategory,
    required this.onSubjectChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Danh mục (Categories) Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: categories.map((cat) {
              final isSelected = selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => onCategoryChanged(cat),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                  avatar: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Môn học Dropdown Filter nếu có môn học
        if (subjects.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Môn học:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: subjects.map((sub) {
                        final isSelected = selectedSubject == sub;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(sub, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (_) => onSubjectChanged(sub),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
