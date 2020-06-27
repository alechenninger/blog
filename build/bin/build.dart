import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:build_blog/build.dart';
import 'package:file/src/interface/directory.dart';
import 'package:file/src/interface/file.dart';
import 'package:markdown/markdown.dart';
import 'package:file/local.dart';
import 'package:path/path.dart';
import 'package:cli_util/cli_logging.dart';
import 'dart:async';

import 'dart:io';

void main(List<String> arguments) async {
  var runner = CommandRunner('build_blog', 'builds posts under posts/')
      ..addCommand(Build())
      ..addCommand(Watch());

  await runner.run(arguments);
}

class Build extends Command<void> {
  @override
  String get description => 'builds the blog';

  @override
  String get name => 'build';

  @override
  FutureOr<void> run() async {
    var fs = LocalFileSystem();
    var posts = fs.directory('posts');
    var logger = Logger.standard();
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
    var fs = LocalFileSystem();
    var posts = fs.directory('posts');
    var logger = Logger.standard();
    var out = await prepareOut(fs);
    var progress = logger.progress('Watching posts/');

    Future<void> handleModify(FileSystemModifyEvent event) async {
      if (!event.contentChanged) return;
      progress.finish(message: '${event.path} changed, rendering...');
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

Future<File> render(File post, Directory out) async {
  var name = basenameWithoutExtension(post.path);
  var contents = await post.readAsString();

  var html = isMarkdown(post)
      ? blogMarkdownToHtml(contents, extensionSet: blogExtensionSet)
      : contents;

  var builtPost = out.childFile('$name.html');

  await builtPost.writeAsString(html);
  return builtPost;
}
