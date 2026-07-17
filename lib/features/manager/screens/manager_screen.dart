import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../widgets/songs_workspace.dart';
import '../widgets/editor_workspace.dart';
import '../widgets/arrange_workspace.dart';
import '../widgets/artists_workspace.dart';
import '../widgets/settings_workspace.dart';
import '../providers/editor_provider.dart';
import '../providers/manager_providers.dart';
import '../../songs/services/cifra_club_parser.dart';
import '../../songs/repositories/song_repository.dart';
import '../../songs/models/song_setlist.dart';
import '../../midi/widgets/midi_settings_dialog.dart';
import '../../../core/theme/theme_provider.dart';
import '../widgets/app_menu.dart';

class ManagerScreen extends ConsumerStatefulWidget {
  const ManagerScreen({super.key});

  @override
  ConsumerState<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends ConsumerState<ManagerScreen> {
  void _showAddSongDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.outline.withOpacity(0.1)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.music_note, color: colors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Nova Música',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Como você deseja adicionar essa música ao seu repertório?',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showImportDialog();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.primary.withOpacity(0.15), colors.primary.withOpacity(0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: colors.primary.withOpacity(0.4), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_fix_high, color: colors.primary, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              'Importar de Link',
                              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cifra Club (Mágica)',
                              style: TextStyle(color: colors.primary.withOpacity(0.7), fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(selectedSongIdProvider.notifier).select(null);
                        final filter = ref.read(songFilterProvider);
                        final initialArtist = filter.artist ?? 'Artista';
                        ref.read(editingChordProProvider.notifier).state = '''{title: Nova Música}
{artist: $initialArtist}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
                        ref.read(isEditorVisibleProvider.notifier).state = true;
                        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
                        ref.read(songFilterProvider.notifier).clearExceptFolder();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          border: Border.all(color: colors.outline.withOpacity(0.2), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note, color: colors.onSurfaceVariant, size: 40),
                            const SizedBox(height: 16),
                            Text(
                              'Criar Manual',
                              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Escrever no Editor',
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog() {
    final urlController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Importar do Cifra Club'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cole a URL do Cifra Club abaixo para converter magicamente!'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: 'https://www.cifraclub.com.br/...',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty) return;

                          setDialogState(() => isLoading = true);

                          try {
                            final chordPro = await CifraClubParser.fetchAndParse(url);
                            
                            // Update editor state
                            ref.read(selectedSongIdProvider.notifier).select(null);
                            ref.read(editingChordProProvider.notifier).state = chordPro;
                            ref.read(isEditorVisibleProvider.notifier).state = true;
                            
                            if (mounted) {
                              Navigator.pop(context);
                              // Switch to songs tab and clear filters
                              ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
                              ref.read(songFilterProvider.notifier).clearExceptFolder();
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Importado com sucesso!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: const Text('IMPORTAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: Text('Confirmar Saída', style: TextStyle(color: colors.onSurface)),
          content: Text('Deseja realmente sair da sua conta?', style: TextStyle(color: colors.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCELAR', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: const Text('SAIR'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final setlistsAsync = ref.watch(setlistListProvider);
    if (setlistsAsync.value != null && setlistsAsync.value!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(songFilterProvider.notifier).initializeWithUpcoming(setlistsAsync.value!);
      });
    }

    final activeTab = ref.watch(sidebarTabProvider);
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName ?? 'Usuário';
    final photoUrl = user?.photoURL;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return _buildMobileLayout(context, activeTab, displayName, photoUrl, ref);
        } else {
          return _buildDesktopLayout(context, activeTab, displayName, user?.email ?? '', photoUrl, ref);
        }
      },
    );
  }

  Widget _buildOfflineBanner(bool isOffline, ColorScheme colors) {
    if (!isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.redAccent.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Text(
        '☁ Você está offline. Exibindo músicas salvas no dispositivo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─── MOBILE LAYOUT ───────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, SidebarTab activeTab, String displayName, String? photoUrl, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: _buildMobileAppBar(context, activeTab, displayName, photoUrl, colors),
      body: Column(
        children: [
          _buildOfflineBanner(ref.watch(isOfflineProvider), colors),
          Expanded(child: _buildMainWorkspace(activeTab, ref)),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(activeTab, colors),
      floatingActionButton: _buildFAB(activeTab, colors),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    SidebarTab activeTab,
    String displayName,
    String? photoUrl,
    ColorScheme colors,
  ) {
    final tabTitles = {
      SidebarTab.songs: 'Músicas',
      SidebarTab.prepare: 'Repertórios',
      SidebarTab.artists: 'Artistas',
      SidebarTab.favorites: 'Favoritos',
    };

    return AppBar(
      backgroundColor: colors.surfaceContainer,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'lib/core/assets/kordapp_icon_192x192/screen.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              children: [
                TextSpan(text: 'Kord', style: TextStyle(color: colors.onSurface)),
                TextSpan(text: 'App', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      actions: [

        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          color: colors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'settings') {
              ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.settings);
            } else if (value == 'logout') {
              _showLogoutDialog();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20, color: colors.onSurface),
                  const SizedBox(width: 12),
                  Text('Configurações', style: TextStyle(color: colors.onSurface)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: colors.error),
                  const SizedBox(width: 12),
                  Text('Sair', style: TextStyle(color: colors.error)),
                ],
              ),
            ),
          ],
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colors.primaryContainer,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              onBackgroundImageError: photoUrl != null ? (_, __) {} : null,
              child: photoUrl == null
                  ? Text(
                      displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(SidebarTab activeTab, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.outline.withOpacity(0.3))),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceVariant,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        type: BottomNavigationBarType.fixed,
        currentIndex: _tabToIndex(activeTab),
        onTap: (index) => _onBottomNavTap(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Músicas'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_play), label: 'Repertórios'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Artistas'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoritos'),
        ],
      ),
    );
  }

  Widget _buildFAB(SidebarTab activeTab, ColorScheme colors) {
    // Only show FAB on songs/favorites tabs (where adding a song makes sense)
    if (activeTab != SidebarTab.songs && activeTab != SidebarTab.favorites) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      onPressed: _showAddSongDialog,
      backgroundColor: colors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      child: const Icon(Icons.add),
    );
  }

  int _tabToIndex(SidebarTab tab) {
    switch (tab) {
      case SidebarTab.songs:
        return 0;
      case SidebarTab.prepare:
        return 1;
      case SidebarTab.artists:
        return 2;
      case SidebarTab.favorites:
        return 3;
      case SidebarTab.settings:
        return 0; // TODO: Settings is not in bottom nav yet
    }
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
        ref.read(songFilterProvider.notifier).clear();
        break;
      case 1:
        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.prepare);
        break;
      case 2:
        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.artists);
        break;
      case 3:
        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.favorites);
        ref.read(songFilterProvider.notifier).setOnlyFavorites(true);
        break;
    }
  }

  // ─── DESKTOP LAYOUT ──────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context, SidebarTab activeTab, String displayName, String email, String? photoUrl, WidgetRef ref) {
    final isTopMenu = ref.watch(isTopMenuProvider);
    final appMenu = AppMenu(
      onAddSong: _showAddSongDialog,
      onLogout: _showLogoutDialog,
      isTopMenu: isTopMenu,
    );
    final workspace = Expanded(child: _buildMainWorkspace(activeTab, ref));

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: Column(
          children: [
            _buildOfflineBanner(ref.watch(isOfflineProvider), Theme.of(context).colorScheme),
            Expanded(
              child: isTopMenu
                  ? SizedBox.expand(key: const ValueKey('topMenuLayout'), child: Column(children: [appMenu, workspace]))
                  : SizedBox.expand(key: const ValueKey('sidebarLayout'), child: Row(children: [appMenu, workspace])),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED ──────────────────────────────────────────────────────────────────

  Widget _buildMainWorkspace(SidebarTab activeTab, WidgetRef ref) {
    final isEditorVisible = ref.watch(isEditorVisibleProvider);
    if (isEditorVisible) {
      return const EditorWorkspace();
    }

    switch (activeTab) {
      case SidebarTab.songs:
      case SidebarTab.favorites:
        return const SongsWorkspace();
      case SidebarTab.prepare:
        return const ArrangeWorkspace();
      case SidebarTab.artists:
        return const ArtistsWorkspace();
      case SidebarTab.settings:
        return const SettingsWorkspace();
    }
  }

  // O widget AppMenu agora cuida de toda a renderização do Menu (Topo ou Lateral)
}
