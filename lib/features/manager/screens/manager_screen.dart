import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/edit_workspace.dart';
import '../widgets/arrange_workspace.dart';
import '../widgets/artists_workspace.dart';
import '../providers/editor_provider.dart';
import '../providers/manager_providers.dart';
import '../../songs/services/cifra_club_parser.dart';
import '../../songs/repositories/song_repository.dart';

class ManagerScreen extends ConsumerStatefulWidget {
  const ManagerScreen({super.key});

  @override
  ConsumerState<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends ConsumerState<ManagerScreen> {
  bool _collapseMainSidebar = false;

  void _showAddSongDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171f33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.add_circle, color: colors.primary),
              const SizedBox(width: 12),
              const Text('Nova Música', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Como você deseja adicionar a nova música ao seu repertório?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showImportDialog();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.08),
                          border: Border.all(color: colors.primary.withOpacity(0.3), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_fix_high, color: colors.primary, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Importar de Link',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Cifra Club (Mágica)',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
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
                        ref.read(editingChordProProvider.notifier).state = '''{title: Nova Música}
{artist: Artista}
{key: C}
{tempo: 70}

{c: Verse 1}
Coloque sua [C]letra aqui
E os acordes [G]entre colchetes
''';
                        ref.read(isEditorVisibleProvider.notifier).state = true;
                        ref.read(sidebarTabProvider.notifier).setTab(SidebarTab.songs);
                        ref.read(songFilterProvider.notifier).clear();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant.withOpacity(0.05),
                          border: Border.all(color: colors.outline.withOpacity(0.2), width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note, color: colors.onSurfaceVariant, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Criar Manual',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Escrever no Editor',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
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
                              ref.read(songFilterProvider.notifier).clear();
                              
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
          backgroundColor: const Color(0xFF171f33),
          title: const Text('Confirmar Saída', style: TextStyle(color: Colors.white)),
          content: const Text('Deseja realmente sair da sua conta?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              child: const Text('SAIR'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(sidebarTabProvider);
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'Usuário';
    final email = user?.email ?? 'Sem e-mail';
    final photoUrl = user?.photoURL;

    // Auto-collapse sidebar when a song is selected to prioritize screen space
    ref.listen<String?>(selectedSongIdProvider, (previous, next) {
      if (next != null) {
        setState(() {
          _collapseMainSidebar = true;
        });
      }
    });

    // Auto-collapse sidebar when editor becomes visible
    ref.listen<bool>(isEditorVisibleProvider, (previous, next) {
      if (next) {
        setState(() {
          _collapseMainSidebar = true;
        });
      }
    });

    return Scaffold(
      body: Row(
        children: [
          _buildSingleSidebar(context, activeTab, displayName, email, photoUrl),
          Expanded(
            child: _buildMainWorkspace(activeTab),
          ),
        ],
      ),
    );
  }

  Widget _buildMainWorkspace(SidebarTab activeTab) {
    switch (activeTab) {
      case SidebarTab.songs:
      case SidebarTab.favorites:
        return const EditWorkspace();
      case SidebarTab.prepare:
        return const ArrangeWorkspace();
      case SidebarTab.artists:
        return const ArtistsWorkspace();
    }
  }

  Widget _buildSingleSidebar(BuildContext context, SidebarTab activeTab, String displayName, String email, String? photoUrl) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _collapseMainSidebar ? 72 : 280,
      decoration: BoxDecoration(
        color: const Color(0xFF171f33), // surfaceContainer
        border: Border(right: BorderSide(color: colors.outline)),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _collapseMainSidebar ? 72 : 280,
          maxWidth: _collapseMainSidebar ? 72 : 280,
          child: SizedBox(
            width: _collapseMainSidebar ? 72 : 280,
            child: Column(
            children: [
              // App Logo / Title
              Padding(
                padding: EdgeInsets.all(_collapseMainSidebar ? 12.0 : 20.0),
                child: Row(
                  mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    // Logo Badge with Gradient and Glow
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withRed(150), // Subtle gradient shift
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    if (!_collapseMainSidebar) ...[
                      const SizedBox(width: 14),
                      // Styled MusiCifras Text
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                          children: [
                            const TextSpan(
                              text: 'Musi',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'Cifras',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              // User Profile Section wrapped in a clean glass card
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _collapseMainSidebar ? 8.0 : 16.0,
                  vertical: 12.0,
                ),
                child: Container(
                  padding: EdgeInsets.all(_collapseMainSidebar ? 6.0 : 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: _collapseMainSidebar
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      // User Photo / Initials
                      InkWell(
                        onTap: _showLogoutDialog,
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
                              ? Image.network(
                                  photoUrl,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        displayName.isNotEmpty
                                            ? displayName.substring(0, 1).toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colors.onPrimaryContainer,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName.substring(0, 1).toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.onPrimaryContainer,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (!_collapseMainSidebar) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                          tooltip: 'Sair da Conta',
                          onPressed: _showLogoutDialog,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _collapseMainSidebar ? 8.0 : 16.0, vertical: 8.0),
            child: OutlinedButton(
              onPressed: _showAddSongDialog,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              children: [
                _buildSidebarItem(Icons.music_note, 'Músicas', SidebarTab.songs, colors, activeTab),
                _buildSidebarItem(Icons.playlist_play, 'Repertórios', SidebarTab.prepare, colors, activeTab),
                _buildSidebarItem(Icons.person, 'Artistas', SidebarTab.artists, colors, activeTab),
                _buildSidebarItem(Icons.favorite, 'Favoritos', SidebarTab.favorites, colors, activeTab),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildSidebarActionItem(Icons.settings, 'Configurações', colors, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações em breve!'), duration: Duration(seconds: 1)));
                }),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(
                    _collapseMainSidebar ? Icons.chevron_right : Icons.chevron_left,
                    color: colors.onSurfaceVariant,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _collapseMainSidebar = !_collapseMainSidebar;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
  ),
);
}

  Widget _buildSidebarItem(IconData icon, String title, SidebarTab tab, ColorScheme colors, SidebarTab activeTab) {
    final isActive = activeTab == tab;
    return InkWell(
      onTap: () {
        ref.read(sidebarTabProvider.notifier).setTab(tab);
        if (tab == SidebarTab.songs) {
          ref.read(songFilterProvider.notifier).clear();
        } else if (tab == SidebarTab.favorites) {
          ref.read(songFilterProvider.notifier).setOnlyFavorites(true);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: _collapseMainSidebar ? 0 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? colors.secondary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive && !_collapseMainSidebar ? Border(left: BorderSide(color: colors.primary, width: 3)) : null,
        ),
        child: Row(
          mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, color: isActive ? colors.primary : colors.onSurfaceVariant),
            if (!_collapseMainSidebar) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? colors.primary : colors.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarActionItem(IconData icon, String title, ColorScheme colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: _collapseMainSidebar ? 0 : 16, vertical: 12),
        child: Row(
          mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            if (!_collapseMainSidebar) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
