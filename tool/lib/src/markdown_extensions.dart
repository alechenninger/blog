import 'package:charcode/charcode.dart';
import 'package:markdown/markdown.dart';

final blogExtensionSet = ExtensionSet([
  AsideBlockSyntax(),
  FootnoteSyntax(),
  DefinitionListSyntax(),
  ...ExtensionSet.gitHubWeb.blockSyntaxes
], [
  VariableSyntax(),
  DefinitionSyntax(),
  FootnoteLinkSyntax(),
  ...ExtensionSet.gitHubWeb.inlineSyntaxes
]);

// Adapted from BlockquoteSyntax
class AsideBlockSyntax extends BlockSyntax {
  /// Matches // with a space and some optional text, or just a lone pair of /.
  /// If a line starts with // and immediately some text (e.g. //foo), it will not
  /// be considered an aside.
  // TODO: consider using /// to start aside, and // as a new paragraph in same
  //  aside.
  static final _pattern = RegExp(r'^[ ]{0,3}// ?((.*)|)$');

  @override
  RegExp get pattern => _pattern;

  const AsideBlockSyntax();

  @override
  List<String> parseChildLines(BlockParser parser) {
    // Grab all of the lines that form the aside, stripping off the "//".
    var childLines = <String>[];

    while (!parser.isDone) {
      var match = pattern.firstMatch(parser.current);
      if (match != null) {
        childLines.add(match[1]);
        parser.advance();
        continue;
      }

      // A paragraph continuation is OK. This is content that cannot be parsed
      // as any other syntax except Paragraph, and it doesn't match the bar in
      // a Setext header.
      if (parser.blockSyntaxes.firstWhere((s) => s.canParse(parser))
          is ParagraphSyntax) {
        childLines.add(parser.current);
        parser.advance();
      } else {
        break;
      }
    }

    return childLines;
  }

  @override
  Node parse(BlockParser parser) {
    var childLines = parseChildLines(parser);

    // Recursively parse the contents of the aside.
    var children = BlockParser(childLines, parser.document).parseLines();

    if (children.isNotEmpty) {
      if (children[0] is Element) {
        var firstEl = children[0] as Element;
        if (firstEl.tag.toLowerCase() == 'p') {
          children.removeAt(0);
          children.insertAll(0, firstEl.children);
        }
      }
    }

    return Element('aside', children);
  }
}

class VariableSyntax extends InlineSyntax {
  VariableSyntax() : super(r'{(\w+)}', startCharacter: $open_brace);

  @override
  bool onMatch(InlineParser parser, Match match) {
    var variable = match[1];
    parser.addNode(Element.text('var', variable));
    return true;
  }
}

class DefinitionSyntax extends InlineSyntax {
  DefinitionSyntax() : super(r'{{([\w ]+)}}', startCharacter: $open_brace);

  @override
  bool onMatch(InlineParser parser, Match match) {
    var term = match[1];
    parser.addNode(Element.text('dfn', term));
    return true;
  }
}


class DefinitionListSyntax extends BlockSyntax {
  /// Matches a line that ends with colon.
  static final _termPattern = RegExp(r'^[ ]{0,3}([^\s].*):[ ]*$');
  static final _definitionPattern = RegExp(r'^[ ]{2,3}([^\s].*)$');

  @override
  RegExp get pattern => _termPattern;

  @override
  Node parse(BlockParser parser) {
    var children = <Node>[];

    while (!parser.isDone) {
      if (parser.current.trim().isEmpty) {
        parser.advance();
        continue;
      }

      var match = _termPattern.firstMatch(parser.current);
      if (match == null) {
        break;
      }

      var term = InlineParser(match[1], parser.document).parse();
      children.add(Element('dt', term));

      parser.advance();

      var definitionLines = <String>[];
      while (!parser.isDone) {
        var match = _definitionPattern.firstMatch(parser.current);
        if (match != null) {
          definitionLines.add(match[1]);
          parser.advance();
          continue;
        }

        if (parser.current.trim().isEmpty ||
            parser.blockSyntaxes.firstWhere((s) => s.canParse(parser))
                is ParagraphSyntax) {
          definitionLines.add(parser.current);
          parser.advance();
        } else {
          break;
        }
      }

      var definition =
          BlockParser(definitionLines, parser.document).parseLines();
      children.add(Element('dd', definition));
    }

    return Element('dl', children);
  }

  @override
  bool canParse(BlockParser parser) {
    return super.canParse(parser) && _definitionPattern.hasMatch(parser.next);
  }
}

class FootnoteLinkSyntax extends InlineSyntax {
  FootnoteLinkSyntax() : super(r'\^\[(\d+)\]');

  @override
  bool onMatch(InlineParser parser, Match match) {
    var note = match[1];
    var link = Element('sup',
        [Element.text('a', note)..attributes['href'] = '#${idFor(note)}']);
    link.attributes['id'] = 'note-$note-link';
    parser.addNode(link);
    return true;
  }

  static String idFor(note) => 'note-$note';
  static String linkIdFor(note) => 'note-$note-link';
}

class FootnoteSyntax extends BlockSyntax {
  static final _pattern = RegExp(r'^\^(\d+):[ ]*(.*)$');
  static final _continuationPattern = RegExp(r'^\^[ ]*(.*)$');

  @override
  RegExp get pattern => _pattern;

  @override
  bool canParse(BlockParser parser) {
    return super.canParse(parser);
  }

  @override
  Node parse(BlockParser parser) {
    var start = pattern.firstMatch(parser.current);
    if (start == null) throw ArgumentError();
    var number = start[1];

    var lines = <String>[];
    lines.add(start[2]);

    parser.advance();

    while (!parser.isDone) {
      if (pattern.hasMatch(parser.current)) break;

      var match = _continuationPattern.firstMatch(parser.current);
      if (match != null) {
        lines.add(match[1]);
        parser.advance();
        continue;
      }

      if (parser.current.trim().isEmpty ||
          parser.blockSyntaxes.firstWhere((s) => s.canParse(parser))
          is ParagraphSyntax) {
        lines.add(parser.current);
        parser.advance();
      } else {
        break;
      }
    }

    var content = BlockParser(lines, parser.document).parseLines();
    var smallContent = <Node>[];
    var first = true;
    var annotation = Element('sup', [
      Element.text('a', number)
        ..attributes['href'] = '#${FootnoteLinkSyntax.linkIdFor(number)}'
        ..attributes['id'] = FootnoteLinkSyntax.idFor(number)
    ]);

    // Make each content node small
    for (var node in content) {
      if (node is! Element) {
        // not sure about this
        throw ArgumentError('expected Element node but got $node');
      }

      var el = node as Element;
      var smalled = Element(el.tag, [
        Element('small', [
          if (first) ...[annotation, Text('&nbsp;')],
          ...el.children
        ])
      ]);
      smallContent.add(smalled);

      if (first) {
        first = false;
      }
    }

    return FootnoteNodes(smallContent);
  }
}

class FootnoteNodes extends Element {
  final List<Node> _children;

  FootnoteNodes(this._children) : super(null, _children);

  @override
  void accept(NodeVisitor visitor) {
    _children.forEach((child) => child.accept(visitor));
  }
}
