import 'package:markdown/markdown.dart';
import 'package:blogtool/src/markdown_extensions.dart';
import 'package:test/test.dart';

import 'html_matcher.dart';

void main() {
  group('VariableSyntax', () {
    test('renders words in braces with var tag', () {
      var html = markdownToHtml('This {test} should pass.',
          inlineSyntaxes: [VariableSyntax()]);

      expect(html, sameHtmlAs(r'<p>This <var>test</var> should pass.</p>'));
    });

    test('renders parts of words in braces with var tag', () {
      var html = markdownToHtml('This te{st} should pass.',
          inlineSyntaxes: [VariableSyntax()]);

      expect(html, sameHtmlAs(r'<p>This te<var>st</var> should pass.</p>'));
    });

    test('does not match multiple words in braces', () {
      var html = markdownToHtml('{This test} should pass.',
          inlineSyntaxes: [VariableSyntax()]);

      expect(html, sameHtmlAs(r'<p>{This test} should pass.</p>'));
    });
  });

  group('AsideBlockSyntax', () {
    test('parses line starting with // as asides', () {
      var html = markdownToHtml('// This test should pass.',
          blockSyntaxes: [AsideBlockSyntax()]);

      expect(html, sameHtmlAs(r'<aside><p>This test should pass.</p></aside>'));
    });

    test('parses lines starting with // as asides', () {
      var html = markdownToHtml('''// This is an aside.
// And another line in the same aside.
      ''', blockSyntaxes: [AsideBlockSyntax()]);

      expect(
          html,
          sameHtmlAs(r'<aside><p>This is an aside. '
              r'And another line in the same aside.</p></aside>'));
    });

    test('parses other markup inside aside', () {
      var html = markdownToHtml('''// **This** is an aside.
// 1. With an
// 2. ordered list
//
// Cool, isn't it?
      ''', blockSyntaxes: [AsideBlockSyntax()]);

      expect(
          html,
          sameHtmlAs(r'<aside><p><strong>This</strong> is an aside.</p>'
              r'<ol><li>With an</li><li>ordered list</li></ol>'
              r"<p>Cool, isn't it?</p></aside>"));
    });
  });

  group('DefinitionListSyntax', () {
    test('parses single definition', () {
      var html = markdownToHtml(r'''Dart:
  A programming language.''', blockSyntaxes: [DefinitionListSyntax()]);

      expect(
          html,
          sameHtmlAs(
              r'<dl><dt>Dart</dt><dd><p>A programming language.</p></dd></dl>'));
    });

    test('parses multiple definitions', () {
      var html = markdownToHtml(r'''Dart:
  A programming language.

Java:
  Coffee.''', blockSyntaxes: [DefinitionListSyntax()]);

      expect(
          html,
          sameHtmlAs(r'<dl><dt>Dart</dt><dd><p>A programming language.</p></dd>'
              r'<dt>Java</dt><dd><p>Coffee.</p></dd></dl>'));
    });

    test('definitions may contain multiple paragraphs and other markup', () {
      var html = markdownToHtml(r'''Dart:
  **Dart** is a client-optimized programming language for apps on multiple 
  platforms. It is developed by [Google](https://en.wikipedia.org/wiki/Google) 
  and is used to build mobile, desktop, server, and web applications.
  
  Dart is an object-oriented, class-based, garbage-collected language with 
  C-style syntax. Dart can compile to either native code or JavaScript. It 
  supports interfaces, mixins, abstract classes, reified generics, and type 
  inference.''', blockSyntaxes: [DefinitionListSyntax()]);

      expect(
          html,
          sameHtmlAs(r'<dl><dt>Dart</dt><dd><p><strong>Dart</strong> is a '
              r'client-optimized programming language for apps on multiple '
              r'platforms. It is developed by '
              r'<a href="https://en.wikipedia.org/wiki/Google">Google</a> '
              r'and is used to build mobile, desktop, server, and web '
              r'applications.</p>'
              r'<p>Dart is an object-oriented, class-based, garbage-collected '
              r'language with C-style syntax. Dart can compile to either '
              r'native code or JavaScript. It supports interfaces, mixins, '
              r'abstract classes, reified generics, and type inference.</p>'
              r'</dd></dl>'));
    });
  });

  group('FootnoteSyntax', () {
    test('creates footnotes and links', () {
      var html = markdownToHtml(r'''This is a test^[1].

Paragraph.
      
^1: A very good test.''',
          inlineSyntaxes: [FootnoteLinkSyntax()],
          blockSyntaxes: [FootnoteSyntax()]);

      expect(
          html,
          sameHtmlAs(
              r'''<p>This is a test<sup id="note-1-link"><a href="#note-1">1
              </a></sup>.</p>

              <p>Paragraph.</p>

              <p><small><sup><a href="#note-1-link" id="note-1">1</a></sup>
              &nbsp;A very good test.</small></p>'''));
    });

    test('footnotes may be multiple lines and paragraphs', () {
      var html = markdownToHtml(r'''This is a test^[1].

Paragraph.
      
^1: A very good test,
since it tests more.
^
^ I quite like it.''',
          inlineSyntaxes: [FootnoteLinkSyntax()],
          blockSyntaxes: [FootnoteSyntax()]);

      expect(
          html,
          sameHtmlAs(
              r'''<p>This is a test<sup id="note-1-link"><a href="#note-1">1
              </a></sup>.</p>
              
              <p>Paragraph.</p>
              
              <p><small><sup><a href="#note-1-link" id="note-1">1</a></sup>
              &nbsp;A very good test, since it tests more.</small></p>
              <p><small>I quite like it.</small></p>'''));
    });

    test('footnotes span empty newlines', () {
      var html = markdownToHtml(r'''This is a test^[1].

Paragraph.
      
^1: A very good test,
since it tests more.

^ I quite like it.''',
          inlineSyntaxes: [FootnoteLinkSyntax()],
          blockSyntaxes: [FootnoteSyntax()]);

      expect(
          html,
          sameHtmlAs(
              r'''<p>This is a test<sup id="note-1-link"><a href="#note-1">1
              </a></sup>.</p>
              
              <p>Paragraph.</p>
              
              <p><small><sup><a href="#note-1-link" id="note-1">1</a></sup>
              &nbsp;A very good test, since it tests more.</small></p>
              <p><small>I quite like it.</small></p>'''));
    });

    test('footnotes may follow other footnotes', () {
      var html = markdownToHtml(r'''This^[1] is a test^[2].

Paragraph.
      
^1: A very good test,
since it tests more.
^
^ I quite like it.

^2: Another footnote. Cool!''',
          inlineSyntaxes: [FootnoteLinkSyntax()],
          blockSyntaxes: [FootnoteSyntax()]);

      expect(
          html,
          sameHtmlAs(
              r'''<p>This<sup id="note-1-link"><a href="#note-1">1</a></sup> 
              is a test
              <sup id="note-2-link"><a href="#note-2">2</a></sup>.</p>
              
              <p>Paragraph.</p>
              
              <p><small><sup><a href="#note-1-link" id="note-1">1</a></sup>
              &nbsp;A very good test, since it tests more.</small></p>
              <p><small>I quite like it.</small></p>
              
              <p><small><sup><a href="#note-2-link" id="note-2">2</a></sup>
              &nbsp;Another footnote. Cool!</small></p>'''));
    });
  });
}
