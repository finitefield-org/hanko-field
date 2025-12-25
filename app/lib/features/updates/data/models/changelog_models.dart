// ignore_for_file: public_member_api_docs

enum ChangelogReleaseTier { major, minor, patch }

enum ChangelogHeroTone { indigo, cedar, jade, sunset }

extension ChangelogReleaseTierX on ChangelogReleaseTier {
  String label({required bool prefersEnglish}) {
    switch (this) {
      case ChangelogReleaseTier.major:
        return prefersEnglish ? 'Major' : '主要';
      case ChangelogReleaseTier.minor:
        return prefersEnglish ? 'Minor' : '軽微';
      case ChangelogReleaseTier.patch:
        return prefersEnglish ? 'Patch' : '修正';
    }
  }
}

class ChangelogCopy {
  const ChangelogCopy({required this.en, required this.ja});

  final String en;
  final String ja;

  String resolve(bool prefersEnglish) => prefersEnglish ? en : ja;
}

class ChangelogHighlight {
  const ChangelogHighlight({required this.title, required this.description});

  final ChangelogCopy title;
  final ChangelogCopy description;
}

class ChangelogSection {
  const ChangelogSection({required this.title, required this.items});

  final ChangelogCopy title;
  final List<ChangelogCopy> items;
}

class ChangelogRelease {
  const ChangelogRelease({
    required this.id,
    required this.version,
    required this.releasedAt,
    required this.tier,
    required this.heroTone,
    required this.title,
    required this.summary,
    required this.highlights,
    required this.sections,
  });

  final String id;
  final String version;
  final DateTime releasedAt;
  final ChangelogReleaseTier tier;
  final ChangelogHeroTone heroTone;
  final ChangelogCopy title;
  final ChangelogCopy summary;
  final List<ChangelogHighlight> highlights;
  final List<ChangelogSection> sections;

  bool get isMajor => tier == ChangelogReleaseTier.major;
}
