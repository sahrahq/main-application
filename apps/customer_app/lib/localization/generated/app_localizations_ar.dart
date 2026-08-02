// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get errAccountUnavailable =>
      'الحساب ده مش متاح دلوقتي. كلّم خدمة العملاء لو سمحت.';

  @override
  String get errBadRequest => 'فيه حاجة في الطلب مش مظبوطة. حاول تاني.';

  @override
  String get errBookingsOutsideNewHours =>
      'فيه حجوزات مؤكدة هتقع بره المواعيد دي.';

  @override
  String get errCapacityConflictWithReservations =>
      'فيه حجوزات قادمة على الطاولة دي مش هتناسب السعة الجديدة.';

  @override
  String get errConflict => 'الحالة اتغيّرت. حدّث الصفحة وحاول تاني.';

  @override
  String get errDuplicateRequest => 'الطلب ده اتبعت قبل كده.';

  @override
  String get errForbidden => 'ملكش صلاحية تعمل ده.';

  @override
  String get errForbiddenRole => 'دورك مايسمحش بده.';

  @override
  String get errHoldExpired =>
      'الحجز المؤقت انتهى. اختار الميعاد تاني — مش هياخد لحظة.';

  @override
  String get errInternalError => 'حصل خطأ عندنا. حاول تاني لو سمحت.';

  @override
  String get errInvalidAvailabilityFilter =>
      'اختار التاريخ وعدد الأفراد مع بعض.';

  @override
  String get errInvalidCredentials => 'رقم التليفون أو كلمة السر مش مظبوطة.';

  @override
  String get errInvalidDate => 'التاريخ ده مش مظبوط.';

  @override
  String get errInvalidIdempotencyKey => 'حصلت مشكلة وإحنا بنبعت. حاول تاني.';

  @override
  String get errInvalidOtp => 'الكود ده غلط. راجعه وحاول تاني.';

  @override
  String get errInvalidPartySize => 'اختار عدد أفراد بين 1 و 50.';

  @override
  String get errInvalidQueryParam => 'واحد من الفلاتر دي مش صحيح.';

  @override
  String get errInvalidSort => 'طريقة الترتيب دي مش متاحة.';

  @override
  String get errInvalidStatusTransition =>
      'الحجز ده اتغيّر بالفعل. حدّث عشان تشوف حالته.';

  @override
  String get errMissingIdempotencyKey => 'حصلت مشكلة وإحنا بنبعت. حاول تاني.';

  @override
  String get errNotAnOwner => 'الحساب ده مش مسجّل كصاحب مطعم.';

  @override
  String get errNotFound => 'مالقيناش ده.';

  @override
  String get errOtpExpired => 'الكود خلصت مدته. اطلب كود جديد.';

  @override
  String get errOtpRateLimited => 'طلبت أكواد كتير. حاول تاني بعد كام دقيقة.';

  @override
  String get errPacingLimitReached =>
      'المطبخ مزحوم في الميعاد ده. جرّب ميعاد قريب منه.';

  @override
  String get errPayloadTooLarge => 'حجم الملف كبير أوي.';

  @override
  String get errRateLimited => 'الطلبات كتير. استنى شوية.';

  @override
  String get errReservationNotFound => 'مالقيناش الحجز ده.';

  @override
  String get errRestaurantNotFound => 'مالقيناش المطعم ده.';

  @override
  String get errSearchUnavailable => 'البحث فيه مشكلة دلوقتي. حاول تاني.';

  @override
  String get errServiceBusy => 'المطعم مزحوم دلوقتي. حاول تاني بعد لحظات.';

  @override
  String get errServiceUnavailable =>
      'الخدمة مش متاحة دلوقتي. حاول تاني لو سمحت.';

  @override
  String get errShiftNotFound => 'مالقيناش المواعيد دي.';

  @override
  String get errShiftOverlap => 'المواعيد دي بتتعارض مع وردية عندك بالفعل.';

  @override
  String get errSlotTaken => 'الميعاد ده اتحجز للتو. دي مواعيد تانية.';

  @override
  String get errSlugUnavailable => 'الاسم ده مستخدم بالفعل.';

  @override
  String get errTableHasFutureReservations =>
      'الطاولة دي عليها حجوزات قادمة. انقلها أو الغيها الأول.';

  @override
  String get errTableNameTaken => 'عندك طاولة بنفس الاسم.';

  @override
  String get errTableNotFound => 'مالقيناش الطاولة دي.';

  @override
  String get errTooManyAttempts =>
      'حاولت كتير والكود مظبطش. استنى ١٥ دقيقة وجرّب تاني — طلب كود جديد مش هيفيد دلوقتي.';

  @override
  String get errUnauthenticated => 'سجّل دخولك وحاول تاني.';

  @override
  String get errUnprocessable => 'مقدرناش ننفّذ ده. راجع البيانات وحاول تاني.';

  @override
  String get errValidationFailed => 'فيه بيانات لسه مش مظبوطة.';

  @override
  String get errOffline => 'إنت مش متصل بالإنترنت. هنحاول تاني أول ما ترجع.';

  @override
  String get errUnknown => 'حصل خطأ. حاول تاني لو سمحت.';

  @override
  String get actionRetry => 'حاول تاني';

  @override
  String get actionDismiss => 'تمام';

  @override
  String errorReference(String requestId) {
    return 'رقم مرجعي $requestId';
  }

  @override
  String get errTitleOffline => 'إنت أوفلاين';

  @override
  String get errTitleNetwork => 'ده أخد وقت طويل';

  @override
  String get errTitleAuth => 'محتاج حساب للخطوة دي';

  @override
  String get errTitleConflict => 'في حاجة اتغيرت دلوقتي';

  @override
  String get errTitleValidation => 'راجع ده تاني';

  @override
  String get errTitleServer => 'سهرة تعبانة شوية';

  @override
  String get errTitleUnknown => 'في حاجة غلط';

  @override
  String get appTitle => 'سهرة';

  @override
  String get searchHint => 'ابحث';

  @override
  String get searchLocation => 'القاهرة';

  @override
  String get searchFilterTonight => 'الليلة';

  @override
  String searchOpenTonight(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكان مفتوح الليلة',
      few: '$count أماكن مفتوحة الليلة',
      two: 'مكانين مفتوحين الليلة',
      one: 'مكان واحد مفتوح الليلة',
      zero: 'مفيش حاجة مفتوحة الليلة',
    );
    return '$_temp0';
  }

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكان',
      few: '$count أماكن',
      two: 'مكانين',
      one: 'مكان واحد',
      zero: 'مفيش أماكن',
    );
    return '$_temp0';
  }

  @override
  String searchNextAvailable(String time) {
    return 'القادم: $time';
  }

  @override
  String get searchStartTitle => 'هتاكل فين الليلة؟';

  @override
  String get searchStartMessage =>
      'دوّر بالاسم أو نوع الأكل أو المنطقة — بالعربي، بالإنجليزي، أو زي ما بتكتب.';

  @override
  String get searchEmptyTitle => 'مفيش حاجة مطابقة';

  @override
  String get searchEmptyMessage => 'جرّب منطقة قريبة، أو ليلة تانية.';

  @override
  String get searchEmptyAction => 'ابدأ من جديد';

  @override
  String get searchOfflineTitle => 'إنت أوفلاين';

  @override
  String get searchOfflineMessage =>
      'مش قادرين نوصل لسهرة دلوقتي. النت رجع قبل كده وهيرجع تاني.';

  @override
  String get venueBack => 'رجوع';

  @override
  String get venueShare => 'شارك';

  @override
  String get venueSave => 'احفظ';

  @override
  String get venueSaved => 'محفوظ';

  @override
  String get venueBook => 'احجز طاولة';

  @override
  String get venueBookingFrom => 'يبدأ من';

  @override
  String get venueBookingFree => 'الحجز مجاني';

  @override
  String get venueOpenTonight => 'مفتوح الليلة';

  @override
  String get venueClosedToday => 'مقفول النهارده';

  @override
  String venueHoursRange(String opens, String closes) {
    return '$opens – $closes';
  }

  @override
  String get venueDirections => 'الاتجاهات';

  @override
  String get venueCall => 'اتصل بالمكان';

  @override
  String get venueNotFoundTitle => 'المكان ده مش متاح';

  @override
  String get venueNotFoundMessage =>
      'المكان ده مش بياخد حجوزات دلوقتي. شوف إيه اللي مفتوح غيره.';

  @override
  String get venueNotFoundAction => 'ارجع للبحث';

  @override
  String get amenityOutdoor => 'قعدة برّه';

  @override
  String get amenityShisha => 'شيشة';

  @override
  String get amenityNileView => 'إطلالة على النيل';

  @override
  String get amenityValet => 'خدمة ركن السيارة';

  @override
  String get amenityFamilySection => 'قسم عائلات';

  @override
  String get amenityAlcoholFree => 'بدون كحول';

  @override
  String get bookTitle => 'احجز طاولة';

  @override
  String get bookDate => 'التاريخ';

  @override
  String get bookParty => 'عدد الأفراد';

  @override
  String get bookTime => 'الوقت';

  @override
  String bookGuests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فرد',
      few: 'أفراد',
      two: 'فردين',
      one: 'فرد',
    );
    return '$_temp0';
  }

  @override
  String get bookDecreaseParty => 'فرد أقل';

  @override
  String get bookIncreaseParty => 'فرد زيادة';

  @override
  String get bookToday => 'الليلة';

  @override
  String bookConfirmFor(int party, String time) {
    return 'أكّد لـ $party الساعة $time';
  }

  @override
  String get bookCancellationPolicy => 'إلغاء مجاني حتى ساعتين قبل الموعد.';

  @override
  String get bookNoSlotsTitle => 'مفيش طاولات الليلة دي';

  @override
  String bookNoSlotsMessage(int party) {
    return 'مفيش حاجة فاضية لـ $party في التاريخ ده. جرّب ليلة تانية، أو طاولة أصغر.';
  }

  @override
  String get bookClosedTitle => 'مقفول اليوم ده';

  @override
  String get bookClosedMessage => 'المكان ده مش بيفتح في التاريخ اللي اخترته.';

  @override
  String get bookHolding => 'بنحجزلك الطاولة…';

  @override
  String get bookSlotTakenTitle => 'حد حجزها قبلك';

  @override
  String get bookSlotTakenMessage =>
      'الوقت ده راح وإنت بتختار. دول الأوقات اللي لسه فاضية.';

  @override
  String get bookHoldExpiredTitle => 'الحجز المؤقت خلص';

  @override
  String get bookHoldExpiredMessage =>
      'بنحجز الطاولة دقايق بس. اختار وقت تاني — مش هياخد وقت.';

  @override
  String get bookPickAgain => 'اختار وقت تاني';

  @override
  String get confirmedOverline => 'تم تأكيد الحجز';

  @override
  String confirmedMessage(String venue) {
    return 'بلّغنا $venue إنك جاي.';
  }

  @override
  String get confirmedDate => 'التاريخ';

  @override
  String get confirmedTime => 'الوقت';

  @override
  String get confirmedGuests => 'الأفراد';

  @override
  String get confirmedReference => 'رقم الحجز';

  @override
  String get confirmedDone => 'تمام';

  @override
  String get loadingLabel => 'بنحمّل';

  @override
  String get cuisineLevantine => 'شامي';

  @override
  String get cuisineEgyptian => 'مصري';

  @override
  String get cuisineMediterranean => 'متوسطي';

  @override
  String get cuisineLebanese => 'لبناني';

  @override
  String get cuisineJapanese => 'ياباني';

  @override
  String get cuisineSushi => 'سوشي';

  @override
  String get cuisineStreetFood => 'أكل شارع';

  @override
  String get cuisineCafe => 'قهوة';
}
