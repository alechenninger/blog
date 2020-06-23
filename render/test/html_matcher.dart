import 'package:test/test.dart';
import 'package:xml/xml.dart';

Matcher sameHtmlAs(String expected) {
  return _HtmlMatcher(expected);
}

class _HtmlMatcher extends Matcher {
  final XmlDocument _expected;

  _HtmlMatcher(String html) : _expected = XmlDocument.parse(html);

  @override
  Description describe(Description description) {
    description.add(
        'html semantically equivalent to ${_expected.toCanonicalString()}');
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    return equals(_expected.toCanonicalString()).describeMismatch(
        _canonicalizeHtml(item), mismatchDescription, matchState, verbose);
  }

  @override
  bool matches(item, Map<dynamic, dynamic> matchState) {
    return _canonicalizeHtml(item) == _expected.toCanonicalString();
  }

  String _canonicalizeHtml(String html) =>
      XmlDocument.parse(html).toCanonicalString();
}

extension _Canonicalize on XmlDocument {
  String toCanonicalString() =>
      toXmlString(pretty: true, preserveWhitespace: (_) => false);
}
