/// Word list lookups and a trie for the AI move generator.
library;

/// Case-insensitive word set used to validate plays.
class Dictionary {
  final Set<String> _words;

  Dictionary(Set<String> words) : _words = words;

  factory Dictionary.fromWords(Iterable<String> words) =>
      Dictionary(words.map((w) => w.trim().toUpperCase()).toSet());

  bool contains(String word) => _words.contains(word.toUpperCase());

  int get size => _words.length;

  List<String> get words => _words.toList();
}

/// Trie node for prefix-based move generation.
class TrieNode {
  final Map<String, TrieNode> children = {};
  bool terminal = false;
}

/// Prefix trie over the dictionary, used by the AI.
class Trie {
  final TrieNode root = TrieNode();

  void insert(String word) {
    var node = root;
    for (var i = 0; i < word.length; i++) {
      final ch = word[i];
      node = node.children.putIfAbsent(ch, () => TrieNode());
    }
    node.terminal = true;
  }

  static Trie fromWords(Iterable<String> words) {
    final trie = Trie();
    for (final w in words) {
      final word = w.trim().toUpperCase();
      if (word.length >= 2 && word.length <= 15) {
        trie.insert(word);
      }
    }
    return trie;
  }
}
