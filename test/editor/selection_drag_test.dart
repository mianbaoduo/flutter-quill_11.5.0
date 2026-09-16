import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/editor/widgets/text/text_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('拖动手柄未跨过字符时，不重复通知编辑器和工具栏', (tester) async {
    final controller = QuillController(
      document: Document()..insert(0, '一二三四五六七八九十'),
      selection: const TextSelection(baseOffset: 2, extentOffset: 6),
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      home: Scaffold(
        body: QuillEditor.basic(
          controller: controller,
          config: const QuillEditorConfig(autoFocus: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final editor =
        tester.state<QuillRawEditorState>(find.byType(QuillRawEditor));
    editor.selectionOverlay!.setHandlesVisible(true);
    await tester.pumpAndSettle();
    final handles = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onPanUpdate != null,
    );
    expect(handles, findsNWidgets(2));
    final handle = tester.widget<GestureDetector>(handles.last);
    final caret = editor.renderEditor.getLocalRectForCaret(
      const TextPosition(offset: 6),
    );
    final position = editor.renderEditor.localToGlobal(caret.center);
    handle.onPanStart!(DragStartDetails(globalPosition: position));
    // 先移动一次手柄，再记录连续停留在同一字符内的回调。
    handle.onPanUpdate!(DragUpdateDetails(globalPosition: position));
    var notifications = 0;
    controller.addListener(() => notifications++);
    for (var i = 0; i < 100; i++) {
      handle.onPanUpdate!(DragUpdateDetails(globalPosition: position));
    }
    expect(notifications, 0);

    // 跨过字符后仍须立即同步选区，下一次输入按这个选区替换。
    final nextCaret = editor.renderEditor.getLocalRectForCaret(
      const TextPosition(offset: 8),
    );
    handle.onPanUpdate!(DragUpdateDetails(
      globalPosition: editor.renderEditor.localToGlobal(nextCaret.center),
    ));
    expect(notifications, 1);
    expect(controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 8));
    final remote =
        TextEditingValue.fromJSON(tester.testTextInput.editingState!);
    expect(remote.selection, controller.selection);
    handle.onPanEnd!(DragEndDetails());
    tester.testTextInput
        .updateEditingValue(remote.replaced(remote.selection, '新'));
    await tester.pump();
    expect(controller.document.toPlainText(), '一二新九十\n');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('放大镜在下一帧跟随拖动并在松手时消失', (tester) async {
    final offset = ValueNotifier<Offset?>(null);
    addTearDown(offset.dispose);
    const lensKey = ValueKey('lens');
    await tester.pumpWidget(MaterialApp(
      home: EditorTextSelectionGestureDetector(
        dragOffsetNotifier: offset,
        quillMagnifierBuilder: (position) => Positioned(
          key: lensKey,
          left: position.dx,
          top: position.dy,
          child: const SizedBox(width: 10, height: 10),
        ),
        child: const SizedBox.expand(),
      ),
    ));
    offset.value = const Offset(80, 100);
    await tester.pump();
    expect(find.byKey(lensKey), findsOneWidget);
    expect(tester.widget<Positioned>(find.byKey(lensKey)).left, 80);
    offset.value = const Offset(120, 110);
    await tester.pump();
    expect(tester.widget<Positioned>(find.byKey(lensKey)).left, 120);
    offset.value = null;
    await tester.pump();
    expect(find.byKey(lensKey), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('构建期间更新拖动位置，卸载后不再访问放大镜上下文', (tester) async {
    final offset = ValueNotifier<Offset?>(null);
    final remove = ValueNotifier(false);
    addTearDown(offset.dispose);
    addTearDown(remove.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: remove,
        builder: (context, shouldRemove, child) {
          if (shouldRemove) {
            offset.value = const Offset(80, 100);
            return const SizedBox.shrink();
          }
          return EditorTextSelectionGestureDetector(
            dragOffsetNotifier: offset,
            quillMagnifierBuilder: (_) => const SizedBox.shrink(),
            child: const SizedBox.expand(),
          );
        },
      ),
    ));
    remove.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
