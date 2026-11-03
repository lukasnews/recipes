import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n_ext.dart';

/// Shows loading / error states for an [AsyncValue] and [data] otherwise.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    final v = value.value;
    if (v != null) return data(v);
    if (value.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.errorGeneric('${value.error}'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
