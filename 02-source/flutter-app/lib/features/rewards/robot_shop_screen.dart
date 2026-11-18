import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/mochi_store.dart';
import '../../core/models/mochi_models.dart';
import '../../design/mochi_design.dart';
import '../../shared/widgets/floating_bar_inset.dart';
import '../../shared/widgets/mochi_assets.dart';
import '../robot/robot_art_palette.dart';
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
    final catalog = MochiStore.shopCatalog
        .where(
          (item) =>
              _selectedCategory == 'all' ||
              item.category == _selectedCategory,
        )
        .toList();
    final palette = MochiPalette.of(context);

    return MochiScaffold(
      appBar: MochiAppBar(
        title: 'Cửa hàng Mochi',
        subtitle: 'Phụ kiện và trang phục cho bạn đồng hành',
        large: true,
        actions: [
          MochiChip(
            label: '${store.stars}',
            icon: Icons.star_rounded,
            tone: MochiChipTone.warning,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _buildShowcase(context, store, constraints.maxWidth),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCategoryFilters(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, gridConstraints) {
                    final width = gridConstraints.maxWidth;
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final columns = width < 360
                        ? 1
                        : width < 680
                        ? 2
                        : (width / 220).floor().clamp(3, 5).toInt();
                    final itemWidth =
                        (width - 32 - (columns - 1) * 12) / columns;
                    final itemHeight =
                        (width < 680 ? 286.0 : 300.0) +
                        ((textScale - 1).clamp(0.0, 1.0).toDouble() * 90);

                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        2,
                        16,
                        FloatingBarInset.of(context) + 16,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: itemHeight,
                      ),
                      itemCount: catalog.length,
                      itemBuilder: (context, index) => _buildShopItem(
                        context,
                        store,
                        catalog[index],
                        itemWidth,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShowcase(
    BuildContext context,
    MochiStore store,
    double availableWidth,
  ) {
    final palette = MochiPalette.of(context);
    final compact = availableWidth < 600;
    final mascot = RobotMascotWidget(
      size: compact ? 104.0 : 120.0,
      emotion: store.robotEmotion,
      primaryColor: Color(store.robotColorHex),
      equippedAccessory: store.equippedAccessory,
      equippedClothes: store.equippedClothes,
      equippedSpecial: store.equippedSpecial,
    );
    final details = Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          store.profile.robotName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: palette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        MochiChip(
          label: 'Chuỗi hiện tại: ${store.currentStreak} ngày',
          icon: Icons.local_fire_department_rounded,
          tone: MochiChipTone.warning,
          compact: true,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final color in RobotArtPalette.colors)
              _buildColorOption(context, store, color),
          ],
        ),
      ],
    );

    return MochiCard(
      padding: EdgeInsets.all(compact ? 14 : 20),
      color: palette.cardSoft,
      child: compact
          ? Column(
              children: [
                mascot,
                const SizedBox(height: 8),
                details,
              ],
            )
          : Row(
              children: [
                mascot,
                const SizedBox(width: 24),
                Expanded(child: details),
              ],
            ),
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    MochiStore store,
    Color color,
  ) {
    final palette = MochiPalette.of(context);
    final selected = store.robotColorHex == color.toARGB32();
    return Semantics(
      button: true,
      selected: selected,
      label: 'Màu robot ${color.toARGB32().toRadixString(16)}',
      child: Tooltip(
        message: 'Đổi màu robot',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            store.changeRobotColor(color.toARGB32());
          },
          child: AnimatedContainer(
            duration: MochiMotion.of(context, MochiMotion.quick),
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? palette.action : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        _buildCategoryChip('all', 'Tất cả'),
        _buildCategoryChip('accessory', 'Phụ kiện'),
        _buildCategoryChip('clothes', 'Trang phục'),
        _buildCategoryChip('special', 'Đặc biệt'),
      ],
    ),
  );

  Widget _buildCategoryChip(String category, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: MochiFilterChip(
      label: label,
      selected: _selectedCategory == category,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = category);
      },
    ),
  );

  Widget _buildShopItem(
    BuildContext context,
    MochiStore store,
    ShopItem item,
    double itemWidth,
  ) {
    final palette = MochiPalette.of(context);
    final isOwned = store.ownedItems.contains(item.id);
    final isEquipped =
        store.equippedAccessory == item.id ||
        store.equippedClothes == item.id ||
        store.equippedSpecial == item.id;
    final canUnlock = store.currentStreak >= item.requiredStreak;
    final imageSize = (itemWidth * 0.36).clamp(52.0, 68.0).toDouble();

    return MochiCard(
      padding: const EdgeInsets.all(12),
      semanticLabel: item.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MochiShopAsset(itemId: item.assetId, size: imageSize),
          const SizedBox(height: 6),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.desc,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: palette.muted,
              height: 1.25,
            ),
          ),
          const Spacer(),
          if (!canUnlock)
            MochiChip(
              label: 'Chuỗi ${item.requiredStreak} ngày',
              icon: Icons.lock_outline_rounded,
              tone: MochiChipTone.danger,
              compact: true,
            )
          else if (isOwned)
            MochiChip(
              label: isEquipped ? 'Đang mặc' : 'Đã sở hữu',
              icon: isEquipped ? Icons.check_circle_outline : Icons.inventory_2_outlined,
              tone: MochiChipTone.success,
              compact: true,
            )
          else
            MochiChip(
              label: '${item.price}',
              icon: Icons.star_rounded,
              tone: MochiChipTone.warning,
              compact: true,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: isOwned
                ? MochiButton(
                    label: isEquipped ? 'Tháo ra' : 'Mặc ngay',
                    icon: isEquipped ? Icons.checkroom_outlined : Icons.style_outlined,
                    variant: isEquipped
                        ? MochiButtonVariant.danger
                        : MochiButtonVariant.secondary,
                    size: MochiButtonSize.small,
                    expand: true,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      store.equipItem(item.id, item.category);
                    },
                  )
                : MochiButton(
                    label: item.price == 0 ? 'Nhận quà' : 'Mua',
                    icon: item.price == 0
                        ? Icons.card_giftcard_rounded
                        : Icons.shopping_bag_outlined,
                    size: MochiButtonSize.small,
                    expand: true,
                    onPressed: (!canUnlock || store.stars < item.price)
                        ? null
                        : () => _buyItem(context, store, item),
                  ),
          ),
        ],
      ),
    );
  }

  void _buyItem(BuildContext context, MochiStore store, ShopItem item) {
    HapticFeedback.mediumImpact();
    if (store.buyItem(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Đã mở khóa ${item.name}!'),
        ),
      );
    }
  }
}
