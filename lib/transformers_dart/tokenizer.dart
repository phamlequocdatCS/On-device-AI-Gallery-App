// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:core';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import '../misc/file_logger.dart';

List<String> regexSplit(String text, RegExp regex) {
  List<String> result = [];
  int prev = 0;

  for (RegExpMatch match in regex.allMatches(text)) {
    String fullMatch = match.group(0)!;
    if (prev < match.start) {
      result.add(text.substring(prev, match.start));
    }
    if (fullMatch.isNotEmpty) {
      result.add(fullMatch);
    }
    prev = match.end;
  }

  if (prev < text.length) {
    result.add(text.substring(prev));
  }

  return result;
}

String cleanUpTokenization(String text) {
  // Clean up a list of simple English tokenization artifacts
  // like spaces before punctuations and abbreviated forms
  return text
      .replaceAll(RegExp(r' \.'), '.')
      .replaceAll(RegExp(r' \?'), '?')
      .replaceAll(RegExp(r' \!'), '!')
      .replaceAll(RegExp(r' ,'), ',')
      .replaceAll(RegExp(r" ' "), "'")
      .replaceAll(RegExp(r" n't"), "n't")
      .replaceAll(RegExp(r" 'm"), "'m")
      .replaceAll(RegExp(r" 's"), "'s")
      .replaceAll(RegExp(r" 've"), "'ve")
      .replaceAll(RegExp(r" 're"), "'re");
}

String removeAccents(String text) {
  // Remove combining diacritical marks
  return text.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}

String lowercaseAndRemoveAccent(String text) {
  return removeAccents(text.toLowerCase());
}

List<T> fuse<T>(List<T> arr, T value, Map<T, dynamic> mapping) {
  final fused = <T>[];
  int i = 0;
  while (i < arr.length) {
    fused.add(arr[i]);
    if ((mapping[arr[i]] ?? value) != value) {
      ++i;
      continue;
    }

    while (i < arr.length && (mapping[arr[i]] ?? value) == value) {
      ++i;
    }
  }

  return fused;
}

List<String> whitespaceSplit(String text) {
  return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
}

/// A regular expression pattern for punctuation characters.
const String PUNCTUATION_REGEX =
    r'\p{P}\u0021-\u002F\u003A-\u0040\u005B-\u0060\u007B-\u007E';

/// A mapping of regex patterns to their equivalent (but longer) Dart-compatible versions.
final Map<String, String> PROBLEMATIC_REGEX_MAP = {
  // This uses the case insensitive group modifier, which is not supported in Dart.
  // When parsing the regex, an "Invalid group" error is thrown.
  r"(?i:'s|'t|'re|'ve|'m|'ll|'d)":
      r"(?:'([sS]|[tT]|[rR][eE]|[vV][eE]|[mM]|[lL][lL]|[dD]))",
};

abstract class TokenizerModel {
  final Map<String, dynamic> config;
  List<String> vocab = [];
  Map<String, int> tokensToIds = {};
  int? unkTokenId;
  String? unkToken;
  String? endOfWordSuffix;
  bool fuseUnk;

  TokenizerModel(this.config) : fuseUnk = config['fuse_unk'] ?? false;

  static TokenizerModel fromConfig(Map<String, dynamic> config) {
    switch (config['type']) {
      case 'BPE':
        return BPE(config: config);
      default:
        return BPE(config: config);
    }
  }

  List<int> call(List<String> tokens) {
    List<int> ids = encode(tokens);
    if (fuseUnk) {
      ids = fuse(ids, unkTokenId!,
          tokensToIds.map((key, value) => MapEntry(value, key)));
    }
    return ids;
  }

  List<int> encode(List<String> tokens);

  List<int> convertTokensToIds(List<String> tokens) {
    return tokens.map((t) => tokensToIds[t] ?? unkTokenId!).toList();
  }

  List<String> convertIdsToTokens(List<int> ids) {
    return ids.map((i) => vocab[i]).toList();
  }
}

