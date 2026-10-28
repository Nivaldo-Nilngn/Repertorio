import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/setlist_repository.dart';
import '../services/youtube_service.dart';

class FeaturedSetlistsTab extends StatefulWidget {
  final Function(FeaturedSong song) onSongSelected;

  const FeaturedSetlistsTab({
    super.key,
    required this.onSongSelected,
  });

  @override
  State<FeaturedSetlistsTab> createState() => _FeaturedSetlistsTabState();
}

class _FeaturedSetlistsTabState extends State<FeaturedSetlistsTab> {
  final TextEditingController _searchController = TextEditingController();
  final YouTubeService _youtubeService = YouTubeService();

  String _searchQuery = '';
  bool _isSearchingYouTube = false;
  List<YouTubeVideoItem> _searchedYouTubeVideos = [];

  // Sugestões rápidas de louvores para busca em um toque
  final List<String> _quickSuggestions = [
    'Para Onde Eu Irei? - Morada',
    'Ambition - Gabi Sampaio',
    'Ninguém Explica Deus - Preto no Branco',
    'Diz - Gabriela Rocha',
    'O Galileu - Fernandinho',
    'A Casa É Sua - Casa Worship',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    // 1. Verifica se é uma URL do YouTube colada diretamente
    final videoId = YoutubePlayerController.convertUrlToId(clean);
    if (videoId != null && videoId.isNotEmpty) {
      final generatedSong = SetlistRepository.findOrGenerateSongForVideo(
        id: videoId,
        title: 'Música do YouTube ($videoId)',
        artist: 'YouTube Jam',
        durationSeconds: 240,
      );
      widget.onSongSelected(generatedSong);
      return;
    }

    // 2. Busca no YouTube
    setState(() {
      _isSearchingYouTube = true;
      _searchQuery = clean;
    });

    final results = await _youtubeService.searchVideos(clean);
    if (mounted) {
      setState(() {
        _searchedYouTubeVideos = results;
        _isSearchingYouTube = false;
      });
    }
  }

  void _handleSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _onSearchSubmitted(suggestion);
  }

  void _selectVideo(YouTubeVideoItem item) {
    final song = SetlistRepository.findOrGenerateSongForVideo(
      id: item.id,
      title: item.title,
      artist: item.author,
      durationSeconds: _parseDuration(item.duration),
    );
    widget.onSongSelected(song);
  }

  int _parseDuration(String durStr) {
    final parts = durStr.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 2) {
      return (parts[0] * 60) + parts[1];
    } else if (parts.length == 3) {
      return (parts[0] * 3600) + (parts[1] * 60) + parts[2];
    }
    return 240;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F1D),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: CustomScrollView(
            slivers: [
              // 1. Barra de Busca no estilo Chorda (app.chorda.com.br/pt/home)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: _buildChordaSearchBar(),
                ),
              ),

              // 2. Sugestões / Histórico Rápido
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildQuickSuggestions(),
                ),
              ),

              // 3. Se houver busca em andamento
              if (_isSearchingYouTube)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Color(0xFF2F6BFF)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Pesquisando no YouTube com IA...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Resultados da Busca do YouTube
              if (_searchedYouTubeVideos.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resultados para "$_searchQuery"',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchedYouTubeVideos = [];
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                          child: const Text('Limpar',
                              style: TextStyle(color: Color(0xFF2F6BFF))),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = _searchedYouTubeVideos[index];
                        return _buildVideoCard(video);
                      },
                      childCount: _searchedYouTubeVideos.length,
                    ),
                  ),
                ),
              ],

              // 5. Se buscou mas não encontrou nada
              if (!_isSearchingYouTube &&
                  _searchedYouTubeVideos.isEmpty &&
                  _searchQuery.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: Colors.white38),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum vídeo encontrado para "$_searchQuery"',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tente buscar por outro termo ou cole o link direto do YouTube.',
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // 6. Se não houver busca ativa, exibe "Como funciona" (como no Chorda)
              if (!_isSearchingYouTube &&
                  _searchedYouTubeVideos.isEmpty &&
                  _searchQuery.isEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Como funciona',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildHowItWorksCards(),
                      ],
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChordaSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13172C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2F6BFF).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F6BFF).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const Icon(Icons.search_rounded, color: Color(0xFF2F6BFF), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onSubmitted: _onSearchSubmitted,
              decoration: const InputDecoration(
                hintText: 'Busque uma música ou cole um link do YouTube',
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchedYouTubeVideos = [];
                  _searchQuery = '';
                });
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _onSearchSubmitted(_searchController.text),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F6BFF), Color(0xFF00D2FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in _quickSuggestions)
          InkWell(
            onTap: () => _handleSuggestionTap(item),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF161A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    item,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHowItWorksCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final children = [
          _buildStepCard(
            stepNumber: '1',
            icon: Icons.search_rounded,
            title: 'Busque ou cole um link',
            subtitle: 'Qualquer música do YouTube ou cole uma URL direta.',
          ),
          _buildStepCard(
            stepNumber: '2',
            icon: Icons.graphic_eq_rounded,
            title: 'Extraia os acordes',
            subtitle: 'Análise acústica pura com IA sem simulações.',
          ),
          _buildStepCard(
            stepNumber: '3',
            icon: Icons.music_note_rounded,
            title: 'Toque junto',
            subtitle: 'Player com compassos sincronizados e diagramas.',
          ),
        ];

        if (isMobile) {
          return Column(
            children: children
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: c,
                    ))
                .toList(),
          );
        }

        return Row(
          children: children
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2F6BFF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2F6BFF), size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            '$stepNumber. $title',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(YouTubeVideoItem video) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Thumbnail com tempo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Image.network(
                  video.thumbnailUrl,
                  width: 140,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 140,
                    height: 80,
                    color: const Color(0xFF1F253E),
                    child: const Icon(Icons.music_note, color: Colors.white38),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Informações do Vídeo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.author,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Botão Extrair com IA / Tocar
          ElevatedButton.icon(
            onPressed: () => _selectVideo(video),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6BFF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text(
              'Extrair com IA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
