import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:blogtool/build.dart';
import 'package:blogtool/blog.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:file/local.dart';
import 'package:file/src/interface/directory.dart';
import 'package:file/src/interface/file.dart';
import 'package:googleapis/blogger/v3.dart' show BloggerApi;
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart';
import 'package:pedantic/pedantic.dart';

var fs = LocalFileSystem();
var posts = fs.directory('posts');
var logger = Logger.standard();
var closeEm = [];

void main(List<String> arguments) async {
  var runner = CommandRunner('build_blog', 'builds posts under posts/')
    ..addCommand(StartPost())
    ..addCommand(Build())
    ..addCommand(Watch())
    ..addCommand(Preview())
    ..addCommand(Lookup())
    ..addCommand(Publish());

  await runner.run(arguments);

  closeEm.reversed.forEach((it) => it.close());
}

class StartPost extends Command<void> {
  @override
  String get description =>
      'starts a new post with empty metadata tags for editing';

  @override
  String get name => 'start';

  @override
  FutureOr<void> run() async {
    if (argResults.rest.isEmpty) {
      throw ArgumentError('must pass post filename');
    }

    var postFileName = argResults.rest[0];

    if (RegExp(r'.*[\s-/\\=+()*&^%$#@!]+.*').hasMatch(postFileName)) {
      throw ArgumentError.value(postFileName, 'post name',
          'must only contain characters numbers and _');
    }

    var post = fs.directory('posts').childFile(postFileName);
    if (await post.exists()) {
      throw ArgumentError.value(
          postFileName, 'post name', 'post already exists with that name');
    }
    await post.writeAsString('''<meta name="labels" content="">
<meta name="title" content="">
<meta name="description" content="">

''');
    logger.stdout('${post.path} prepared for editing');
  }
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

      built.add(builtPost.htmlPath);
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

  @override
  String get description => 'uploads post as draft and provides preview url';

  @override
  String get name => 'preview';

  @override
  FutureOr<void> run() async {
    _blog = await loadBlog();

    if (argResults.rest.isEmpty) {
      throw ArgumentError('Must provide path to post as argument');
    }

    var post = fs.file(argResults.rest[0]);
    var out = await prepareOut(fs);

    var rendered = await render(post, out);
    await uploadDraft(_blog, rendered);

    var progress = logger.progress('Watching $post for changes');

    Future<void> handleModify(FileSystemModifyEvent event) async {
      if (!event.contentChanged) return;
      progress.finish(message: '${event.path} changed');
      var rendered = await render(post, out);
      logger.stderr('${rendered} updated');
      await uploadDraft(_blog, rendered);
    }

    await for (var event in post.watch()) {
      if (event is FileSystemModifyEvent) {
        await handleModify(event);
      }

      progress = logger.progress('Watching $post for changes');
    }
  }
}

class Publish extends Command<void> {
  @override
  String get description => 'publishes post and provides published url';

  @override
  String get name => 'publish';

  @override
  FutureOr<void> run() async {
    var post = fs.file(argResults.rest[0]);

    var loadingBlog = loadBlog();
    var preparingOut = prepareOut(fs);

    var blog = await loadingBlog;
    var out = await preparingOut;
    var rendered = await render(post, out);

    var result = await uploadDraft(blog, rendered);
    await blog.publishPost(result.id);
  }
}

class Lookup extends Command<void> {
  @override
  String get description => 'looks up JSON for a post by ID';

  @override
  String get name => 'lookup';

  @override
  FutureOr<void> run() async {
    var blog = await loadBlog();
    var id = argResults.rest[0];
    var post = await blog.lookupPost(id);
    var encoder = JsonEncoder.withIndent('  ');
    logger.stdout(encoder.convert(post.toJson()));
  }
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

  var html = isMarkdown(post) ? blogMarkdownToHtml(contents) : contents;

  var builtPost = out.childFile('$name.html');

  await builtPost.writeAsString(html, flush: true);

  return BuiltPost(post, builtPost, contents, html);
}

Future<PostResult> uploadDraft(Blog blog, BuiltPost builtPost) async {
  var progress = logger.progress('Uploading draft');
  var rendered = RenderedPost(builtPost.htmlContent);

  PostResult result;

  if (!rendered.isNewPost) {
    result = await blog.updatePost(rendered);

    progress.finish(message: 'Done!', showTiming: true);

    logger.stdout('Preview your post here: ${result.previewUrl}');
  } else {
    result = await blog.startNewPost(post: rendered);

    progress.finish(message: 'Done!', showTiming: true);

    await builtPost.originalFile
        .writeAsString('''<meta name="id" content="${result.id}">
${builtPost.originalContent}''', flush: true);

    logger.stdout('Preview your post here: ${result.previewUrl}');
  }

  return result;
}

// TODO: BuiltPost and RenderedPost should be combined
class BuiltPost {
  final File originalFile;
  final File htmlFile;
  final String originalContent;
  final String htmlContent;
  String get originalPath => originalFile.path;
  @deprecated
  String get path => htmlPath;
  String get htmlPath => htmlFile.path;

  const BuiltPost(
      this.originalFile, this.htmlFile, this.originalContent, this.htmlContent);

  RenderedPost toRenderedPost() => RenderedPost(htmlContent);
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