class BPE extends TokenizerModel {
  final Map<String, int> bpeRanks;
  final List<List<String>> merges;
  final String? continuingSubwordSuffix;
  final bool byteFallback;
  final bool ignoreMerges;
  final Map<String, List<String>> cache;

  static const String BPE_SPLIT_TOKEN = ' ';

  BPE({required Map<String, dynamic> config})
      : bpeRanks = Map<String, int>.fromEntries(
            (config['merges'] as List<dynamic>)
                .cast<String>()
                .asMap()
                .entries
                .map((e) => MapEntry(e.value, e.key))),
        merges = (config['merges'] as List<dynamic>)
            .cast<String>()
            .map((x) => x.split(BPE_SPLIT_TOKEN))
            .toList(),
        continuingSubwordSuffix = config['continuing_subword_suffix'],
        byteFallback = config['byte_fallback'] ?? false,
        ignoreMerges = config['ignore_merges'] ?? false,
        cache = {},
        super(config) {
    tokensToIds = Map<String, int>.from(config['vocab']);
    vocab = List<String>.filled(tokensToIds.length, '');
    tokensToIds.forEach((key, value) {
      vocab[value] = key;
    });
    unkToken = config['unk_token'];
    unkTokenId = tokensToIds[unkToken];
    endOfWordSuffix = config['end_of_word_suffix'];
  }

  List<String> bpe(String token) {
    if (token.isEmpty) {
      return [];
    }

    if (cache.containsKey(token)) {
      return cache[token]!;
    }

    List<String> word = token.split('');
    if (endOfWordSuffix != null && endOfWordSuffix!.isNotEmpty) {
      word[word.length - 1] += endOfWordSuffix!;
    }

    List<String> result = [];
    if (word.length > 1) {
      final queue =
          HeapPriorityQueue<_BPENode>((a, b) => a.score.compareTo(b.score));

      _BPENode? startingNode = _BPENode(
        token: word[0],
        bias: 0,
        prev: null,
        next: null,
      );

      _BPENode previousNode = startingNode;
      for (int i = 1; i < word.length; ++i) {
        final currentNode = _BPENode(
          token: word[i],
          bias: i / word.length,
          prev: previousNode,
          next: null,
        );
        previousNode.next = currentNode;
        _addNode(queue, previousNode);
        previousNode = currentNode;
      }

      while (queue.isNotEmpty) {
        final node = queue.removeFirst();

        if (node.deleted || node.next == null || node.next!.deleted) continue;

        node.deleted = true;
        node.next!.deleted = true;

        if (node.prev != null) {
          final newPreviousNode = _BPENode(
            token: node.prev!.token,
            bias: node.prev!.bias,
            prev: node.prev!.prev,
            next: node.prev!.next,
          );

          node.prev!.deleted = true;
          node.prev = newPreviousNode;

          if (newPreviousNode.prev != null) {
            newPreviousNode.prev!.next = newPreviousNode;
          } else {
            startingNode = newPreviousNode;
          }
        }

        final merged = _BPENode(
          token: node.token + node.next!.token,
          bias: node.bias,
          prev: node.prev,
          next: node.next!.next,
        );

        if (merged.prev != null) {
          merged.prev!.next = merged;
          _addNode(queue, merged.prev!);
        } else {
          startingNode = merged;
        }

        if (merged.next != null) {
          merged.next!.prev = merged;
          _addNode(queue, merged);
        }
      }

      for (_BPENode? currentNode = startingNode;
          currentNode != null;
          currentNode = currentNode.next) {
        result.add(currentNode.token);
      }
    } else {
      result = word;
    }

    if (continuingSubwordSuffix != null) {
      for (int i = 0; i < result.length - 1; ++i) {
        result[i] += continuingSubwordSuffix!;
      }
    }

    cache[token] = result;
    return result;
  }

  void _addNode(HeapPriorityQueue<_BPENode> queue, _BPENode node) {
    final rank = bpeRanks[node.token + BPE_SPLIT_TOKEN + node.next!.token];
    if (rank != null) {
      node.score = rank + node.bias;
      queue.add(node);
    }
  }

