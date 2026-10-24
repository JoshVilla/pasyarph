import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/deep_links.dart';
import 'package:pasyarph/core/links.dart';

void main() {
  group('share links', () {
    test('loop, post and invite links on the site', () {
      expect(AppLinks.loop('abc').toString(), 'https://pasyar.pages.dev/l/abc');
      expect(AppLinks.post('xyz').toString(), 'https://pasyar.pages.dev/p/xyz');
      expect(
        AppLinks.clubInvite('0123').toString(),
        'https://pasyar.pages.dev/join/0123',
      );
    });

    test('the share message has the name, distance and link', () {
      expect(
        shareMessage(
          loopName: ' Tanay Sunrise Loop ',
          distanceM: 82400,
          link: AppLinks.loop('abc'),
        ),
        'Pasyar tayo! Tanay Sunrise Loop · 82 km\n'
        'https://pasyar.pages.dev/l/abc',
      );
      expect(
        shareMessage(
          loopName: 'Short',
          distanceM: 8400,
          link: AppLinks.post('p'),
        ),
        startsWith('Pasyar tayo! Short · 8.4 km\n'),
      );
    });

    test('isShareLinkPath knows /l, /p and /join with one id', () {
      expect(isShareLinkPath('/l/abc'), isTrue);
      expect(isShareLinkPath('/p/abc/'), isTrue);
      expect(isShareLinkPath('/join/0123'), isTrue);
      expect(isShareLinkPath('/l'), isFalse);
      expect(isShareLinkPath('/l/abc/extra'), isFalse);
      expect(isShareLinkPath('/ride'), isFalse);
      expect(isShareLinkPath('/clubs/join/0123'), isFalse);
    });
  });

  group('PendingLink', () {
    const home = '/ride';

    test('a link opened signed out opens after signing in', () {
      final pending = PendingLink();
      // Signed out: the auth redirect sends the link to Welcome.
      expect(
        pending.redirect(path: '/l/abc', target: '/welcome', home: home),
        '/welcome',
      );
      expect(pending.path, '/l/abc');
      // Moving around the auth screens keeps it.
      expect(
        pending.redirect(path: '/login', target: null, home: home),
        isNull,
      );
      // Signed in: instead of Home, the link.
      expect(
        pending.redirect(path: '/login', target: home, home: home),
        '/l/abc',
      );
      expect(pending.path, isNull);
      // Only once.
      expect(pending.redirect(path: '/login', target: home, home: home), home);
    });

    test('it waits through the splash and onboarding', () {
      final pending = PendingLink();
      pending.redirect(path: '/p/xyz', target: '/splash', home: home);
      expect(
        pending.redirect(
          path: '/splash',
          target: '/onboarding/profile',
          home: home,
        ),
        '/onboarding/profile',
      );
      expect(
        pending.redirect(
          path: '/onboarding/location',
          target: home,
          home: home,
        ),
        '/p/xyz',
      );
    });

    test('signed in, links open directly and nothing is remembered', () {
      final pending = PendingLink();
      expect(
        pending.redirect(path: '/l/abc', target: null, home: home),
        isNull,
      );
      expect(pending.path, isNull);
    });

    test('other screens are not remembered', () {
      final pending = PendingLink();
      pending.redirect(path: '/feed', target: '/welcome', home: home);
      expect(pending.path, isNull);
    });
  });
}
