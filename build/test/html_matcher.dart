import 'package:test/test.dart';
import 'package:xml/xml.dart';

Matcher sameHtmlAs(String expected) {
  return _HtmlMatcher(expected);
}

class _HtmlMatcher extends Matcher {
  final String _expected;

  _HtmlMatcher(String html) : _expected = _normalizeHtml(html);

  @override
  Description describe(Description description) {
    description.add(
        'html semantically equivalent to ${_expected}');
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    return equals(_expected).describeMismatch(
        _normalizeHtml(item), mismatchDescription, matchState, verbose);
  }

  @override
  bool matches(item, Map<dynamic, dynamic> matchState) {
    return _normalizeHtml(item) == _expected;
  }

  static String _normalizeHtml(String html) =>
      XmlDocument.parse('<normalized>$html</normalized>').toNormalizedString();
}

extension _Normalize on XmlHasWriter {
  String toNormalizedString() =>
      toXmlString(pretty: true, preserveWhitespace: (_) => false);
}
