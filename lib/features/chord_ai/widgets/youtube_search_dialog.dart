import 'package:flutter/material.dart';
import '../services/youtube_service.dart';

class YouTubeSearchDialog extends StatefulWidget {
  final YouTubeService youtubeService;
  final String? initialQuery;

  const YouTubeSearchDialog({
    super.key,
    required this.youtubeService,
    this.initialQuery,
  });

  @override
  State<YouTubeSearchDialog> createState() => _YouTubeSearchDialogState();
}

class _YouTubeSearchDialogState extends State<YouTubeSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<YouTubeVideoItem> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    } else {
      _results = YouTubeService.suggestions;
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final results = await widget.youtubeService.searchVideos(query);
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141722),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600,
        height: 650,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.smart_display_rounded, color: Color(0xFFFF5252), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Buscar no YouTube',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de Busca
            TextField(
              controller: _searchController,
              onSubmitted: _performSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Digite o nome da música ou artista...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF00E5FF)),
                  onPressed: () => _performSearch(_searchController.text),
                ),
                filled: true,
                fillColor: const Color(0xFF1E212D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sugestões Rápidas (Chips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickChip('The Beatles'),
                  _buildQuickChip('Queen'),
                  _buildQuickChip('Ed Sheeran'),
                  _buildQuickChip('Tom Jobim'),
                  _buildQuickChip('Legião Urbana'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Resultados
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 12, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final video = _results[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 80,
                              height: 50,
                              child: Image.network(
                                video.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: Colors.black45,
                                  child: const Icon(Icons.music_note, color: Colors.white54),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            video.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${video.author} • ${video.duration}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Color(0xFF00E5FF),
                            size: 26,
                          ),
                          onTap: () {
                            Navigator.pop(context, video);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String query) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(query),
        backgroundColor: const Color(0xFF1E212D),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        onPressed: () {
          _searchController.text = query;
          _performSearch(query);
        },
      ),
    );
  }
}
