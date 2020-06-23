import 'package:charcode/charcode.dart';
import 'package:markdown/markdown.dart';

// Adapted from BlockquoteSyntax
class AsideBlockSyntax extends BlockSyntax {
  /// Matches // with a space and some optional text, or just a lone pair of /.
  /// If a line starts with // and immediately some text (e.g. /foo), it will not
  /// be considered an aside.
  static final _pattern = RegExp(r'^[ ]{0,3}//( (.*)|)$');

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

class FootnoteSyntax {}
