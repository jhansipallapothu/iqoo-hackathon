import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../services/config_service.dart';

class SearchResult {
  final String title;
  final String snippet;
  final String url;
  final String? favicon;

  SearchResult({
    required this.title,
    required this.snippet,
    required this.url,
    this.favicon,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'snippet': snippet,
        'url': url,
        'favicon': favicon,
      };
}

class PageContent {
  final String url;
  final String title;
  final String content;
  final DateTime fetchedAt;

  PageContent({
    required this.url,
    required this.title,
    required this.content,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'content': content,
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}

class BrowsingService {
  static final BrowsingService _instance = BrowsingService._internal();
  factory BrowsingService() => _instance;
  BrowsingService._internal();

  final ConfigService _configService = ConfigService();

  static const String _duckDuckGoHtml = 'https://html.duckduckgo.com/html/';
  static const String _duckDuckGoLite = 'https://duckduckgo.com/html/';
  static const int _requestTimeout = 10;
  static const int _maxResults = 5;
  static const int _maxContentLength = 3000;

  final http.Client _client = http.Client();

  Future<List<SearchResult>> search({
    required String query,
    int maxResults = 5,
    String region = 'wt-wt',
    String safeSearch = 'moderate',
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_duckDuckGoLite?q=$encodedQuery&kl=$region&kp=$safeSearch';

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en,ta;q=0.9',
            },
          )
          .timeout(Duration(seconds: _requestTimeout));

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      return _parseSearchResults(response.body, maxResults);
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  List<SearchResult> _parseSearchResults(String html, int maxResults) {
    final document = parse(html);
    final results = <SearchResult>[];

    final resultElements = document.querySelectorAll('.result, .results_links_deep, .web-result, [class*="result"]');

    for (final element in resultElements) {
      if (results.length >= maxResults) break;

      try {
        final titleElement = element.querySelector('h2 a, .result__title a, .result-title a, a.result__snippet');
        final snippetElement = element.querySelector('.result__snippet, .snippet, .result-snippet, [class*="snippet"]');
        final urlElement = element.querySelector('a[href^="http"]');

        String? title = titleElement?.text.trim();
        String? snippet = snippetElement?.text.trim();
        String? url = urlElement?.attributes['href'];

        if (title != null && title.isNotEmpty && url != null && url.isNotEmpty) {
          // Clean up DuckDuckGo redirect URLs
          if (url.contains('duckduckgo.com/l/?uddg=')) {
            final uri = Uri.parse(url);
            url = uri.queryParameters['uddg'] ?? url;
          }

          results.add(SearchResult(
            title: title,
            snippet: snippet ?? '',
            url: url,
          ));
        }
      } catch (e) {
        // Skip malformed results
      }
    }

    // Fallback: try generic link extraction
    if (results.isEmpty) {
      final links = document.querySelectorAll('a[href^="http"]');
      for (final link in links) {
        if (results.length >= maxResults) break;
        final href = link.attributes['href'];
        final text = link.text.trim();
        if (href != null && text.isNotEmpty && !href.contains('duckduckgo.com')) {
          results.add(SearchResult(
            title: text.length > 100 ? text.substring(0, 100) : text,
            snippet: '',
            url: href,
          ));
        }
      }
    }

    return results;
  }

  Future<PageContent?> fetchPageContent(String url) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(Duration(seconds: _requestTimeout));

      if (response.statusCode != 200) {
        return null;
      }

      return _extractPageContent(url, response.body);
    } catch (e) {
      return null;
    }
  }

  PageContent? _extractPageContent(String url, String html) {
    try {
      final document = parse(html);

      // Remove script, style, nav, footer, header, aside elements
      final elementsToRemove = document.querySelectorAll('script, style, nav, footer, header, aside, noscript, iframe, .ads, .advertisement, [class*="cookie"], [class*="popup"], [class*="modal"]');
      for (final el in elementsToRemove) {
        el.remove();
      }

      // Try to find main content
      String content = '';
      String title = document.querySelector('title')?.text.trim() ?? '';

      // Priority order for content extraction
      final contentSelectors = [
        'main',
        'article',
        '[role="main"]',
        '.content',
        '.post-content',
        '.entry-content',
        '.article-body',
        '#content',
        '.main-content',
        'body',
      ];

      for (final selector in contentSelectors) {
        final element = document.querySelector(selector);
        if (element != null) {
          content = _cleanText(element.text);
          if (content.length > 200) break;
        }
      }

      if (content.isEmpty) {
        content = _cleanText(document.body?.text ?? '');
      }

      // Truncate if too long
      if (content.length > _maxContentLength) {
        content = content.substring(0, _maxContentLength) + '...';
      }

      if (content.length < 50) return null;

      return PageContent(
        url: url,
        title: title,
        content: content,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n'), '\n')
        .trim();
  }

  Future<String> searchAndSummarize({
    required String query,
    int maxResults = 3,
    int maxPagesToFetch = 2,
  }) async {
    try {
      final results = await search(query: query, maxResults: maxResults);
      if (results.isEmpty) {
        return 'No search results found for: $query';
      }

      final pages = <PageContent>[];
      for (final result in results.take(maxPagesToFetch)) {
        final page = await fetchPageContent(result.url);
        if (page != null) {
          pages.add(page);
        }
      }

      if (pages.isEmpty) {
        // Return just snippets if page fetch failed
        final snippets = results.map((r) => '- ${r.title}: ${r.snippet}').join('\n');
        return 'Search results for "$query":\n$snippets';
      }

      // Build summary from fetched pages
      final summaries = pages.map((p) {
        final source = p.title.isNotEmpty ? p.title : p.url;
        return 'Source: $source\n${p.content}';
      }).join('\n\n---\n\n');

      return 'Web search results for "$query":\n\n$summaries';
    } catch (e) {
      return 'Search failed: $e';
    }
  }

  // Specialized searches for common use cases
  Future<String> searchFoodInfo(String foodName) async {
    final query = '$foodName nutrition facts ingredients allergens calories';
    return searchAndSummarize(query: query, maxResults: 3, maxPagesToFetch: 2);
  }

  Future<String> searchDocumentInfo(String docType) async {
    final query = '$docType document format template example structure';
    return searchAndSummarize(query: query, maxResults: 3, maxPagesToFetch: 2);
  }

  Future<String> searchLocalInfo(String location, String topic) async {
    final query = '$location $topic near me reviews hours contact';
    return searchAndSummarize(query: query, maxResults: 3, maxPagesToFetch: 2);
  }

  Future<String> searchCurrentEvents(String topic) async {
    final query = '$topic latest news updates 2024 2025';
    return searchAndSummarize(query: query, maxResults: 4, maxPagesToFetch: 3);
  }

  void dispose() {
    _client.close();
  }
}