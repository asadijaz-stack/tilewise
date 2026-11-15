/// The shipped dictionary must be the OFFICIAL Scrabble word list
/// (CSW21 — Collins Scrabble Words, 2021), not a generic English list.
///
/// Scrabble word rules:
/// - 2 to 15 letters, letters only
/// - no abbreviations, no proper nouns, no hyphenated words,
///   no words needing an apostrophe, no foreign words
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('official CSW21 dictionary follows Scrabble rules', () {
    final words = File('assets/words.txt')
        .readAsLinesSync()
        .where((w) => w.isNotEmpty)
        .toList();

    // CSW21 has exactly 279,077 words.
    expect(words.length, 279077);
    expect(words.toSet().length, words.length); // no duplicates

    // Every entry: 2-15 capital letters, nothing else.
    expect(words.every((w) => RegExp(r'^[A-Z]{2,15}$').hasMatch(w)),
        isTrue);

    // Real Scrabble words, including the famous 2-letter words.
    final set = words.toSet();
    for (final w in ['AA', 'QI', 'ZA', 'JO', 'OX', 'OK', 'AX', 'ED', 'GO']) {
      expect(set.contains(w), isTrue, reason: '$w should be in CSW21');
    }
    // CSW21 has exactly 127 two-letter words.
    expect(set.where((w) => w.length == 2).length, 127);

    // Abbreviations, proper nouns and non-words are NOT in CSW.
    for (final w in [
      'TV',
      'USA',
      'NASA',
      'FBI',
      'BBC',
      'COVID',
      'LOL',
      'OMG',
      'DVD',
      'GPS',
      'CEO',
      'ATM',
      'BTW',
      'LONDON',
    ]) {
      expect(set.contains(w), isFalse, reason: '$w must not be in CSW21');
    }

    // The common-words tier (Easy/Medium AI) is a subset of the
    // official list, so the AI can never play a non-Scrabble word.
    final common = File('assets/common_words.txt')
        .readAsLinesSync()
        .where((w) => w.isNotEmpty)
        .toList();
    expect(common.length, greaterThan(8000));
    expect(common.every(set.contains), isTrue);
  });
}