  @override
  List<int> encode(List<String> tokens) {
    final outputTokens = <String>[];

    for (final token in tokens) {
      if (ignoreMerges && tokensToIds.containsKey(token)) {
        outputTokens.add(token);
        continue;
      }
      final bpeTokenList = bpe(token);

      for (final t in bpeTokenList) {
        if (tokensToIds.containsKey(t)) {
          outputTokens.add(t);
        } else {
          if (byteFallback) {
            outputTokens.addAll(utf8.encode(t).map((x) =>
                '<0x${x.toRadixString(16).toUpperCase().padLeft(2, '0')}>'));
          } else {
            outputTokens.add(unkToken!);
          }
        }
      }
    }

    return convertTokensToIds(outputTokens);
  }
}

class _BPENode {
  String token;
  double bias;
  _BPENode? prev;
  _BPENode? next;
  bool deleted = false;
  double score = 0;

  _BPENode({
    required this.token,
    required this.bias,
    this.prev,
    this.next,
  });
}

abstract class Normalizer {
  Map<String, dynamic> config;

  Normalizer(this.config);

  static Normalizer fromConfig(Map<String, dynamic> config) {
    switch (config['type']) {
      case 'BertNormalizer':
        return BertNormalizer(config);
      case 'Sequence':
        return NormalizerSequence(config);
      case 'Replace':
        return Replace(config);
      case 'NFC':
        return NFC(config);
      case 'Strip':
        return StripNormalizer(config);
      case 'StripAccents':
        return StripAccents(config);
      case 'Lowercase':
        return Lowercase(config);
      case 'Prepend':
        return Prepend(config);
      default:
        throw Exception('Unknown Normalizer type: ${config['type']}');
    }
  }

  String normalize(String text);

  String call(String text) => normalize(text);
}

class Replace extends Normalizer {
  Replace(super.config);

  @override
  String normalize(String text) {
    final pattern = createPattern(config['pattern']);
    return pattern == RegExp('')
        ? text
        : text.replaceAll(pattern, config['content']);
  }
}

class NFC extends Normalizer {
  NFC(super.config);

  @override
  String normalize(String text) {
    return text; // Dart strings are already in NFC form
  }
}

class StripNormalizer extends Normalizer {
  StripNormalizer(super.config);

  @override
  String normalize(String text) {
    if (config['strip_left'] && config['strip_right']) {
      return text.trim();
    } else {
      if (config['strip_left']) {
        text = text.trimLeft();
      }
      if (config['strip_right']) {
        text = text.trimRight();
      }
    }
    return text;
  }
}

class StripAccents extends Normalizer {
  StripAccents(super.config);

  @override
  String normalize(String text) {
    return removeAccents(text);
  }
}

class Lowercase extends Normalizer {
  Lowercase(super.config);

  @override
  String normalize(String text) {
    return text.toLowerCase();
  }
}

class Prepend extends Normalizer {
  Prepend(super.config);

  @override
  String normalize(String text) {
    return config['prepend'] + text;
  }
}

class NormalizerSequence extends Normalizer {
  late List<Normalizer> normalizers;

  NormalizerSequence(Map<String, dynamic> config) : super(config) {
    normalizers = (config['normalizers'] as List)
        .map((x) => Normalizer.fromConfig(x as Map<String, dynamic>))
        .toList();
  }

  @override
  String normalize(String text) {
    return normalizers.fold(text, (t, normalizer) => normalizer.normalize(t));
  }
}

class BertNormalizer extends Normalizer {
  BertNormalizer(super.config);

  String _tokenizeChineseChars(String text) {
    final output = StringBuffer();
    for (final char in text.runes) {
      if (_isChineseChar(char)) {
        output.write(' ');
        output.writeCharCode(char);
        output.write(' ');
      } else {
        output.writeCharCode(char);
      }
    }
    return output.toString();
  }

