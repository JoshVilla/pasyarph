import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/data/models/club.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/club_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/clubs/club_rules.dart';
import 'package:pasyarph/features/clubs/providers/club_controller.dart';
import 'package:pasyarph/features/riders/providers/rider_profile_controller.dart';

import '../../support/fake_clubs.dart';
import '../../support/fake_social.dart';

void main() {
  group('invite links', () {
    const code = '3f9a0c2b7d1e4a56';

    test('the whole link, with or without https://', () {
      expect(parseInviteCode('https://pasyar.app/join/$code'), code);
      expect(parseInviteCode('pasyar.app/join/$code'), code);
      expect(parseInviteCode('  https://www.pasyar.app/join/$code/ \n'), code);
      expect(
        parseInviteCode('https://pasyar.app/join/${code.toUpperCase()}'),
        code,
      );
    });

    test('just the code', () {
      expect(parseInviteCode(code), code);
      expect(parseInviteCode(' $code '), code);
    });

    test('anything else is not an invite', () {
      expect(parseInviteCode(''), isNull);
      expect(parseInviteCode('hello'), isNull);
      expect(parseInviteCode('3f9a0c2b7d1e4a5'), isNull, reason: 'too short');
      expect(parseInviteCode('3f9a0c2b7d1e4a5z'), isNull, reason: 'not hex');
      expect(parseInviteCode('https://evil.example/join/$code'), isNull);
      expect(parseInviteCode('https://pasyar.app/loop/$code'), isNull);
      expect(parseInviteCode('https://pasyar.app/join/$code/extra'), isNull);
    });
  });

  test('club names: 2 to 60 characters, trimmed', () {
    expect(clubNameError('A'), isNotNull);
    expect(clubNameError('  A  '), isNotNull);
    expect(clubNameError('Cordon Riders'), isNull);
    expect(clubNameError('x' * 60), isNull);
    expect(clubNameError('x' * 61), isNotNull);
  });

  test('member counts and club subtitles', () {
    expect(memberCount(1), '1 member');
    expect(memberCount(12), '12 members');
    Club club(ClubRole? role, int? n) => Club(
      id: 'k',
      name: 'K',
      ownerId: 'o',
      createdAt: DateTime(2026),
      myRole: role,
      memberCount: n,
    );
    expect(clubSubtitle(club(ClubRole.owner, 12)), 'Owner · 12 members');
    expect(clubSubtitle(club(ClubRole.member, 1)), 'Member · 1 member');
    expect(clubSubtitle(club(null, 3)), '3 members');
    expect(clubSubtitle(club(null, null)), '');
  });

  test('club rows parse from club_info / my_clubs', () {
    final c = Club.fromJson({
      'id': 'k',
      'name': 'Cordon Riders',
      'owner_id': 'o',
      'photo_url': null,
      'created_at': '2026-10-19T05:00:00Z',
      'my_role': 'member',
      'member_count': 7,
    });
    expect(c.isMember, isTrue);
    expect(c.isOwner, isFalse);
    expect(c.memberCount, 7);
    // A plain clubs row (no RPC extras).
    final plain = Club.fromJson({
      'id': 'k',
      'name': 'Cordon Riders',
      'owner_id': 'o',
      'created_at': '2026-10-19T05:00:00Z',
    });
    expect(plain.isMember, isFalse);
    expect(plain.memberCount, isNull);
  });

  group('ClubController', () {
    late FakeClubRepository repo;

    setUp(() {
      repo = FakeClubRepository();
      repo.add('mine', 'Cordon Riders', memberIds: ['ana', 'jun']);
      repo.add('theirs', 'Isabela Riders', ownerId: 'rico');
    });

    test('a member sees the club and its members, owner first', () async {
      final c = ClubController(clubs: repo, clubId: 'mine');
      await c.load();
      expect(c.club!.isOwner, isTrue);
      expect(c.club!.memberCount, 3);
      expect([for (final m in c.members!) m.userId], ['me', 'ana', 'jun']);
    });

    test("a non-member sees the club's name but not its members", () async {
      final c = ClubController(clubs: repo, clubId: 'theirs');
      await c.load();
      expect(c.club!.name, 'Isabela Riders');
      expect(c.club!.isMember, isFalse);
      expect(c.members, isNull);
      expect(repo.calls, isNot(contains('members:theirs')));
    });

    test('a deleted club is not found', () async {
      final c = ClubController(clubs: repo, clubId: 'gone');
      await c.load();
      expect(c.notFound, isTrue);
    });

    test('invite link, and a new one after a reset', () async {
      final c = ClubController(clubs: repo, clubId: 'mine');
      await c.load();
      final link = await c.inviteLink();
      expect(link.toString(), 'https://pasyar.app/join/${repo.codes['mine']}');
      final fresh = await c.resetInviteLink();
      expect(fresh, isNot(link));
      expect(parseInviteCode(fresh.toString()), repo.codes['mine']);
    });

    test('offline: invite throws a message; leave returns one', () async {
      final c = ClubController(clubs: repo, clubId: 'mine');
      await c.load();
      repo.failNext = ClubException.offline;
      await expectLater(
        c.inviteLink(),
        throwsA(
          isA<ClubException>().having(
            (e) => e.message,
            'message',
            ClubException.offline.message,
          ),
        ),
      );
      repo.failNext = ClubException.offline;
      expect(await c.leave(), ClubException.offline.message);
      expect(c.busy, isFalse);
    });
  });

  group('joining and leaving', () {
    test('join with a code, then leave', () async {
      final repo = FakeClubRepository()
        ..add('k', 'Isabela Riders', ownerId: 'rico', code: '0123456789abcdef');
      final preview = await repo.byInvite('0123456789abcdef');
      expect(preview!.isMember, isFalse);
      expect(preview.memberCount, 1);

      expect(await repo.join('0123456789abcdef'), 'k');
      expect((await repo.mine()).single.myRole, ClubRole.member);

      await repo.leave('k');
      expect(await repo.mine(), isEmpty);
    });

    test('an unknown code', () async {
      final repo = FakeClubRepository();
      expect(await repo.byInvite('0123456789abcdef'), isNull);
      expect(
        () => repo.join('0123456789abcdef'),
        throwsA(same(ClubException.inviteNotFound)),
      );
    });
  });

  group('RiderProfileController', () {
    const ana = RiderProfile(
      id: 'ana',
      displayName: 'Ana Lopez',
      homeArea: 'Cordon, Isabela',
      bikeType: BikeType.underbone,
      followerCount: 4,
      followingCount: 2,
    );

    test('follow: counts change at once and stick', () async {
      final social = FakeSocialRepository(riders: {'ana': ana});
      final c = RiderProfileController(social: social, userId: 'ana');
      await c.load();
      expect(c.isMe, isFalse);
      expect(await c.toggleFollow(), isNull);
      expect(c.rider!.followedByMe, isTrue);
      expect(c.rider!.followerCount, 5);
      expect(social.follows, {'ana'});

      expect(await c.toggleFollow(), isNull);
      expect(c.rider!.followedByMe, isFalse);
      expect(c.rider!.followerCount, 4);
      expect(social.follows, isEmpty);
    });

    test('follow: rolled back with a message when it fails', () async {
      final social = FakeSocialRepository(riders: {'ana': ana});
      final c = RiderProfileController(social: social, userId: 'ana');
      await c.load();
      social.failNext = SocialException.offline;
      expect(await c.toggleFollow(), SocialException.offline.message);
      expect(c.rider!.followedByMe, isFalse);
      expect(c.rider!.followerCount, 4);
    });

    test('my own profile has nothing to follow', () async {
      final social = FakeSocialRepository(
        riders: {'me': const RiderProfile(id: 'me')},
      );
      final c = RiderProfileController(social: social, userId: 'me');
      await c.load();
      expect(c.isMe, isTrue);
      expect(await c.toggleFollow(), isNull);
      expect(social.calls, isNot(contains('follow:me')));
    });

    test('rider_profile rows parse', () {
      final r = RiderProfile.fromJson({
        'id': 'ana',
        'display_name': 'Ana',
        'avatar_url': null,
        'bike_type': 'big_bike',
        'home_area': null,
        'follower_count': 3,
        'following_count': 1,
        'followed_by_me': true,
      });
      expect(r.bikeType, BikeType.bigBike);
      expect(r.followerCount, 3);
      expect(r.followedByMe, isTrue);
    });
  });
}
