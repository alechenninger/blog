import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:blogtool/build.dart';
import 'package:blogtool/publish.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:file/local.dart';
import 'package:file/src/interface/directory.dart';
import 'package:file/src/interface/file.dart';
import 'package:googleapis/blogger/v3.dart' show BloggerApi;
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart';

var fs = LocalFileSystem();
var posts = fs.directory('posts');
var logger = Logger.standard();
var closeEm = [];

void main(List<String> arguments) async {
  var runner = CommandRunner('build_blog', 'builds posts under posts/')
    ..addCommand(Build())
    ..addCommand(Watch())
    ..addCommand(Preview());

  await runner.run(arguments);

  closeEm.reversed.forEach((it) => it.close());
}

class Build extends Command<void> {
  @override
  String get description => 'builds the blog';

  @override
  String get name => 'build';

  @override
  FutureOr<void> run() async {
    var progress = logger.progress('Clearing output directory');

    var out = await prepareOut(fs, clear: true);

    progress.finish();
    progress = logger.progress('Rendering markdown posts to html');
    var built = [];

    await for (var entity in posts.list()) {
      if (entity is! File) continue;
      var post = entity as File;
      var builtPost = await render(post, out);

      built.add(builtPost.path);
    }

    progress.finish(message: '${built}');
  }
}

class Watch extends Command<void> {
  @override
  String get description => 'builds posts as they are updated';

  @override
  FutureOr<void> run() async {
    var out = await prepareOut(fs);
    var progress = logger.progress('Watching posts/');

    Future<void> handleModify(FileSystemModifyEvent event) async {
      if (!event.contentChanged) return;
      progress.finish(message: '${event.path} changed');
      var post = await fs.file(event.path);
      var rendered = await render(post, out);
      logger.stderr('${rendered} updated');
    }

    await for (var event in posts.watch()) {
      if (event.path.endsWith('~')) continue;

      if (event is FileSystemModifyEvent) {
        await handleModify(event);
      }

      progress = logger.progress('Watching posts/');
    }
  }

  @override
  String get name => 'watch';
}

class Preview extends Command<void> {
  Blog _blog;

  Preview();

  @override
  String get description => 'uploads post as draft and provides preview url';

  @override
  String get name => 'preview';

  @override
  FutureOr<void> run() async {
    _blog = await loadBlog();

    var progress = logger.progress('Clearing output directory');

    var out = await prepareOut(fs, clear: true);

    progress.finish();
    progress = logger.progress('Rendering markdown posts to html');
    var built = [];

    var post = fs.file(argResults.rest[0]);
    var builtPost = await render(post, out);

    built.add(builtPost.path);

    progress.finish(message: '${built}');

    progress = logger.progress('Uploading draft');

    var rendered = RenderedPost(builtPost.htmlContent);

    if (!rendered.isNewPost) {
      var result = await _blog.updatePost(rendered);

      progress.finish(message: 'Done!', showTiming: true);

      logger.stdout('Preview your post here: ${result.previewUrl}');
    } else {
      var result = await _blog.startNewPost(post: rendered);

      progress.finish(message: 'Done!', showTiming: true);

      await post.writeAsString('''<meta name="id" content="${result.id}">
${builtPost.originalContent}''',
          flush: true);

      logger.stdout('Preview your post here: ${result.previewUrl}');
    }
  }
}

class Publish extends Command<void> {
  final Blog _blog;

  Publish(this._blog);

  @override
  String get description => 'publishes post and provides published url';

  @override
  String get name => 'publish';

  @override
  FutureOr<void> run() async {}
}

bool isMarkdown(File file) =>
    ['.md', '.markdown'].contains(extension(file.path));

Future<Directory> prepareOut(LocalFileSystem fs, {bool clear = false}) async {
  var out = await fs.directory('out/posts');

  if (!await out.exists()) {
    await out.create(recursive: true);
  } else if (clear) {
    await for (var entity in out.list(recursive: true)) {
      await entity.delete(recursive: true);
    }
  }

  return out;
}

Future<BuiltPost> render(File post, Directory out) async {
  var name = basenameWithoutExtension(post.path);
  var contents = await post.readAsString();

  var html = isMarkdown(post)
      ? blogMarkdownToHtml(contents, extensionSet: blogExtensionSet)
      : contents;

  var builtPost = out.childFile('$name.html');

  await builtPost.writeAsString(html, flush: true);

  return BuiltPost(builtPost, contents, html);
}

class BuiltPost {
  final File file;
  final String originalContent;
  final String htmlContent;
  String get path => file.path;

  const BuiltPost(this.file, this.originalContent, this.htmlContent);
}

Future<Blog> loadBlog() async {
  var file = fs.file('client.json');
  var clientJson = await file.readAsString();
  var clientInfo = jsonDecode(clientJson);
  var clientId = ClientId(clientInfo['id'], clientInfo['secret']);

  AutoRefreshingAuthClient httpClient;

  if (clientInfo['refreshToken'] == null) {
    httpClient = await clientViaUserConsent(clientId, [BloggerApi.BloggerScope],
        (uri) => logger.stdout('Please login via $uri'));
  } else {
    var accessToken = AccessToken(
        clientInfo['accessToken']['type'],
        clientInfo['accessToken']['data'],
        DateTime.parse(clientInfo['accessToken']['expiry']));
    var credentials = AccessCredentials(
        accessToken, clientInfo['refreshToken'], [BloggerApi.BloggerScope]);

    var client = Client();
    closeEm.add(client);

    httpClient = autoRefreshingClient(clientId, credentials, client);
  }

  closeEm.add(httpClient);

  var credentials = httpClient.credentials;
  var accessToken = credentials.accessToken;

  clientInfo['accessToken'] = {
    'type': accessToken.type,
    'data': accessToken.data,
    'expiry': accessToken.expiry.toIso8601String()
  };
  clientInfo['refreshToken'] = credentials.refreshToken;

  var encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(clientInfo), flush: true);

  return Blog.withClient(httpClient);
}