  bool _isChineseChar(int cp) {
    return (cp >= 0x4E00 && cp <= 0x9FFF) ||
        (cp >= 0x3400 && cp <= 0x4DBF) ||
        (cp >= 0x20000 && cp <= 0x2A6DF) ||
        (cp >= 0x2A700 && cp <= 0x2B73F) ||
        (cp >= 0x2B740 && cp <= 0x2B81F) ||
        (cp >= 0x2B820 && cp <= 0x2CEAF) ||
        (cp >= 0xF900 && cp <= 0xFAFF) ||
        (cp >= 0x2F800 && cp <= 0x2FA1F);
  }

  bool _isControl(String char) {
    if (char == '\t' || char == '\n' || char == '\r') {
      return false;
    }
    // TODO: Implement Unicode category check
    return false;
  }

  String _cleanText(String text) {
    final output = StringBuffer();
    for (final char in text.runes) {
      if (char == 0 ||
          char == 0xFFFD ||
          _isControl(String.fromCharCode(char))) {
        continue;
      }
      if (RegExp(r'^\s$').hasMatch(String.fromCharCode(char))) {
        output.write(' ');
      } else {
        output.writeCharCode(char);
      }
    }
    return output.toString();
  }

  @override
  String normalize(String text) {
    if (config['clean_text']) {
      text = _cleanText(text);
    }

    if (config['handle_chinese_chars']) {
      text = _tokenizeChineseChars(text);
    }

    if (config['lowercase']) {
      text = text.toLowerCase();

      if (config['strip_accents'] != false) {
        text = removeAccents(text);
      }
    } else if (config['strip_accents']) {
      text = removeAccents(text);
    }

    return text;
  }
}

abstract class PreTokenizer {
  static PreTokenizer fromConfig(Map<String, dynamic> config) {
    switch (config['type']) {
      case 'BertPreTokenizer':
        return BertPreTokenizer(config);
      case 'Sequence':
        return PreTokenizerSequence(config);
      case 'Whitespace':
        return WhitespacePreTokenizer(config);
      case 'WhitespaceSplit':
        return WhitespaceSplit(config);
      case 'ByteLevel':
        return ByteLevelPreTokenizer(config);
      case 'Split':
        return SplitPreTokenizer(config);
      case 'Punctuation':
        return PunctuationPreTokenizer(config);
      case 'Digits':
        return DigitsPreTokenizer(config);
      case 'Replace':
        return ReplacePreTokenizer(config);
      default:
        throw Exception('Unknown PreTokenizer type: ${config['type']}');
    }
  }

  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    throw UnimplementedError(
        "preTokenizeText should be implemented in subclass.");
  }

  List<String> preTokenize(dynamic text, [Map<String, dynamic>? options]) {
    if (text is List<String>) {
      return text.expand((x) => preTokenizeText(x, options)).toList();
    } else if (text is String) {
      return preTokenizeText(text, options);
    } else {
      throw ArgumentError('Input must be a String or List<String>');
    }
  }

  List<String> call(dynamic text, [Map<String, dynamic>? options]) {
    return preTokenize(text, options);
  }
}

class BertPreTokenizer extends PreTokenizer {
  late RegExp pattern;

  BertPreTokenizer(Map<String, dynamic> config) {
    // Construct a pattern which matches the rust implementation
    pattern = RegExp(r'[^\s\p{P}]+|[\p{P}]', unicode: true);
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    return pattern.allMatches(text.trim()).map((m) => m.group(0)!).toList();
  }
}

class PreTokenizerSequence extends PreTokenizer {
  late List<PreTokenizer> tokenizers = [];

  PreTokenizerSequence(Map<String, dynamic> config) {
    for (var tknizer in (config['pretokenizers'] as List)) {
      tokenizers.add(PreTokenizer.fromConfig(tknizer));
    }
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    return tokenizers.fold<List<String>>([text], (preTokenizedText, tokenizer) {
      return tokenizer.preTokenize(preTokenizedText, options);
    });
  }
}

class WhitespacePreTokenizer extends PreTokenizer {
  WhitespacePreTokenizer(Map<String, dynamic> config);

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    return RegExp(r'\w+|[^\w\s]+')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
  }
}

