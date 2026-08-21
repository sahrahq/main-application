import 'venue.dart';

/// R-2.3 / C-2.6 — a venue's menu, already in the diner's language.
///
/// The API sends `name_en` and `name_ar` on every row; the repository picks
/// one, the same way it does for the venue profile. Carrying both up to the
/// widget would put the locale decision in the presentation layer, and then in
/// four presentation layers.
class Menu {
  const Menu({
    required this.id,
    required this.name,
    required this.kind,
    required this.categories,
    this.pdfUrl,
  });

  final String id;
  final String name;

  /// `food` | `drinks` | `ramadan` | `set`. Unmapped by design — the screen
  /// draws the NAME, not the kind, and a `switch` on it here would be a second
  /// vocabulary to keep in step with the enum.
  final String kind;

  final List<MenuCategory> categories;

  /// R-2.3's fallback, for the many Cairo venues whose whole menu is one
  /// scanned file. Non-null means there is a document to hand to the phone;
  /// nothing in this app renders a PDF itself.
  final String? pdfUrl;

  /// The first few dishes, for the preview on the venue page.
  ///
  /// Flattened ACROSS categories rather than taking the first category whole:
  /// the reference shows four dishes each with a different category label
  /// beside it, which is a sample of the menu rather than the top of it.
  List<({MenuItem item, String category})> preview(int count) {
    final out = <({MenuItem item, String category})>[];
    for (final c in categories) {
      for (final i in c.items) {
        if (out.length == count) return out;
        out.add((item: i, category: c.name));
      }
    }
    return out;
  }

  int get itemCount => categories.fold(0, (total, c) => total + c.items.length);
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.items});

  final String id;
  final String name;
  final List<MenuItem> items;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.description,
    this.dietaryTags = const <String>[],
    this.image,
  });

  final String id;
  final String name;
  final String? description;

  /// A DECIMAL STRING, exactly as the API sent it — `'320.00'`.
  ///
  /// Not a `double`, and not parsed on the way in. `NUMERIC(12,2)` through a
  /// binary float is where money stops being exact, and the client has no
  /// reason to do arithmetic on a price: it prints it. Parsing it to print it
  /// would introduce the one operation that can be wrong.
  final String price;

  /// ISO 4217. Always `EGP` today; carried because the column carries it and a
  /// hardcoded «ج.م» would be wrong the first time a venue prices in USD.
  final String currency;

  /// From a fixed vocabulary the database enforces. Unknown keys are dropped
  /// by the widget, the same way unknown amenities are.
  final List<String> dietaryTags;

  final VenueImage? image;
}
