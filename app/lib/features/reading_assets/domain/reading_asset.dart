enum ReadingAssetKind { highlightOnly, linkedNote, standaloneNote }

class TextAnchor {
  const TextAnchor({
    required this.id,
    required this.assetId,
    required this.articleId,
    required this.startBlockId,
    required this.endBlockId,
    required this.startUtf16Offset,
    required this.endUtf16Offset,
    required this.selectedText,
    required this.contentChecksum,
  });

  final String id;
  final String assetId;
  final String articleId;
  final String startBlockId;
  final String endBlockId;
  final int startUtf16Offset;
  final int endUtf16Offset;
  final String selectedText;
  final String contentChecksum;
}

class Tag {
  const Tag({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.isSystem,
  });

  final String id;
  final String ownerId;
  final String name;
  final bool isSystem;
}

class ReadingAsset {
  const ReadingAsset({
    required this.id,
    required this.ownerId,
    required this.anchor,
    required this.noteContent,
    required this.tags,
  });

  final String id;
  final String ownerId;
  final TextAnchor? anchor;
  final String? noteContent;
  final List<Tag> tags;

  ReadingAssetKind get kind =>
      deriveReadingAssetKind(anchor: anchor, noteContent: noteContent);
}

ReadingAssetKind deriveReadingAssetKind({
  required TextAnchor? anchor,
  required String? noteContent,
}) {
  final hasNote = noteContent?.trim().isNotEmpty ?? false;

  if (anchor != null) {
    return hasNote
        ? ReadingAssetKind.linkedNote
        : ReadingAssetKind.highlightOnly;
  }
  if (hasNote) {
    return ReadingAssetKind.standaloneNote;
  }

  throw ArgumentError('A reading asset requires an anchor or note content.');
}
