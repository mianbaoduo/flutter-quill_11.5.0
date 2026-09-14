import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final selection in [
    const TextSelection.collapsed(offset: 0),
    const TextSelection.collapsed(offset: 3),
    const TextSelection(baseOffset: 3, extentOffset: 5),
  ]) {
    testWidgets('已有输入连接应同步新的光标或选区：$selection', (tester) async {
      final controller = QuillController(
        document: Document()..insert(0, '1234567890'),
        selection: const TextSelection.collapsed(offset: 10),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          home: Scaffold(
            body: QuillEditor.basic(
              controller: controller,
              config: const QuillEditorConfig(autoFocus: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.state<QuillRawEditorState>(
        find.byType(QuillRawEditor),
      );
      expect(tester.testTextInput.editingState!['selectionBase'], 10);

      // 模拟页面选区已变化、输入法还保留旧位置，再次请求已有的输入连接。
      // ignore: experimental_member_use
      controller.replaceText(0, 0, '', selection, shouldNotifyListeners: false);
      editor.openConnectionIfNeeded();
      expect(
        tester.testTextInput.editingState!['selectionBase'],
        selection.baseOffset,
      );
      expect(
        tester.testTextInput.editingState!['selectionExtent'],
        selection.extentOffset,
      );

      // 输入法依据收到的选区插入文字，应在正文中间插入或替换选中文字。
      final remote = TextEditingValue.fromJSON(
        tester.testTextInput.editingState!,
      );
      final updated = remote.replaced(remote.selection, '8');
      tester.testTextInput.updateEditingValue(updated);
      await tester.pump();
      expect(controller.document.toPlainText(), updated.text);
      expect(controller.selection, updated.selection);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }
}
