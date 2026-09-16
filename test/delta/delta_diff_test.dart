import 'package:flutter_quill/src/delta/delta_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('只移动选区时，长文和 emoji 文本均没有内容差异', () {
    final text = '这是长笔记😀\n' * 3000;
    for (final position in [0, 5, text.length ~/ 2, text.length]) {
      final diff = getDiff(text, text, position);
      expect(diff.start, position);
      expect(diff.deleted, isEmpty);
      expect(diff.inserted, isEmpty);
    }
    // 输入连接建立前可能还没有有效选区，差异起点仍不能为负数。
    expect(getDiff(text, text, -1).start, 0);
  });

  test('拖动选区后替换、删除和插入文字仍返回正确差异', () {
    final replaced = getDiff('一二三四\n', '一新四\n', 2);
    expect(replaced.start, 1);
    expect(replaced.deleted, '二三');
    expect(replaced.inserted, '新');

    final deleted = getDiff('一二三四\n', '一四\n', 1);
    expect(deleted.start, 1);
    expect(deleted.deleted, '二三');
    expect(deleted.inserted, isEmpty);

    final inserted = getDiff('一二三四\n', '一二😀三四\n', 4);
    expect(inserted.start, 2);
    expect(inserted.deleted, isEmpty);
    expect(inserted.inserted, '😀');
  });
}
