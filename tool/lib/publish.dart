import 'package:googleapis/blogger/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';
import 'package:html/parser.dart';

export 'package:http/http.dart' show Client;

const _scopes = [BloggerApi.BloggerScope];
const blogId = '2329797559500355970';
final _myBlog = PostBlog()..id = blogId;

class PostResult {
  final String id;
  final String url;
  String get previewUrl =>
      'https://draft.blogger.com/blog/post/edit/preview/$blogId/$id';

  const PostResult(this.id, this.url);
}

class Blog {
  BloggerApi _api;

  Blog(this._api);

  Blog.withClient(Client client): this(BloggerApi(client));

  static Future<Blog> production(ServiceAccountCredentials credentials) async {
    var client = await clientViaServiceAccount(credentials, _scopes);
    return Blog(BloggerApi(client));
  }

  /// Returns id of new post, in draft state.
  Future<PostResult> startNewPost({RenderedPost post}) async {
    var request;

    if (post != null) {
      if (!post.isNewPost) throw ArgumentError('post should be new but is not');

      var duplicates = await _api.posts.search(blogId, post.title);
      // Does not paginate, but shouldn't need to go that deep to find a
      // duplicate...
      if (duplicates.items != null) {
        for (var duplicate in duplicates.items) {
          if (duplicate.title == post.title) {
            throw StateError(
                'There is already a post with title ${post.title}');
          }
        }
      }

      request = _toApiPost(post);
    } else {
      request = Post()
        ..blog = _myBlog
        ..kind = _Kinds.post
        ..title = 'untitled';
    }

    var response = await _api.posts.insert(request, blogId, isDraft: true);

    return PostResult(response.id, response.url);
  }

  Future<PostResult> updatePost(RenderedPost post) async {
    if (post.id == null) {
      throw ArgumentError.notNull('post.id');
    }

    var request = _toApiPost(post);
    var response = await _api.posts.update(request, blogId, post.id);

    return PostResult(response.id, response.url);
  }

  Future<void> publishPost(RenderedPost post) async {
    if (post.id == null) {
      throw ArgumentError.notNull('post.id');
    }

    var response = await _api.posts.publish(blogId, post.id);

    return PostResult(response.id, response.url);
  }

  Post _toApiPost(RenderedPost post) => Post()
    ..blog = _myBlog
    ..kind = _Kinds.post
    ..content = post.htmlContent
    ..labels = post.labels
    ..title = post.title
    ..id = post.id;
}

class RenderedPost {
  final Set<String> _labels = <String>{};
  List<String> get labels => _labels.toList();
  String _title = 'untitled';
  String get title => _title;
  String _id;
  String get id => _id;
  final String _htmlContent;
  String get htmlContent => _htmlContent;
  bool get isNewPost => _id == null;

  RenderedPost(this._htmlContent) {
    var html = parse(_htmlContent);
    for (var metadata in html.getElementsByTagName('meta')) {
      var content = metadata.attributes['content'];
      switch (metadata.attributes['name']) {
        case 'labels':
          _labels.addAll(content.split(','));
          break;
        case 'title':
          _title = content;
          break;
        case 'id':
          _id = content;
      }
    }
  }
}

class _Kinds {
  static const post = 'blogger#post';
}
