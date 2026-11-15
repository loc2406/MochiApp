import '../robot/robot_art_palette.dart';
import '../../design/mochi_design.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../shared/widgets/mochi_assets.dart';
import '../robot/robot_mascot_widget.dart';

class RobotShopScreen extends StatefulWidget {
  const RobotShopScreen({super.key});

  @override
  State<RobotShopScreen> createState() => _RobotShopScreenState();
}

class _RobotShopScreenState extends State<RobotShopScreen> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MochiStore>();
    final catalog = MochiStore.shopCatalog.where((item) {
      if (_selectedCategory == 'all') return true;
      return item.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Robot Shop & Phụ kiện',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: MochiPalette.of(context).card.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MochiPalette.of(context).cardBorder
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: MochiPalette.of(context).warning,
                  size: 18,
                ),
                SizedBox(width: 5),
                Text(
                  '${store.stars}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: MochiPalette.of(context).warning,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Apple OS27 Dark Liquid Showcase Fitting Room
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: PastelPalette.of(context).cardGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                RobotMascotWidget(
                  size: 115,
                  emotion: store.robotEmotion,
                  primaryColor: Color(store.robotColorHex),
                  equippedAccessory: store.equippedAccessory,
                  equippedClothes: store.equippedClothes,
                  equippedSpecial: store.equippedSpecial,
                ),
                SizedBox(height: 8),
                Text(
                  store.profile.robotName,
                  style: TextStyle(
                    color: MochiPalette.of(context).ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Chuỗi hiện tại: ${store.currentStreak} ngày liên tục',
                  style: TextStyle(
                    color: MochiPalette.of(context).muted,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 10),
                // Color Picker Row with Apple Haptic
                Wrap(
                  spacing: 8,
                  children: RobotArtPalette.colors.map((c) {
                    final isSelected = store.robotColorHex == c.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        store.changeRobotColor(c.toARGB32());
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? MochiPalette.of(context).cardBorder
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Category Filters (Apple OS27 Segmented Chips)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: MochiPalette.of(context).card,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'Tất cả'),
                  _buildCategoryChip('accessory', 'Phụ kiện'),
                  _buildCategoryChip('clothes', 'Trang phục'),
                  _buildCategoryChip('special', 'Đặc biệt'),
                ],
              ),
            ),
          ),

          // Catalog Grid - Responsive layoutBuilder with dynamic aspect ratio
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Adaptive aspect ratio prevents overflow on 360dp width screens
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = constraints.maxWidth < 380 && scale > 1.3
                    ? 1
                    : (constraints.maxWidth / 210).floor().clamp(2, 5);
                final itemWidth =
                    (constraints.maxWidth - 32 - (columns - 1) * 12) / columns;

                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    90,
                  ), // Space for floating glass bar
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent:
                        (itemWidth / .78).clamp(240.0, 340.0) +
                        (scale - 1) * 120,
                  ),
                  itemCount: catalog.length,
                  itemBuilder: (context, index) {
                    final item = catalog[index];
                    final isOwned = store.ownedItems.contains(item.id);
                    final isEquipped =
                        store.equippedAccessory == item.id ||
                        store.equippedClothes == item.id ||
                        store.equippedSpecial == item.id;
                    final canUnlock =
                        store.currentStreak >= item.requiredStreak;

                    return MochiCard(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          MochiShopAsset(itemId: item.assetId, size: 54),
                          SizedBox(height: 6),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: MochiPalette.of(context).ink,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            item.desc,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: MochiPalette.of(context).muted,
                              height: 1.25,
                            ),
                          ),
                          Spacer(),
                          if (!canUnlock)
                            Text(
                              'Cần chuỗi ${item.requiredStreak} ngày',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MochiPalette.of(context).danger,
                              ),
                            )
                          else if (!isOwned)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: MochiPalette.of(context).warning,
                                  size: 14,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '${item.price}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: MochiPalette.of(context).ink,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: isOwned
                                ? OutlinedButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      store.equipItem(item.id, item.category);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isEquipped
                                          ? MochiPalette.of(context).danger
                                          : MochiPalette.of(context).action,
                                      side: BorderSide(
                                        color: isEquipped
                                            ? MochiPalette.of(context).danger
                                            : MochiPalette.of(context).action,
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                    ),
                                    child: Text(
                                      isEquipped ? 'Tháo ra' : 'Mặc ngay',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                : MochiPrimaryButton(
                                    onPressed:
                                        (!canUnlock || store.stars < item.price)
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            final success = store.buyItem(item);
                                            if (success) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Đã mở khóa ${item.name}!',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MochiPalette.of(context)
                                          .accent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      item.price == 0 ? 'Nhận quà' : 'Mua',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: MochiPalette.of(context)
                                            .onAccent,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String cat, String label) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: MochiPalette.of(context).action,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: TextStyle(
          color: isSelected
              ? MochiPalette.of(context).ink
              : MochiPalette.of(context).ink,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        onSelected: (val) {
          if (val) {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = cat);
          }
        },
      ),
    );
  }
}