class WhitespaceSplit extends PreTokenizer {
  WhitespaceSplit(Map<String, dynamic> config);

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    return whitespaceSplit(text);
  }
}

Pattern createPattern(Map<String, dynamic> pattern, {bool invert = true}) {
  if (pattern.containsKey('Regex')) {
    // Handle unnecessary escape sequences
    String regex = pattern['Regex'].toString().replaceAllMapped(
          RegExp(r'\\([#&~])'),
          (match) => match.group(1)!,
        );

    // Handle special cases where the regex contains invalid (non-Dart compatible) syntax
    for (final entry in PROBLEMATIC_REGEX_MAP.entries) {
      regex = regex.replaceAll(entry.key, entry.value);
    }

    return RegExp(regex, unicode: true, dotAll: true);
  } else if (pattern.containsKey('String')) {
    final escaped = RegExp.escape(pattern['String']);
    // If invert is true, we wrap the pattern in a group so that it is kept when performing .split()
    return RegExp(invert ? escaped : '($escaped)', unicode: true, dotAll: true);
  } else {
    print('Warning: Unknown pattern type: $pattern');
    return RegExp('');
  }
}

class ReplacePreTokenizer extends PreTokenizer {
  late Pattern pattern;
  late String content;

  ReplacePreTokenizer(Map<String, dynamic> config) {
    pattern = createPattern(config['pattern'] as Map<String, dynamic>);
    content = config['content'];
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    if (pattern == RegExp('')) {
      return [text];
    }
    return [text.replaceAll(pattern, content)];
  }
}

class ByteLevelPreTokenizer extends PreTokenizer {
  late bool addPrefixSpace;
  late bool trimOffsets;
  late bool useRegex;
  late RegExp pattern;
  late Map<int, String> byteEncoder;

  ByteLevelPreTokenizer(Map<String, dynamic> config) {
    addPrefixSpace = config['add_prefix_space'] ?? false;
    trimOffsets = config['trim_offsets'] ?? false;
    useRegex = config['use_regex'] ?? true;
    pattern = RegExp(
        r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+",
        unicode: true);
    byteEncoder = BYTES_TO_UNICODE; // This needs to be defined elsewhere
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    if (addPrefixSpace && !text.startsWith(' ')) {
      text = ' $text';
    }

    List<String> tokens = useRegex
        ? pattern.allMatches(text).map((m) => m.group(0)!).toList()
        : [text];

    return tokens.map((token) {
      return utf8.encode(token).map((byte) => byteEncoder[byte]!).join('');
    }).toList();
  }
}

enum SplitDelimiterBehavior {
  removed,
  isolated,
  mergedWithPrevious,
  mergedWithNext,
  contiguous
}

class SplitPreTokenizer extends PreTokenizer {
  late Pattern pattern;
  late bool invert;

  SplitPreTokenizer(Map<String, dynamic> config) {
    // print(config['pattern']['Regex']);
    pattern = createPattern(config['pattern'] as Map<String, dynamic>,
        invert: config['invert'] ?? false);
    invert = config['invert'] ?? false;
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    if (pattern == RegExp('')) {
      return [];
    }

    if (invert) {
      return pattern.allMatches(text).map((m) => m.group(0)!).toList();
    } else {
      return text.split(pattern).where((s) => s.isNotEmpty).toList();
    }
  }
}

class PunctuationPreTokenizer extends PreTokenizer {
  late RegExp pattern;

  PunctuationPreTokenizer(Map<String, dynamic> config) {
    pattern = RegExp(r'[^\p{P}]+|[\p{P}]+', unicode: true);
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }
}

class DigitsPreTokenizer extends PreTokenizer {
  late RegExp pattern;

  DigitsPreTokenizer(Map<String, dynamic> config) {
    bool individualDigits = config['individual_digits'] ?? false;
    String digitPattern = r'[^\d]+|\d' + (individualDigits ? '' : '+');
    pattern = RegExp(digitPattern, unicode: true);
  }

