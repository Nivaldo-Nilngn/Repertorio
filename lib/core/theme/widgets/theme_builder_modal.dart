import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../settings_provider.dart';
import '../app_theme.dart';

class ThemeBuilderModal extends ConsumerStatefulWidget {
  const ThemeBuilderModal({super.key});

  @override
  ConsumerState<ThemeBuilderModal> createState() => _ThemeBuilderModalState();
}

class _ThemeBuilderModalState extends ConsumerState<ThemeBuilderModal> {
  static List<Color> _recentColors = []; // Banco de cores recentes em memória

  late Color primaryColor;
  late Color bgColor;
  late Color textColor;
  late Color chordColor;
  late Color lyricColor;
  late String selectedFont;
  late double fontSize;

  final List<String> availableFonts = [
    'Inter',
    'Roboto Mono',
    'Fira Code',
    'Poppins',
    'Playfair Display',
    'Arvo',
    'Segoe UI',
    'Consolas',
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    
    primaryColor = Colors.blueGrey;
    if (settings.customThemeColorHex != null) {
      try { primaryColor = Color(int.parse(settings.customThemeColorHex!.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    bgColor = const Color(0xFF121212);
    if (settings.customBgColorHex != null) {
      try { bgColor = Color(int.parse(settings.customBgColorHex!.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    textColor = Colors.white;
    if (settings.customTextColorHex != null) {
      try { textColor = Color(int.parse(settings.customTextColorHex!.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    chordColor = Colors.white;
    if (settings.customChordColorHex != null) {
      try { chordColor = Color(int.parse(settings.customChordColorHex!.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    lyricColor = primaryColor;
    if (settings.customLyricColorHex != null) {
      try { lyricColor = Color(int.parse(settings.customLyricColorHex!.replaceFirst('#', '0xFF'))); } catch (_) {}
    }

    selectedFont = settings.fontFamily ?? 'Inter';
    if (!availableFonts.contains(selectedFont)) {
      selectedFont = 'Inter';
    }

    fontSize = settings.defaultFontSize;
  }

  void _saveTheme() {
    final notifier = ref.read(settingsProvider.notifier);
    notifier.setCustomThemeColorHex('#${primaryColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    notifier.setCustomBgColorHex('#${bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    notifier.setCustomTextColorHex('#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    notifier.setCustomChordColorHex('#${chordColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    notifier.setCustomLyricColorHex('#${lyricColor.value.toRadixString(16).padLeft(8, '0').substring(2)}');
    
    Navigator.of(context).pop();
  }

  void _pickColor(String title, Color currentColor, ValueChanged<Color> onColorChanged) {
    Color tempColor = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (c) => tempColor = c,
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
            hexInputBar: true, // Permite digitar o código HEX
            colorPickerWidth: 300,
            colorHistory: _recentColors,
            onHistoryChanged: (List<Color> colors) {
              _recentColors = colors;
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () {
              if (!_recentColors.contains(tempColor)) {
                _recentColors.add(tempColor);
                if (_recentColors.length > 12) _recentColors.removeAt(0);
              }
              onColorChanged(tempColor);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('SELECIONAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    // Gerar um ThemeData temporário para o preview
    final previewTheme = AppTheme.buildCustomTheme(
      primaryHex: '#${primaryColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      bgHex: '#${bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      textHex: '#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}',
      fontFamily: selectedFont,
    );

    final previewArea = AnimatedTheme(
      data: previewTheme,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: previewTheme.colorScheme.surface,
          borderRadius: isMobile 
              ? BorderRadius.zero
              : const BorderRadius.only(topLeft: Radius.circular(32), bottomLeft: Radius.circular(32)),
          border: isMobile
              ? Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)))
              : Border(right: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1))),
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: previewTheme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PREVIEW AO VIVO',
                      style: TextStyle(
                        color: previewTheme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.visibility, color: previewTheme.colorScheme.primary.withOpacity(0.5), size: 20),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 40),
            Text(
              'Amazing Grace',
              style: previewTheme.textTheme.displayLarge?.copyWith(fontSize: isMobile ? 24 : 36, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              'John Newton',
              style: previewTheme.textTheme.titleLarge?.copyWith(fontSize: isMobile ? 14 : 20, color: previewTheme.colorScheme.onSurface.withOpacity(0.5)),
            ),
            SizedBox(height: isMobile ? 12 : 24),
            // Mock de Componentes de UI
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: previewTheme.colorScheme.primary,
                    foregroundColor: previewTheme.colorScheme.onPrimary,
                  ),
                  child: const Text('Principal'),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: previewTheme.colorScheme.primary,
                    side: BorderSide(color: previewTheme.colorScheme.primary),
                  ),
                  child: const Text('Secundário'),
                ),
                Switch(
                  value: true, 
                  onChanged: (_) {},
                  activeColor: previewTheme.colorScheme.primary,
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 24),
            // Mock Cifra
            Expanded(
              child: Container(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                decoration: BoxDecoration(
                  color: previewTheme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: previewTheme.colorScheme.outline.withOpacity(0.1)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.music_note, size: 16, color: previewTheme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Tom: G', style: previewTheme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: previewTheme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'G                   C           G',
                        style: previewTheme.textTheme.bodyMedium?.copyWith(fontSize: fontSize, color: chordColor, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Amazing grace! How sweet the sound',
                        style: previewTheme.textTheme.bodyMedium?.copyWith(fontSize: fontSize, color: lyricColor),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '                   D',
                        style: previewTheme.textTheme.bodyMedium?.copyWith(fontSize: fontSize, color: chordColor, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'That saved a wretch like me',
                        style: previewTheme.textTheme.bodyMedium?.copyWith(fontSize: fontSize, color: lyricColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final controlsArea = Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            Text(
              'Design Studio',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Construa sua identidade visual.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
          ],
          _buildColorSelector('Fundo da Tela', bgColor, (c) => setState(() => bgColor = c)),
          _buildColorSelector('Detalhes e Destaques', primaryColor, (c) => setState(() => primaryColor = c)),
          _buildColorSelector('Acordes', chordColor, (c) => setState(() => chordColor = c)),
          _buildColorSelector('Letra da Música', lyricColor, (c) => setState(() => lyricColor = c)),
          _buildColorSelector('Textos Secundários', textColor, (c) => setState(() => textColor = c)),
        ],
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Design Studio', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          elevation: 0,
        ),
        body: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              child: previewArea,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: controlsArea,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saveTheme,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('SALVAR TEMA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: 950,
            height: 640,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40)],
            ),
            child: Row(
              children: [
                Expanded(flex: 5, child: previewArea),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: controlsArea,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: _saveTheme,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: const Text('SALVAR TEMA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildColorSelector(String label, Color color, ValueChanged<Color> onChanged) {
    final hexCode = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => _pickColor(label, color, onChanged),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hexCode,
                      style: TextStyle(
                        fontFamily: 'Fira Code',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
