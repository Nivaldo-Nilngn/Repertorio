import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/manager_providers.dart';

class MenuItemData {
  final IconData icon;
  final String title;
  final SidebarTab tab;
  final bool isSpecial;

  const MenuItemData({
    required this.icon,
    required this.title,
    required this.tab,
    this.isSpecial = false,
  });
}

class AppMenu extends ConsumerStatefulWidget {
  final VoidCallback onAddSong;
  final VoidCallback onLogout;

  const AppMenu({
    super.key,
    required this.onAddSong,
    required this.onLogout,
  });

  @override
  ConsumerState<AppMenu> createState() => _AppMenuState();
}

class _AppMenuState extends ConsumerState<AppMenu> {
  bool _collapseMainSidebar = false;

  final List<MenuItemData> _navItems = const [
    MenuItemData(icon: Icons.music_note, title: 'Músicas', tab: SidebarTab.songs),
    MenuItemData(icon: Icons.playlist_play, title: 'Repertórios', tab: SidebarTab.prepare),
    MenuItemData(icon: Icons.person, title: 'Artistas', tab: SidebarTab.artists),
    MenuItemData(icon: Icons.favorite, title: 'Favoritos', tab: SidebarTab.favorites),
  ];

  @override
  Widget build(BuildContext context) {
    final isTopMenu = ref.watch(isTopMenuProvider);
    final colors = Theme.of(context).colorScheme;

    if (isTopMenu) {
      return _buildTopMenu(colors);
    } else {
      return _buildSidebar(colors);
    }
  }

  Widget _buildTopMenu(ColorScheme colors) {
    final activeTab = ref.watch(sidebarTabProvider);
    
    return Container(
      height: 64, // Altura padrão para top navbars
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: colors.outline.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo Section
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'lib/core/assets/kordapp_icon_192x192/screen.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                  children: [
                    TextSpan(text: 'Kord', style: TextStyle(color: colors.onSurface)),
                    TextSpan(text: 'App', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          
          // Navigation Items (Center)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._navItems.map((item) => _buildTopMenuItem(item, colors, activeTab)),
                const SizedBox(width: 16),
                _buildTopMenuItem(const MenuItemData(icon: Icons.settings, title: 'Configurações', tab: SidebarTab.settings), colors, activeTab),
              ],
            ),
          ),

          // Actions Section (Right)
          Row(
            children: [
              FilledButton.icon(
                onPressed: widget.onAddSong,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Música'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary.withOpacity(0.15),
                  foregroundColor: colors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 24),
              _buildUserProfile(colors, isTop: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopMenuItem(MenuItemData item, ColorScheme colors, SidebarTab activeTab) {
    final isActive = activeTab == item.tab;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          ref.read(sidebarTabProvider.notifier).setTab(item.tab);
          if (item.tab == SidebarTab.songs) {
            ref.read(songFilterProvider.notifier).clear();
          } else if (item.tab == SidebarTab.favorites) {
            ref.read(songFilterProvider.notifier).setOnlyFavorites(true);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? colors.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 18, color: isActive ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                item.title,
                style: TextStyle(
                  color: isActive ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(ColorScheme colors) {
    final activeTab = ref.watch(sidebarTabProvider);
    final width = _collapseMainSidebar ? 72.0 : 240.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(right: BorderSide(color: colors.outline.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Row(
                mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'lib/core/assets/kordapp_icon_192x192/screen.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                  if (!_collapseMainSidebar) ...[
                    const SizedBox(width: 14),
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                        children: [
                          TextSpan(text: 'Kord', style: TextStyle(color: colors.onSurface)),
                          TextSpan(text: 'App', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: colors.outline.withOpacity(0.2)),
            
            // Perfil
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _collapseMainSidebar ? 8.0 : 16.0,
                vertical: 12.0,
              ),
              child: Container(
                padding: EdgeInsets.all(_collapseMainSidebar ? 6.0 : 12.0),
                decoration: BoxDecoration(
                  color: colors.onSurface.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.onSurface.withOpacity(0.05)),
                ),
                child: _buildUserProfile(colors, isTop: false),
              ),
            ),
            
            // Botão Adicionar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _collapseMainSidebar ? 8.0 : 16.0, vertical: 8.0),
              child: OutlinedButton(
                onPressed: widget.onAddSong,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.outline.withOpacity(0.5)),
                  padding: _collapseMainSidebar ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _collapseMainSidebar 
                    ? const Icon(Icons.add)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('Adicionar Música'),
                        ],
                      ),
              ),
            ),
            
            // Nav Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                children: _navItems.map((item) => _buildSidebarItem(item, colors, activeTab)).toList(),
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                children: [
                  Divider(height: 1, color: colors.outline.withOpacity(0.2)),
                  const SizedBox(height: 4),
                  _buildSidebarItem(const MenuItemData(icon: Icons.settings, title: 'Configurações', tab: SidebarTab.settings), colors, activeTab),
                  
                  // Collapse Toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _collapseMainSidebar = !_collapseMainSidebar;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 46,
                      padding: EdgeInsets.symmetric(horizontal: _collapseMainSidebar ? 0 : 14),
                      child: Row(
                        mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            _collapseMainSidebar ? Icons.chevron_right : Icons.chevron_left,
                            color: colors.onSurfaceVariant,
                            size: 20,
                          ),
                          if (!_collapseMainSidebar) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Minimizar',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(MenuItemData item, ColorScheme colors, SidebarTab activeTab) {
    final isActive = activeTab == item.tab;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () {
          ref.read(sidebarTabProvider.notifier).setTab(item.tab);
          if (item.tab == SidebarTab.songs) {
            ref.read(songFilterProvider.notifier).clear();
          } else if (item.tab == SidebarTab.favorites) {
            ref.read(songFilterProvider.notifier).setOnlyFavorites(true);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: _collapseMainSidebar ? 0 : 14),
          decoration: BoxDecoration(
            color: isActive ? colors.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive && !_collapseMainSidebar ? Border.all(color: colors.primary.withOpacity(0.35), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(item.icon, size: 20, color: isActive ? colors.primary : colors.onSurfaceVariant),
              if (!_collapseMainSidebar) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: isActive ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(ColorScheme colors, {required bool isTop}) {
    final user = ref.watch(authStateProvider).value;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? '';

    final avatar = InkWell(
      onTap: widget.onLogout,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: photoUrl != null
            ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildAvatarFallback(displayName, colors))
            : _buildAvatarFallback(displayName, colors),
      ),
    );

    if (isTop || _collapseMainSidebar) {
      return avatar;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface, fontSize: 14), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(email, style: TextStyle(color: colors.onSurfaceVariant.withOpacity(0.7), fontSize: 11), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
          tooltip: 'Sair da Conta',
          onPressed: widget.onLogout,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(4),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback(String displayName, ColorScheme colors) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
        style: TextStyle(fontWeight: FontWeight.bold, color: colors.onPrimaryContainer, fontSize: 14),
      ),
    );
  }
}