  @override
  List<String> preTokenizeText(String text, [Map<String, dynamic>? options]) {
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }
}

abstract class Decoder {
  final Map<String, dynamic> config;
  List<AddedToken> addedTokens = [];
  String? endOfWordSuffix;
  bool trimOffsets;

  Decoder(this.config) : trimOffsets = config['trim_offsets'] ?? false;

  /// Creates a decoder instance based on the provided configuration.
  static Decoder fromConfig(Map<String, dynamic> config) {
    switch (config['type']) {
      case 'ByteLevel':
        return ByteLevelDecoder(config);
      default:
        throw ArgumentError('Unknown Decoder type: ${config['type']}');
    }
  }

  /// Calls the `decode` method.
  String call(List<String> tokens) => decode(tokens);

  /// Decodes a list of tokens.
  String decode(List<String> tokens) => decodeChain(tokens).join();

  /// Apply the decoder to a list of tokens.
  List<String> decodeChain(List<String> tokens) {
    throw UnimplementedError(
        '`decodeChain` should be implemented in subclass.');
  }
}

class ByteLevelDecoder extends Decoder {
  late final Map<String, int> byteDecoder;
  late final Utf8Decoder textDecoder;

  ByteLevelDecoder(super.config) {
    byteDecoder = UNICODE_TO_BYTES; // Assuming this is defined elsewhere
    textDecoder = const Utf8Decoder(allowMalformed: true);
    endOfWordSuffix = null;
  }

  String convertTokensToString(List<String> tokens) {
    final text = tokens.join();
    final byteArray =
        Uint8List.fromList(text.split('').map((c) => byteDecoder[c]!).toList());
    return textDecoder.convert(byteArray);
  }

  @override
  List<String> decodeChain(List<String> tokens) {
    final subTexts = <String>[];
    var currentSubText = <String>[];

    for (final token in tokens) {
      if (addedTokens.any((t) => t.content == token)) {
        if (currentSubText.isNotEmpty) {
          subTexts.add(convertTokensToString(currentSubText));
          currentSubText = [];
        }
        subTexts.add(token);
      } else {
        currentSubText.add(token);
      }
    }

    if (currentSubText.isNotEmpty) {
      subTexts.add(convertTokensToString(currentSubText));
    }

    return subTexts;
  }
}

class AddedToken {
  final String content;
  final int id;
  final bool singleWord;
  final bool lstrip;
  final bool rstrip;
  final bool special;
  final bool? normalized;

  AddedToken({
    required this.content,
    required this.id,
    this.singleWord = false,
    this.lstrip = false,
    this.rstrip = false,
    this.normalized = false,
    this.special = false,
  });
}

Map<String, int> reverseDictionary(Map<int, dynamic> data) {
  return Map.fromEntries(
    data.entries.map((entry) => MapEntry(entry.value.toString(), entry.key)),
  );
}

final Map<int, String> BYTES_TO_UNICODE = (() {
  // Returns list of utf-8 byte and a mapping to unicode strings.
  // We specifically avoid mapping to whitespace/control characters
  // the bpe code barfs on.
  final List<int> bs = [
    ...List.generate('~'.codeUnitAt(0) - '!'.codeUnitAt(0) + 1,
        (i) => i + '!'.codeUnitAt(0)),
    ...List.generate('¬'.codeUnitAt(0) - '¡'.codeUnitAt(0) + 1,
        (i) => i + '¡'.codeUnitAt(0)),
    ...List.generate('ÿ'.codeUnitAt(0) - '®'.codeUnitAt(0) + 1,
        (i) => i + '®'.codeUnitAt(0)),
  ];

  final List<int> cs = List.from(bs);
  int n = 0;

  for (int b = 0; b < 256; ++b) {
    if (!bs.contains(b)) {
      bs.add(b);
      cs.add(256 + n);
      n += 1;
    }
  }

  final List<String> ccs = cs.map((n) => String.fromCharCode(n)).toList();
  return Map.fromIterables(bs, ccs);
})();

