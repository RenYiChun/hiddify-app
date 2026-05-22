import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/route_rules/data/running_process_repository.dart';
import 'package:hiddify/features/route_rules/notifier/generic_list_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rule_notifier.dart';
import 'package:hiddify/features/route_rules/overview/generic_list_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RunningProcessesPage extends HookConsumerWidget {
  const RunningProcessesPage({super.key, this.ruleListOrder});

  final int? ruleListOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final searchController = useTextEditingController();
    final searchQuery = useState('');
    final focusNode = useFocusNode();
    final provider = genericListNotifierProvider(ruleListOrder, RuleEnum.processName);
    final selected = ref.watch(provider).map((value) => '$value').toList(growable: false);
    final runningProcesses = ref.watch(runningProcessesProvider);

    void openManualListPage() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GenericListPage(
            ruleListOrder: ruleListOrder,
            ruleEnum: RuleEnum.processName,
            validator: (value) {
              if (isProcessName('$value')) return null;
              return t.pages.settings.routing.routeRule.rule.validProcessName;
            },
          ),
          fullscreenDialog: true,
        ),
      );
    }

    Future<void> clearSelection() async {
      final result = await ref
          .read(dialogNotifierProvider.notifier)
          .showConfirmation(
            title: t.pages.settings.routing.routeRule.genericList.clearList,
            message: t.pages.settings.routing.routeRule.genericList.clearListMsg,
          );
      if (result == true) ref.read(provider.notifier).reset();
    }

    void toggleProcessName(String processName) {
      final selectedIndex = selected.indexWhere((value) => value.toLowerCase() == processName.toLowerCase());
      if (selectedIndex == -1) {
        ref.read(provider.notifier).add(processName);
      } else {
        ref.read(provider.notifier).remove(selectedIndex);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(RuleEnum.processName.present(t)),
        actions: [
          IconButton(
            tooltip: t.common.update,
            onPressed: () => ref.invalidate(runningProcessesProvider),
            icon: const Icon(Icons.refresh_rounded),
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
              label: Text(t.common.search),
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
        onPressed: openManualListPage,
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
}
