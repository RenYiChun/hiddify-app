import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/route_rules/data/running_process_repository.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProcessDirectRulesPage extends HookConsumerWidget {
  const ProcessDirectRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final searchController = useTextEditingController();
    final searchQuery = useState('');
    final focusNode = useFocusNode();
    final selected = ref.watch(ConfigOptions.effectiveProcessDirectRuleNames);
    final runningProcesses = ref.watch(runningProcessesProvider);

    Future<void> addProcessName() async {
      final result = await ref
          .read(dialogNotifierProvider.notifier)
          .showSettingText(
            lable: t.pages.settings.routing.routeRule.genericList.addNew,
            validator: (value) {
              if (isProcessName('$value')) return null;
              return t.pages.settings.routing.routeRule.rule.validProcessName;
            },
          );
      if (result is! String) return;
      await _updateSelected(ref, [...selected, result]);
    }

    Future<void> clearSelection() async {
      final result = await ref
          .read(dialogNotifierProvider.notifier)
          .showConfirmation(
            title: t.pages.settings.routing.routeRule.genericList.clearList,
            message: t.pages.settings.routing.routeRule.genericList.clearListMsg,
          );
      if (result == true) await _updateSelected(ref, const []);
    }

    Future<void> resetToRegionDefaults() async {
      await ref.read(ConfigOptions.processDirectRuleNames.notifier).reset();
    }

    Future<void> toggleProcessName(String processName) async {
      final selectedIndex = selected.indexWhere((value) => value.toLowerCase() == processName.toLowerCase());
      if (selectedIndex == -1) {
        await _updateSelected(ref, [...selected, processName]);
      } else {
        final updated = selected.toList()..removeAt(selectedIndex);
        await _updateSelected(ref, updated);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('进程直连规则'),
        actions: [
          IconButton(
            tooltip: t.common.update,
            onPressed: () => ref.invalidate(runningProcessesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: t.common.reset,
            onPressed: resetToRegionDefaults,
            icon: const Icon(Icons.restore_rounded),
          ),
          IconButton(
            tooltip: t.pages.settings.routing.routeRule.genericList.clearList,
            onPressed: selected.isEmpty ? null : clearSelection,
            icon: const Icon(Icons.clear_all),
          ),
          const Gap(8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kMinInteractiveDimension),
          child: TextField(
            focusNode: focusNode,
            controller: searchController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              label: const Text('Search'),
              suffixIcon: searchQuery.value.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                        searchQuery.value = '';
                        focusNode.unfocus();
                      },
                      icon: const Icon(Icons.cancel_outlined),
                    )
                  : null,
            ),
            onChanged: (value) => searchQuery.value = value,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addProcessName,
        label: Text(t.pages.settings.routing.routeRule.genericList.addNew),
        icon: const Icon(Icons.add_rounded),
      ),
      body: runningProcesses.when(
        data: (processes) {
          final items = buildRunningProcessSelectionItems(
            runningProcesses: processes,
            selectedProcessNames: selected,
            searchQuery: searchQuery.value,
          );

          if (items.isEmpty) {
            return Center(child: Text(t.common.empty));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is RunningProcess) {
                final isSelected = selected.any((value) => value.toLowerCase() == item.name.toLowerCase());
                return CheckboxListTile(
                  title: Text(item.name, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                  subtitle: item.path == null
                      ? Text('pid: ${item.pid ?? '-'}', overflow: TextOverflow.ellipsis)
                      : Text(item.path!, overflow: TextOverflow.ellipsis),
                  value: isSelected,
                  onChanged: (_) => toggleProcessName(item.name),
                );
              }

              if (item is String) {
                return CheckboxListTile(
                  title: Row(
                    children: [
                      const Icon(size: 16, Icons.warning_rounded, color: Colors.amber),
                      const Gap(4),
                      Expanded(
                        child: Text(item, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  value: selected.any((value) => value.toLowerCase() == item.toLowerCase()),
                  onChanged: (_) => toggleProcessName(item),
                );
              }

              throw Exception('Data type is not supported');
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _updateSelected(WidgetRef ref, List<String> processNames) async {
    await ref.read(ConfigOptions.processDirectRuleNames.notifier).update(_cleanSelectedProcessNames(processNames));
  }

  List<String> _cleanSelectedProcessNames(List<String> processNames) {
    return parseProcessDirectRuleNames(formatProcessDirectRuleNames(processNames));
  }
}
