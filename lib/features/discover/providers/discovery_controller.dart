import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/loop.dart';
import '../../../data/repositories/discovery_repository.dart';

class DiscoveryController extends ChangeNotifier {
  DiscoveryController(
    this._repository, {
    this.debounce = const Duration(milliseconds: 350),
  });
  final DiscoveryRepository _repository;
  final Duration debounce;
  Timer? _timer;
  int _request = 0, _offset = 0;
  bool _disposed = false;
  DiscoveryQuery query = const DiscoveryQuery();
  List<Loop> loops = const [];
  bool loading = false, loadingMore = false, hasMore = false;
  String? error;

  void searchText(String value) {
    final term = value.trim();
    if (term == query.term) return;
    change(query.copyWith(term: term), delayed: true);
  }

  void change(DiscoveryQuery next, {bool delayed = false}) {
    query = next;
    _timer?.cancel();
    ++_request;
    loops = const [];
    loading = true;
    loadingMore = false;
    hasMore = false;
    error = null;
    notifyListeners();
    if (delayed) {
      _timer = Timer(debounce, refresh);
    } else {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    _timer?.cancel();
    final request = ++_request;
    _offset = 0;
    loading = true;
    loadingMore = false;
    error = null;
    loops = const [];
    hasMore = false;
    notifyListeners();
    try {
      final page = await _repository.search(query);
      if (_disposed || request != _request) return;
      loops = page.loops;
      _offset = page.loops.length;
      hasMore = page.hasMore;
    } on DiscoveryException catch (e) {
      if (_disposed || request != _request) return;
      error = e.message;
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final request = _request;
    loadingMore = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repository.search(query, offset: _offset);
      if (_disposed || request != _request) return;
      _offset += page.loops.length;
      final ids = loops.map((loop) => loop.id).toSet();
      loops = [...loops, ...page.loops.where((loop) => ids.add(loop.id))];
      hasMore = page.hasMore;
    } on DiscoveryException catch (e) {
      if (_disposed || request != _request) return;
      error = e.message;
    } finally {
      if (!_disposed && request == _request) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    _timer?.cancel();
    super.dispose();
  }
}
