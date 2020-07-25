import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:markdown/markdown.dart';

import 'src/markdown_extensions.dart';

export 'src/markdown_extensions.dart';

/// From markdownToHtml, but recognizes more block tags, and other blog-specific
/// extensions.
String blogMarkdownToHtml(String markdown) {
  var document = Document(
    extensionSet: blogExtensionSet,
  );

  // Replace windows line endings with unix line endings, and split.
  var lines = markdown.replaceAll('\r\n', '\n').split('\n');

  var rendered =
      _HtmlRendererWithMoreBlocks().render(document.parseLines(lines)) + '\n';

  return _postProcessHtml(rendered);
}

String _postProcessHtml(String rendered) {
  var html = parseFragment(rendered);

  _openExternalLinksInNewTab(html);

  return html.outerHtml;
}

void _openExternalLinksInNewTab(dom.DocumentFragment html) {
  for (var anchor in html.querySelectorAll('a')) {
    var href = anchor.attributes['href'];
    if (href.startsWith('https://') || href.startsWith('http://')) {
      anchor.attributes['target'] = '_blank';
      anchor.attributes['rel'] = 'noreferrer noopener';
    }
  }
}

const _blockTags = [
  'blockquote',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'li',
  'ol',
  'p',
  'pre',
  'ul',
  'aside'
];

/// From HtmlRenderer, but recognizes more block tags.
class _HtmlRendererWithMoreBlocks implements NodeVisitor {
  StringBuffer buffer;
  Set<String> uniqueIds;

  final _elementStack = <Element>[];
  String _lastVisitedTag;

  _HtmlRendererWithMoreBlocks();

  String render(List<Node> nodes) {
    buffer = StringBuffer();
    uniqueIds = <String>{};

    for (final node in nodes) {
      node.accept(this);
    }

    return buffer.toString();
  }

  @override
  void visitText(Text text) {
    var content = text.text;
    if (const ['p', 'li'].contains(_lastVisitedTag)) {
      var lines = LineSplitter.split(content);
      content = content.contains('<pre>')
          ? lines.join('\n')
          : lines.map((line) => line.trimLeft()).join('\n');
      if (text.text.endsWith('\n')) {
        content = '$content\n';
      }
    }
    buffer.write(content);

    _lastVisitedTag = null;
  }

  @override
  bool visitElementBefore(Element element) {
    // Hackish. Separate block-level elements with newlines.
    if (buffer.isNotEmpty && _blockTags.contains(element.tag)) {
      buffer.writeln();
    }

    buffer.write('<${element.tag}');

    for (var entry in element.attributes.entries) {
      buffer.write(' ${entry.key}="${entry.value}"');
    }

    // attach header anchor ids generated from text
    if (element.generatedId != null) {
      buffer.write(' id="${uniquifyId(element.generatedId)}"');
    }

    _lastVisitedTag = element.tag;

    if (element.isEmpty) {
      // Empty element like <hr/>.
      buffer.write(' />');

      if (element.tag == 'br') {
        buffer.write('\n');
      }

      return false;
    } else {
      _elementStack.add(element);
      buffer.write('>');
      return true;
    }
  }

  @override
  void visitElementAfter(Element element) {
    assert(identical(_elementStack.last, element));

    if (element.children != null &&
        element.children.isNotEmpty &&
        _blockTags.contains(_lastVisitedTag) &&
        _blockTags.contains(element.tag)) {
      buffer.writeln();
    } else if (element.tag == 'blockquote') {
      buffer.writeln();
    }
    buffer.write('</${element.tag}>');

    _lastVisitedTag = _elementStack.removeLast().tag;
  }

  /// Uniquifies an id generated from text.
  String uniquifyId(String id) {
    if (!uniqueIds.contains(id)) {
      uniqueIds.add(id);
      return id;
    }

    var suffix = 2;
    var suffixedId = '$id-$suffix';
    while (uniqueIds.contains(suffixedId)) {
      suffixedId = '$id-${suffix++}';
    }
    uniqueIds.add(suffixedId);
    return suffixedId;
  }
}