final Map<String, int> UNICODE_TO_BYTES = reverseDictionary(BYTES_TO_UNICODE);

class PreTrainedTokenizer {
  late Map<String, dynamic> tokenizerJSON;
  late Map<String, dynamic> tokenizerConfig;

  late Normalizer normalizer;
  late PreTokenizer pre_tokenizer;
  late TokenizerModel model;
  late Decoder decoder;

  static String START_STR = "<|startoftext|>";
  static String END_STR = "<|endoftext|>";
  static int START_INT = 49406;
  static int END_INT = 49407;

  static int maxLength = 77;

  Future<void> readFromFiles(String jsonPath, String configPath) async {
    try {
      await FileLogger.log("Starting to read tokenizer files");
      // tokenizerJSON = await AssetManager.getJsonAsset(jsonPath);
      tokenizerJSON = await jsonDecode(await rootBundle.loadString(jsonPath));
      await FileLogger.log("Tokenizer JSON loaded successfully");

      // Uncomment and modify if you need the config file as well
      // final tokenizerConfig = await AssetManager.getJsonAsset(configPath);
      // await FileLogger.log("Tokenizer config loaded successfully");

      normalizer = Normalizer.fromConfig(tokenizerJSON['normalizer']);
      pre_tokenizer = PreTokenizer.fromConfig(tokenizerJSON['pre_tokenizer']);
      model = TokenizerModel.fromConfig(tokenizerJSON["model"]);
      decoder = Decoder.fromConfig(tokenizerJSON['decoder']);

      await FileLogger.log("Tokenizer components initialized successfully");
    } catch (e, stackTrace) {
      await FileLogger.log("Error reading tokenizer files: $e");
      await FileLogger.log("Stack trace: $stackTrace");
      rethrow;
    }
  }

  List<int> encodeText(String text,
      {bool insert_special = true, bool padding = true}) {
    String normalizedText = normalizer.normalize(text);
    List<String> tokens = pre_tokenizer.preTokenizeText(normalizedText);
    List<int> real_tokens = model.encode(tokens);
    if (real_tokens.length > maxLength - 2) {
      real_tokens = real_tokens.sublist(0, maxLength - 2);
    }
    if (insert_special) {
      real_tokens.insert(0, START_INT); // "<|startoftext|>"
      real_tokens.add(END_INT); // "<|endoftext|>"
    }

    if (padding && real_tokens.length < maxLength) {
      real_tokens = real_tokens +
          List.filled(
            maxLength - real_tokens.length,
            0,
          );
    }
    return real_tokens;
  }

  List<String> encodeTextDisplay(String text) {
    String normalizedText = normalizer.normalize(text);
    List<String> tokens = pre_tokenizer.preTokenizeText(normalizedText);
    List<int> real_tokens = model.encode(tokens);
    var decoded_tokens = model
        .convertIdsToTokens(real_tokens)
        .map((text) => text.replaceAll("</w>", ""));
    return decoded_tokens.toList();
  }

  String decodeTokens(List<int> tokens, {bool remove_special = true}) {
    if (remove_special) {
      tokens.removeAt(0);
      tokens.removeLast();
    }
    var decoded_tokens = model.convertIdsToTokens(tokens);
    var decoded_string = decoder.decode(decoded_tokens).replaceAll("</w>", " ");
    var cleaned_string = cleanUpTokenization(decoded_string);
    return cleaned_string;
  }
}

int getTokenizedLength(
  String text,
  PreTrainedTokenizer tokenizer,
) {
  List tokenizedText = tokenizer.encodeTextDisplay(text);
  print(tokenizedText.toString());
  return tokenizedText.length;
}

// Future<void> main() async {
//   const String jsonPath = "assets/models/mobileclip_s0/tokenizer.json";
//   String text =
//       "In the heart of a dense forest, a quick brown fox named Reynar";

//   PreTrainedTokenizer tokenizer = PreTrainedTokenizer();
//   await tokenizer.readFromFiles(jsonPath, configPath);

//   tokenizer.encodeText(text);
// }
