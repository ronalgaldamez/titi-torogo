import 'package:flutter/material.dart';
import '../theme.dart';

class FilterTabs extends StatelessWidget {
  const FilterTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.keyPrefix,
    this.icons,
    super.key,
  });
  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    if (icons == null) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  key: ValueKey('$keyPrefix-$index'),
                  label: Text(labels[index]),
                  selected: selectedIndex == index,
                  onSelected: (_) => onSelected(index),
                ),
              ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : AppSpacing.xs,
              ),
              child: Semantics(
                selected: selectedIndex == index,
                child: TextButton(
                  key: ValueKey('$keyPrefix-$index'),
                  style: TextButton.styleFrom(
                    backgroundColor: selectedIndex == index
                        ? AppTheme.tealSoft
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: selectedIndex == index
                        ? AppTheme.tealDeep
                        : AppTheme.navy,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 2,
                    ),
                    minimumSize: const Size(48, 72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => onSelected(index),
                  child: Column(
                    children: [
                      Icon(icons![index], size: 22),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
