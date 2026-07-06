import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          backgroundColor: colors.surface,
          title: const Text('Adicionar Música'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.auto_fix_high, color: colors.primary),
                title: const Text('Importar do Cifra Club (Mágica)'),
                subtitle: const Text('Cole a URL da cifra para converter automaticamente'),
                onTap: () {
                  Navigator.pop(context);
                  _showImportDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.edit_note, color: colors.primary),
                title: const Text('Criar Manualmente'),
                subtitle: const Text('Escreva sua própria cifra no editor'),
                onTap: () {
                  Navigator.pop(context);
                  // Reset editor state
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
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
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

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(sidebarTabProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildTopNavBar(context),
          Expanded(
            child: Row(
              children: [
                _buildSingleSidebar(context, activeTab),
                Expanded(
                  child: _buildMainWorkspace(activeTab),
                ),
              ],
            ),
          ),
          _buildBottomFooter(context),
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

  Widget _buildTopNavBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'SongbookPro Manager',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.share), color: colors.onSurfaceVariant, onPressed: () {}),
              IconButton(icon: const Icon(Icons.fullscreen), color: colors.onSurfaceVariant, onPressed: () {}),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.print, size: 18),
                label: const Text('ENVIAR'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('MÁGICA'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.surfaceContainerHighest,
                child: const Icon(Icons.person, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSidebar(BuildContext context, SidebarTab activeTab) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _collapseMainSidebar ? 72 : 280,
      decoration: BoxDecoration(
        color: const Color(0xFF171f33), // surfaceContainer
        border: Border(right: BorderSide(color: colors.outline)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(_collapseMainSidebar ? 8.0 : 16.0),
            child: Row(
              mainAxisAlignment: _collapseMainSidebar ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _collapseMainSidebar = !_collapseMainSidebar),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: _collapseMainSidebar
                        ? const Icon(Icons.menu, size: 20)
                        : const Text('MC', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (!_collapseMainSidebar) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MusiCifras', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text('Gerenciador', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu_open, size: 20),
                    onPressed: () => setState(() => _collapseMainSidebar = true),
                    color: colors.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
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
                _buildSidebarActionItem(Icons.settings, 'Configurações', colors),
                _buildSidebarActionItem(Icons.account_circle, 'Conta', colors),
              ],
            ),
          ),
        ],
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

  Widget _buildSidebarActionItem(IconData icon, String title, ColorScheme colors) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title em breve!'), duration: const Duration(seconds: 1)));
      },
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

  Widget _buildBottomFooter(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: colors.surfaceContainerHigh,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: colors.secondary, size: 10),
              const SizedBox(width: 8),
              Text('SYNC ATIVO', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 16),
              Container(width: 1, height: 16, color: colors.outline),
              const SizedBox(width: 16),
              Text('TOM: ORIGINAL', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 16),
              Text('ROLANDO: OFF', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          Row(
            children: const [],
          ),
        ],
      ),
    );
  }
}
