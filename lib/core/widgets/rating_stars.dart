import 'package:flutter/material.dart';

import 'l10n_ext.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 20,
  });

  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          onChanged == null
              ? Icon(
                  i <= rating ? Icons.star : Icons.star_border,
                  size: size,
                  color: color,
                )
              : IconButton(
                  tooltip: context.l10n.ratingStars(i),
                  onPressed: () => onChanged!(i == rating ? 0 : i),
                  icon: Icon(
                    i <= rating ? Icons.star : Icons.star_border,
                    color: color,
                  ),
                ),
      ],
    );
  }
}
