import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/providers/auth_provider.dart';
import '../../songs/repositories/song_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/settings_provider.dart';
import '../../../core/theme/widgets/theme_builder_modal.dart';
import '../../midi/widgets/midi_settings_panel.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/manager_providers.dart';

class SettingsWorkspace extends ConsumerStatefulWidget {
  const SettingsWorkspace({super.key});

  @override
  ConsumerState<SettingsWorkspace> createState() => _SettingsWorkspaceState();
}

class _SettingsWorkspaceState extends ConsumerState<SettingsWorkspace> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colors.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMobileMenuItem(0, Icons.palette, 'Geral', colors),
                _buildMobileMenuItem(1, Icons.piano, 'MIDI', colors),
                _buildMobileMenuItem(2, Icons.person, 'Conta', colors),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outline.withOpacity(0.2)),
          Expanded(
            child: Container(
              color: colors.surface,
              child: _buildContent(),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Menu Interno
        Container(
          width: 250,
          color: colors.surfaceContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Configurações',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              _buildMenuItem(0, Icons.palette, 'Geral'),
              _buildMenuItem(1, Icons.piano, 'MIDI'),
              _buildMenuItem(2, Icons.person, 'Conta'),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: colors.outline.withOpacity(0.2)),
        // Conteúdo
        Expanded(
          child: Container(
            color: colors.surface,
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileMenuItem(int index, IconData icon, String title, ColorScheme colors) {
    final isActive = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? colors.onPrimary : colors.onSurfaceVariant),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isActive = _selectedIndex == index;
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        color: isActive ? colors.primary.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? colors.primary : colors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? colors.primary : colors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildGeralTab();
      case 1:
        return const MidiSettingsPanel();
      case 2:
        return _buildContaTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildGeralTab() {
    final colors = Theme.of(context).colorScheme;
    final currentTheme = ref.watch(appThemeProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isWideScreen = MediaQuery.of(context).size.width >= 1000;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aparência',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personalize as cores e a tipografia do seu aplicativo.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Row(
                  children: [
                    const Text('Menu no Topo (Navbar)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Switch(
                      value: ref.watch(isTopMenuProvider),
                      onChanged: (val) => ref.read(isTopMenuProvider.notifier).toggle(),
                      activeColor: colors.primary,
                    ),
                  ],
                ),
            ],
          ),
          
          if (isMobile) ...[
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Menu no Topo (Navbar)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Alterna entre o menu lateral clássico e o menu no topo da tela.'),
              value: ref.watch(isTopMenuProvider),
              onChanged: (val) => ref.read(isTopMenuProvider.notifier).toggle(),
              activeColor: colors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
          
          const SizedBox(height: 32),
          
          if (!isWideScreen) ...[
            Text('Temas Clássicos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface)),
            const SizedBox(height: 12),
            _buildThemeList([
              _buildThemeOption(AppThemeType.managerDark, currentTheme),
              _buildThemeOption(AppThemeType.managerLight, currentTheme),
              _buildCustomThemeOption(currentTheme),
            ], isMobile),
            const SizedBox(height: 24),
            Text('Combos Cafeteria (Premium)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface)),
            const SizedBox(height: 12),
            _buildThemeList([
              _buildThemeOption(AppThemeType.cafeteriaModerna, currentTheme),
              _buildThemeOption(AppThemeType.graoGourmet, currentTheme),
              _buildThemeOption(AppThemeType.bistroVintage, currentTheme),
            ], isMobile),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temas Clássicos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface)),
                      const SizedBox(height: 12),
                      _buildThemeList([
                        _buildThemeOption(AppThemeType.managerDark, currentTheme),
                        _buildThemeOption(AppThemeType.managerLight, currentTheme),
                        _buildCustomThemeOption(currentTheme),
                      ], isMobile),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Combos Cafeteria (Premium)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface)),
                      const SizedBox(height: 12),
                      _buildThemeList([
                        _buildThemeOption(AppThemeType.cafeteriaModerna, currentTheme),
                        _buildThemeOption(AppThemeType.graoGourmet, currentTheme),
                        _buildThemeOption(AppThemeType.bistroVintage, currentTheme),
                      ], isMobile),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 32),
          Divider(color: colors.outline.withOpacity(0.2)),
          const SizedBox(height: 24),

          Text(
            'Opções do Leitor (Palco)',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configurações persistentes para facilitar a leitura durante apresentações.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          _buildSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildThemeList(List<Widget> options, bool isMobile) {
    if (isMobile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: options.map((opt) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: opt))).toList(),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((opt) => Padding(padding: const EdgeInsets.only(bottom: 12), child: opt)).toList(),
      );
    }
  }

  Widget _buildSettingsCard() {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final isMobile = MediaQuery.of(context).size.width < 800; // Use a slightly larger breakpoint for the card to avoid cramped row

    final List<String> availableFonts = [
      'Inter', 'Roboto Mono', 'Fira Code', 'Poppins', 'Playfair Display', 'Arvo', 'Segoe UI', 'Consolas'
    ];
    String selectedFont = settings.fontFamily ?? 'Inter';
    if (!availableFonts.contains(selectedFont)) {
      selectedFont = 'Inter';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline.withOpacity(0.2)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFontFamilySelector(colors, selectedFont, availableFonts, settingsNotifier)),
                    const SizedBox(width: 32),
                    Expanded(child: _buildFontSizeSelector(colors, settings, settingsNotifier)),
                  ],
                ),
                const SizedBox(height: 32),
                Text('Preview no Palco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.onSurfaceVariant)),
                const SizedBox(height: 12),
                _buildPreviewBox(colors, settings, selectedFont),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFontFamilySelector(colors, selectedFont, availableFonts, settingsNotifier),
                      const SizedBox(height: 32),
                      _buildFontSizeSelector(colors, settings, settingsNotifier),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preview no Palco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      _buildPreviewBox(colors, settings, selectedFont),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPreviewBox(ColorScheme colors, dynamic settings, String selectedFont) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Am7   D9',
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: settings.defaultFontSize,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exemplo de como ficará a música',
            style: TextStyle(
              fontFamily: selectedFont,
              color: colors.primary,
              fontStyle: FontStyle.italic,
              fontSize: settings.defaultFontSize - 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontFamilySelector(ColorScheme colors, String selectedFont, List<String> availableFonts, dynamic settingsNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.font_download, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Família de Fonte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Altere a fonte', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedFont,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          dropdownColor: colors.surfaceContainerHigh,
          items: availableFonts.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (val) {
            if (val != null) settingsNotifier.setFontFamily(val);
          },
        ),
      ],
    );
  }

  Widget _buildFontSizeSelector(ColorScheme colors, dynamic settings, dynamic settingsNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.text_increase, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tamanho Padrão', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Ajuste o zoom', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            Text('${settings.defaultFontSize.toInt()}px', style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: settings.defaultFontSize,
          min: 14.0,
          max: 48.0,
          divisions: 17,
          onChanged: (value) {
            settingsNotifier.setFontSize(value);
          },
        ),
      ],
    );
  }

  Widget _buildCustomThemeOption(AppThemeType currentType) {
    final isActive = currentType == AppThemeType.custom;
    final settings = ref.watch(settingsProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    Color primaryColor = Colors.blueGrey;
    if (settings.customThemeColorHex != null) {
      try {
        primaryColor = Color(int.parse(settings.customThemeColorHex!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final themeData = AppTheme.resolveWithCustomSettings(
      AppThemeType.custom, 
      primaryHex: settings.customThemeColorHex,
      bgHex: settings.customBgColorHex,
      textHex: settings.customTextColorHex,
      fontFamily: settings.fontFamily,
    );
    return InkWell(
      onTap: () {
        if (!isActive) {
          ref.read(appThemeProvider.notifier).setTheme(AppThemeType.custom);
        } else {
          if (isMobile) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeBuilderModal()));
          } else {
            showDialog(
              context: context,
              builder: (context) => const ThemeBuilderModal(),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isMobile ? (MediaQuery.of(context).size.width - 60) / 3 : null,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeData.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? themeData.colorScheme.primary : themeData.colorScheme.outline.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: themeData.colorScheme.primary.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: isMobile 
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildColorPalette(themeData, compact: true),
                const SizedBox(height: 8),
                Text(
                  'Personalizado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: themeData.colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: isActive,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          if (isMobile) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeBuilderModal()));
                          } else {
                            showDialog(
                              context: context,
                              builder: (context) => const ThemeBuilderModal(),
                            );
                          }
                        },
                        child: Icon(Icons.palette, size: 16, color: themeData.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _buildColorPalette(themeData),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    'Tema Personalizado',
                    style: TextStyle(
                      color: themeData.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: isActive,
                  child: IconButton(
                    tooltip: 'Editar Cores',
                    onPressed: () {
                      if (isMobile) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeBuilderModal()));
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => const ThemeBuilderModal(),
                        );
                      }
                    },
                    icon: const Icon(Icons.palette, size: 20),
                    color: themeData.colorScheme.primary,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildThemeOption(AppThemeType type, AppThemeType currentType) {
    final isActive = type == currentType;
    final themeData = AppTheme.resolve(type);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return InkWell(
      onTap: () {
        ref.read(appThemeProvider.notifier).setTheme(type);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isMobile ? null : null, // Removed fixed width, controlled by parent layout
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeData.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? themeData.colorScheme.primary : themeData.colorScheme.outline.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: themeData.colorScheme.primary.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: isMobile 
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildColorPalette(themeData, compact: true),
                const SizedBox(height: 8),
                Text(
                  type.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: themeData.colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: isActive,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      Icon(Icons.check_circle, size: 16, color: themeData.colorScheme.primary),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _buildColorPalette(themeData),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      color: themeData.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: isActive,
                  child: Icon(Icons.check_circle, color: themeData.colorScheme.primary),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildColorPalette(ThemeData theme, {bool compact = false}) {
    final double size = compact ? 20.0 : 28.0;
    return SizedBox(
      width: compact ? 44 : 60,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _buildColorCircle(theme.colorScheme.primary, size, zIndex: 1),
          ),
          Positioned(
            left: compact ? 12 : 16,
            child: _buildColorCircle(theme.colorScheme.surfaceContainerHighest, size, zIndex: 2),
          ),
          Positioned(
            left: compact ? 24 : 32,
            child: _buildColorCircle(theme.colorScheme.onSurface, size, zIndex: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color color, double size, {required int zIndex}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ]
      ),
    );
  }

  Widget _buildContaTab() {
    final colors = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).value;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'Usuário';
    final isMobile = MediaQuery.of(context).size.width < 600;

    final songs = ref.watch(songListProvider).value ?? [];
    final setlists = ref.watch(setlistListProvider).value ?? [];
    
    final artistSet = <String>{};
    for (var s in songs) {
      if (s.artist.isNotEmpty) artistSet.add(s.artist);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sua Conta',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gerencie suas credenciais e seus dados armazenados.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          
          // Card de Perfil Premium
          Container(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceContainerHigh,
                  colors.surfaceContainerLow,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outline.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primary.withOpacity(0.5), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: colors.primaryContainer,
                        backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                        child: user?.photoURL == null
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colors.primary),
                              )
                            : null,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Função de trocar foto em breve!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surfaceContainer, width: 2),
                        ),
                        child: Icon(Icons.camera_alt, size: 16, color: colors.onPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orangeAccent]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('PRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user?.email ?? 'Sem e-mail vinculado',
                        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildStatItem('Músicas', songs.length.toString(), Icons.music_note, colors),
                    _buildStatItem('Repertórios', setlists.length.toString(), Icons.queue_music, colors),
                    _buildStatItem('Artistas', artistSet.length.toString(), Icons.mic, colors),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Função de alterar senha em breve!')),
                      );
                    },
                    icon: const Icon(Icons.password, size: 18),
                    label: const Text('Alterar Senha'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => ref.read(firebaseAuthProvider).signOut(),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sair da Conta'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error.withOpacity(0.1),
                      foregroundColor: colors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 48),
          
          // Zona de Perigo
          Text(
            'Zona de Perigo',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildDangerOption(
                  'Limpar Cache Local',
                  'Apaga arquivos temporários salvos no seu dispositivo. Nenhuma música ou repertório será perdido do banco de dados.',
                  'LIMPAR CACHE',
                  Icons.cleaning_services,
                  () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.surface,
                        title: const Text('Limpar Cache?'),
                        content: const Text('Isto apagará apenas configurações temporárias no seu aparelho.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LIMPAR')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cache limpo com sucesso!')),
                      );
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.redAccent.withOpacity(0.2)),
                ),
                _buildDangerOption(
                  'Apagar Tudo (Banco de Dados)',
                  'Esta ação é irreversível. Todas as suas músicas, artistas e repertórios salvos na nuvem serão excluídos permanentemente.',
                  'APAGAR TUDO',
                  Icons.delete_forever,
                  () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.surface,
                        title: const Text('Apagar todo o Banco de Dados?', style: TextStyle(color: Colors.redAccent)),
                        content: const Text('ATENÇÃO: Você perderá TODAS as músicas, pastas e repertórios criados. Esta ação não pode ser desfeita. Tem certeza?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.white70))),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('SIM, APAGAR TUDO'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ref.read(songRepositoryProvider).deleteAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Banco de dados apagado!'), backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerOption(String title, String description, String buttonText, IconData icon, VoidCallback onPressed, {bool isDestructive = false}) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
      ],
    );

    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(buttonText),
      style: FilledButton.styleFrom(
        backgroundColor: isDestructive ? Colors.red : colors.surfaceContainerHighest,
        foregroundColor: isDestructive ? Colors.white : colors.onSurface,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        const SizedBox(height: 16),
        button,
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: colors.primary.withOpacity(0.8), size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
      ],
    );
  }
}
