import 'package:args/args.dart';
import 'package:build_blog/build.dart';
import 'package:markdown/markdown.dart';
import 'package:file/local.dart';
import 'package:path/path.dart';
import 'package:cli_util/cli_logging.dart';

import 'dart:io';

void main(List<String> arguments) async {
  var fs = LocalFileSystem();
  var posts = fs.directory('posts');
  var logger = Logger.standard();
  var progress = logger.progress('Clearing output directory');

  var out = await fs.directory('out/posts');

  if (!await out.exists()) {
    await out.create(recursive: true);
  } else {
    await for (var entity in out.list(recursive: true)) {
      await entity.delete(recursive: true);
    }
  }

  progress.finish();
  progress = logger.progress('Rendering posts to html');
  var built = [];

  await for (var entity in posts.list()) {
    if (entity is! File) continue;
    var post = entity as File;
    var name = basenameWithoutExtension(post.path);
    var contents = await post.readAsString();
    var html = markdownToHtml(contents, extensionSet: blogExtensionSet);
    var builtPost = out.childFile('$name.html');
    await builtPost.writeAsString(html);
    built.add(builtPost.path);
  }

  progress.finish(message: '${built}');
}
