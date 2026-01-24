import 'package:flutter/material.dart';
import 'package:hpdaerah/models/user_model.dart';
import 'package:hpdaerah/utils/menu_helper.dart';

/// Reusable Admin Navigator Header
/// Responsive and centered on all devices
class AdminNavigatorHeader extends StatelessWidget {
  final String selectedRoute;
  final ValueChanged<String> onRouteSelected;
  final UserModel user;

  const AdminNavigatorHeader({
    super.key,
    required this.selectedRoute,
    required this.onRouteSelected,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final adminMenus = MenuHelper.getMenus(
      user,
    ).where((m) => m.route.startsWith('/admin')).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: 12,
        horizontal: isTablet ? 24 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 600 : double.infinity,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: adminMenus.asMap().entries.map((entry) {
                final index = entry.key;
                final menu = entry.value;
                final isSelected = selectedRoute == menu.route;

                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 6,
                    right: index == adminMenus.length - 1 ? 0 : 6,
                  ),
                  child: _AdminMenuChip(
                    title: menu.title,
                    icon: menu.icon,
                    color: menu.color,
                    isSelected: isSelected,
                    onTap: () => onRouteSelected(menu.route),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminMenuChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminMenuChip({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF059669)
                : Colors.grey.withOpacity(0.25),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
