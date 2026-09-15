import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/features/student/models/lineage_node.dart';

void main() {
  group('Layer 1: LineageNode Tests (Coverage)', () {
    test('LineageNode constructor assigns values correctly', () {
      const node = LineageNode(
        id: 'test_node',
        name: 'Test Node',
        arabicName: 'عقدة اختبار',
        lifespan: '2000 - 2026',
        position: Offset(100, 200),
        childrenIds: ['child_1'],
        isHighlight: true,
      );

      expect(node.id, 'test_node');
      expect(node.name, 'Test Node');
      expect(node.arabicName, 'عقدة اختبار');
      expect(node.lifespan, '2000 - 2026');
      expect(node.position, const Offset(100, 200));
      expect(node.childrenIds, ['child_1']);
      expect(node.isHighlight, true);
    });

    test('LineageNode constructor handles defaults correctly', () {
      const node = LineageNode(
        id: 'test_node_2',
        name: 'Test Node 2',
        arabicName: 'عقدة 2',
        lifespan: '2026',
        position: Offset.zero,
      );

      expect(node.childrenIds, isEmpty);
      expect(node.isHighlight, false);
    });

    test('silsilahTreeData contains critical roots', () {
      // Verify Ibn Muqla is the starting point
      expect(silsilahTreeData.containsKey('ibn_muqla'), true);
      
      final root = silsilahTreeData['ibn_muqla']!;
      expect(root.name, 'Ibn Muqla');
      expect(root.isHighlight, true);
      expect(root.childrenIds, contains('ibn_albawwab'));
    });
  });
}
