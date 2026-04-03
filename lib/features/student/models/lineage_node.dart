import 'package:flutter/material.dart';

class LineageNode {
  final String id;
  final String name;             // e.g "Ibn Muqla"
  final String arabicName;       // e.g "ابن مقلة"
  final String lifespan;         // e.g "886 - 940m"
  final List<String> childrenIds;// The core line of descent
  final Offset position;         // X, Y position on the virtual canvas
  final bool isHighlight;        // If true, style as a major era founder
  
  const LineageNode({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.lifespan,
    required this.position,
    this.childrenIds = const [],
    this.isHighlight = false,
  });
}

// Map the tree positions on a fixed coordinate system.
// We will center the Abbasid roots at the top (x: 500, y: 100).
final Map<String, LineageNode> silsilahTreeData = {
  // --- ABBASID ROOTS ---
  'ibn_muqla': const LineageNode(
    id: 'ibn_muqla',
    name: 'Ibn Muqla',
    arabicName: 'ابن مقلة',
    lifespan: '886 - 940',
    position: Offset(500, 100),
    childrenIds: ['ibn_albawwab'],
    isHighlight: true,
  ),
  'ibn_albawwab': const LineageNode(
    id: 'ibn_albawwab',
    name: 'Ibn al-Bawwab',
    arabicName: 'ابن البواب',
    lifespan: 'd. 1022',
    position: Offset(500, 220),
    childrenIds: ['yaqut'],
  ),
  'yaqut': const LineageNode(
    id: 'yaqut',
    name: 'Yaqut al-Musta\'simi',
    arabicName: 'ياقوت المستعصمي',
    lifespan: 'd. 1298',
    position: Offset(500, 340),
    childrenIds: ['hamdullah'],
    isHighlight: true,
  ),

  // --- OTTOMAN CLASSICAL ---
  'hamdullah': const LineageNode(
    id: 'hamdullah',
    name: 'Sheikh Hamdullah',
    arabicName: 'الشيخ حمد الله',
    lifespan: '1436 - 1520',
    position: Offset(500, 500),
    childrenIds: ['hafiz_osman'],
    isHighlight: true,
  ),
  // Darwish Ali is often parallel
  'darwish_ali': const LineageNode(
    id: 'darwish_ali',
    name: 'Darwish Ali',
    arabicName: 'درويش علي',
    lifespan: 'd. 1673',
    position: Offset(700, 500),
    childrenIds: ['hafiz_osman'],
  ),
  'hafiz_osman': const LineageNode(
    id: 'hafiz_osman',
    name: 'Hafiz Osman',
    arabicName: 'الحافظ عثمان',
    lifespan: '1642 - 1698',
    position: Offset(500, 620),
    childrenIds: ['ismail_zuhdi'],
    isHighlight: true,
  ),
  'ismail_zuhdi': const LineageNode(
    id: 'ismail_zuhdi',
    name: 'Ismail Zuhdi',
    arabicName: 'إسماعيل زهدي',
    lifespan: 'd. 1806',
    position: Offset(500, 740),
    childrenIds: ['mustafa_rakim'],
  ),
  'mustafa_rakim': const LineageNode(
    id: 'mustafa_rakim',
    name: 'Mustafa Rakim',
    arabicName: 'مصطفى راقم',
    lifespan: '1757 - 1826',
    position: Offset(500, 860),
    childrenIds: ['qadi_askar', 'shafiq_bey'],
    isHighlight: true,
  ),

  // --- LATE OTTOMAN & 20TH CENTURY ---
  'qadi_askar': const LineageNode(
    id: 'qadi_askar',
    name: 'Qadi Askar Mustafa Izzet',
    arabicName: 'قاضي عسكر مصطفى عزت',
    lifespan: '1801 - 1876',
    position: Offset(300, 1020),
    childrenIds: ['shawqi_efendi', 'bakkal_arif', 'shafiq_bey'],
  ),
  'shafiq_bey': const LineageNode(
    id: 'shafiq_bey',
    name: 'Mehmed Sefik Bey',
    arabicName: 'محمد شفيق بك',
    lifespan: '1820 - 1880',
    position: Offset(500, 1020),
    childrenIds: ['sami_efendi', 'bakkal_arif'],
  ),
  'shawqi_efendi': const LineageNode(
    id: 'shawqi_efendi',
    name: 'Mehmed Şevki Efendi',
    arabicName: 'محمد شوقي أفندي',
    lifespan: '1829 - 1887',
    position: Offset(700, 1020),
    childrenIds: ['hasan_rida', 'bakkal_arif', 'kamil_akdik'],
    isHighlight: true,
  ),
  
  'bakkal_arif': const LineageNode(
    id: 'bakkal_arif',
    name: 'Bakkal Arif Efendi',
    arabicName: 'بقال عارف أفندي',
    lifespan: '1836 - 1909',
    position: Offset(880, 1140),
    childrenIds: ['sami_efendi'], // Or lateral
  ),
  'sami_efendi': const LineageNode(
    id: 'sami_efendi',
    name: 'Sami Efendi',
    arabicName: 'سامي أفندي',
    lifespan: '1838 - 1912',
    position: Offset(500, 1140),
    childrenIds: ['hasan_rida', 'kamil_akdik', 'nazif_bey', 'okyay', 'halim'],
    isHighlight: true,
  ),

  // Sami's students / Late era
  'hasan_rida': const LineageNode(
    id: 'hasan_rida',
    name: 'Hasan Riza',
    arabicName: 'حسن رضا',
    lifespan: '1849 - 1920',
    position: Offset(200, 1260),
    childrenIds: [],
  ),
  'kamil_akdik': const LineageNode(
    id: 'kamil_akdik',
    name: 'Ahmad Kamil Akdik',
    arabicName: 'أحمد كامل أكديك',
    lifespan: '1861 - 1941',
    position: Offset(400, 1260),
    childrenIds: ['halim'],
  ),
  'nazif_bey': const LineageNode(
    id: 'nazif_bey',
    name: 'Haji Mehmed Nazif Bey',
    arabicName: 'حاجي محمد نظيف بك',
    lifespan: '1846 - 1913',
    position: Offset(600, 1260),
    childrenIds: ['hamid_aytac', 'halim'],
  ),
  'ismail_hakki': const LineageNode(
    id: 'ismail_hakki',
    name: 'Ismail Hakki Altunbezer',
    arabicName: 'إسماعيل حقي ألطونبزر',
    lifespan: '1873 - 1946',
    position: Offset(800, 1260),
    childrenIds: [],
  ),

  'okyay': const LineageNode(
    id: 'okyay',
    name: 'Necmeddin Okyay',
    arabicName: 'نجم الدين أوكياي',
    lifespan: '1883 - 1976',
    position: Offset(200, 1380),
    childrenIds: [],
  ),
  'hamid_aytac': const LineageNode(
    id: 'hamid_aytac',
    name: 'Hamid Aytaç',
    arabicName: 'حامد الآمدي',
    lifespan: '1891 - 1982',
    position: Offset(400, 1380),
    childrenIds: [],
  ),
  'halim': const LineageNode(
    id: 'halim',
    name: 'Halim Özyazıcı',
    arabicName: 'حليم أوزيازجي',
    lifespan: '1898 - 1964',
    position: Offset(600, 1380),
    childrenIds: [],
  ),
};
