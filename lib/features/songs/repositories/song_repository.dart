import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/song.dart';
import '../models/song_collection.dart';
import '../models/song_setlist.dart';

class SongRepository {
  final FirebaseDatabase _database;
  final String userId;

  SongRepository({required FirebaseDatabase database, required this.userId}) : _database = database;

  DatabaseReference get _songsRef => _database.ref('users/$userId/songs');
  DatabaseReference get _collectionsRef => _database.ref('users/$userId/collections');
  DatabaseReference get _setlistsRef => _database.ref('users/$userId/setlists');

  Future<void> createCollection(SongCollection collection) async {
    await _collectionsRef.child(collection.id).set(collection.toJson());
  }

  Future<void> updateCollection(SongCollection collection) async {
    await _collectionsRef.child(collection.id).update(collection.toJson());
  }

  Future<void> deleteCollection(String collectionId) async {
    await _collectionsRef.child(collectionId).remove();
  }

  Stream<List<SongCollection>> watchCollections() {
    return _collectionsRef.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return <SongCollection>[];
      }
      try {
        final value = snapshot.value;
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          final List<SongCollection> parsedCollections = [];
          for (final data in map.values) {
            if (data is Map) {
              parsedCollections.add(SongCollection.fromJson(Map<String, dynamic>.from(data)));
            }
          }
          return parsedCollections;
        } else if (value is List) {
          final list = List<dynamic>.from(value);
          return list.where((e) => e != null).map((data) {
            return SongCollection.fromJson(Map<String, dynamic>.from(data as Map));
          }).toList();
        }
      } catch (e) {
        print('Error parsing collections from Firebase: $e');
      }
      return <SongCollection>[];
    });
  }

  Future<void> createSetlist(SongSetlist setlist) async {
    await _setlistsRef.child(setlist.id).set(setlist.toJson());
  }

  Future<void> updateSetlist(SongSetlist setlist) async {
    await _setlistsRef.child(setlist.id).update(setlist.toJson());
  }

  Future<void> deleteSetlist(String setlistId) async {
    await _setlistsRef.child(setlistId).remove();
  }

  Stream<List<SongSetlist>> watchSetlists() {
    return _setlistsRef.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return <SongSetlist>[];
      }
      try {
        final value = snapshot.value;
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          final List<SongSetlist> list = [];
          for (final data in map.values) {
            if (data is Map) {
              list.add(SongSetlist.fromJson(Map<String, dynamic>.from(data)));
            }
          }
          return list;
        } else if (value is List) {
          final list = List<dynamic>.from(value);
          return list.where((e) => e != null).map((data) {
            return SongSetlist.fromJson(Map<String, dynamic>.from(data as Map));
          }).toList();
        }
      } catch (e) {
        print('Error parsing setlists from Firebase: $e');
      }
      return <SongSetlist>[];
    });
  }



  Future<void> createSong(Song song) async {
    await _songsRef.child(song.id).set(song.toJson());
  }

  Future<void> updateSong(Song song) async {
    await _songsRef.child(song.id).update(song.toJson());
  }

  Future<void> deleteSong(String songId) async {
    await _songsRef.child(songId).remove();
  }

  Future<void> deleteAllData() async {
    await _database.ref('users/$userId').remove();
  }

  Future<Song?> getSong(String songId) async {
    final snapshot = await _songsRef.child(songId).get();
    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return Song.fromJson(data);
    }
    return null;
  }

  Stream<List<Song>> watchSongs() {
    return _songsRef.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return <Song>[];
      }
      try {
        final value = snapshot.value;
        if (value is Map) {
          final List<Song> parsedSongs = [];
          
          void parseNode(String key, dynamic nodeData) {
            if (nodeData is Map) {
              try {
                final nodeMap = Map<String, dynamic>.from(nodeData);
                if (nodeMap.containsKey('title') || nodeMap.containsKey('content')) {
                  if (!nodeMap.containsKey('id') || nodeMap['id'] == null || nodeMap['id'].toString().isEmpty) {
                    nodeMap['id'] = key;
                  }
                  parsedSongs.add(Song.fromJson(nodeMap));
                } else {
                  nodeMap.forEach((childKey, childValue) {
                    parseNode(childKey.toString(), childValue);
                  });
                }
              } catch (e) {
                print('Error parsing individual song node $key: $e');
              }
            }
          }

          final map = Map<dynamic, dynamic>.from(value);
          map.forEach((key, val) {
            parseNode(key.toString(), val);
          });
          return parsedSongs;
        } else if (value is List) {
          final list = List<dynamic>.from(value);
          return list.where((e) => e != null).map((data) {
            try {
              return Song.fromJson(Map<String, dynamic>.from(data as Map));
            } catch (e) {
              print('Error parsing song from list: $e');
              return null;
            }
          }).whereType<Song>().toList();
        }
      } catch (e, stack) {
        print('Error parsing songs from Firebase: $e\n$stack');
      }
      return <Song>[];
    });
  }
}

final songRepositoryProvider = Provider<SongRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return SongRepository(
    database: FirebaseDatabase.instance,
    userId: user?.uid ?? 'guest',
  );
});

final songListProvider = StreamProvider<List<Song>>((ref) {
  final repository = ref.watch(songRepositoryProvider);
  return repository.watchSongs();
});

final collectionListProvider = StreamProvider<List<SongCollection>>((ref) {
  final repository = ref.watch(songRepositoryProvider);
  return repository.watchCollections();
});

final setlistListProvider = StreamProvider<List<SongSetlist>>((ref) {
  final repository = ref.watch(songRepositoryProvider);
  return repository.watchSetlists();
});

