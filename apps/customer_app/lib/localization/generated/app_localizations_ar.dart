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
  String get errImageNotFound => 'مالقيناش الصورة دي.';

  @override
  String get errImageTooLarge => 'الصورة كبيرة أوي. خليها أقل من 12 ميجا.';

  @override
  String get errInvalidImage => 'مقدرناش نقرا الملف ده كصورة.';

  @override
  String get errStorageUnavailable => 'مقدرناش نحفظ الصورة. حاول تاني.';

  @override
  String get errUnsupportedImageType => 'استخدم صورة JPEG أو PNG أو WebP.';

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
  String get errOtpSendingUnavailable =>
      'مش قادرين نبعت أكواد دلوقتي. حاول تاني بعد شوية.';

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
  String get errReservationNotModifiable =>
      'الحجز ده بدأ خلاص، فمش ممكن يتعدّل. لسه تقدر تلغيه.';

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
      'حاولت كتير والكود مظبطش. استنى 15 دقيقة وجرّب تاني — طلب كود جديد مش هيفيد دلوقتي.';

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

  @override
  String get signInTitle => 'سجّل دخولك عشان تحجز';

  @override
  String get signInWhy => 'بنحجز الطاولة باسمك، وبنبلّغك لو حصل أي تغيير.';

  @override
  String get signInPhoneLabel => 'رقم التليفون';

  @override
  String get signInPhoneHint => '01x xxx xxxx';

  @override
  String get signInNameLabel => 'اسمك';

  @override
  String get signInNameHint => 'عشان المطعم يعرف مين اللي جاي';

  @override
  String get signInContinue => 'ابعتلي كود';

  @override
  String get signInSending => 'بنبعت…';

  @override
  String get signInCodeTitle => 'اكتب الكود';

  @override
  String signInCodeSentTo(String phone) {
    return 'بعتنا كود من 6 أرقام على $phone.';
  }

  @override
  String get signInCodeLabel => 'كود من 6 أرقام';

  @override
  String get signInVerify => 'تأكيد';

  @override
  String get signInVerifying => 'بنتأكد…';

  @override
  String get signInResend => 'ابعت كود تاني';

  @override
  String get signInResending => 'بنبعت…';

  @override
  String get signInChangePhone => 'استخدم رقم تاني';

  @override
  String signInDevHint(String marker) {
    return 'الكود لسه مش بيتبعت برسالة. دوّر في كونسول الـ API على بانر $marker.';
  }

  @override
  String signInSlotHeld(String venue, String date, String time, int party) {
    String _temp0 = intl.Intl.pluralLogic(
      party,
      locale: localeName,
      other: '$party فرد',
      many: '$party فرد',
      few: '$party أفراد',
      two: 'فردين',
      one: 'فرد واحد',
    );
    return 'طاولتك: $venue، $date الساعة $time، $_temp0';
  }

  @override
  String get signInSlotNote => 'هنكمّل الحجز أول ما تدخل.';

  @override
  String get signInCancel => 'مش دلوقتي';

  @override
  String get bookingsTitle => 'حجوزاتي';

  @override
  String get bookingsUpcoming => 'الجاي';

  @override
  String get bookingsPast => 'اللي فات';

  @override
  String get bookingsEmptyUpcomingTitle => 'لسه مافيش حجوزات';

  @override
  String get bookingsEmptyUpcomingMessage =>
      'أول ما تحجز طاولة هتلاقيها هنا، بكل اللي محتاجه على الباب.';

  @override
  String get bookingsEmptyUpcomingAction => 'دوّر على مكان';

  @override
  String get bookingsEmptyPastTitle => 'لسه مارحتش حتة';

  @override
  String get bookingsEmptyPastMessage => 'الطاولات اللي رحتلها هتتحفظ هنا.';

  @override
  String get bookingsSignedOutTitle => 'سجّل دخولك تشوف حجوزاتك';

  @override
  String get bookingsSignedOutMessage => 'حجوزاتك محفوظة برقم تليفونك.';

  @override
  String get bookingsSignedOutAction => 'تسجيل الدخول';

  @override
  String get bookingsCancelledByVenue => 'المطعم ألغى';

  @override
  String get bookingsCancelledByYou => 'إنت ألغيت';

  @override
  String bookingsPartyOf(int party) {
    return 'طاولة لـ $party';
  }

  @override
  String get bookingsAcknowledge => 'تمام، فهمت';

  @override
  String get reservationTitle => 'حجزك';

  @override
  String get reservationReference => 'رقم الحجز';

  @override
  String get reservationWhen => 'الميعاد';

  @override
  String get reservationParty => 'الأفراد';

  @override
  String get reservationStatus => 'الحالة';

  @override
  String get reservationSpecialRequests => 'طلبت';

  @override
  String get reservationOccasion => 'المناسبة';

  @override
  String get reservationModify => 'غيّر الميعاد أو العدد';

  @override
  String get reservationCancel => 'إلغاء الحجز';

  @override
  String get reservationCallInstead => 'عايز تغيّر حاجة تانية؟ كلّم المطعم.';

  @override
  String get cancelSheetTitle => 'تلغي الحجز ده؟';

  @override
  String get cancelSheetBody =>
      'الترابيزة هترجع للمطعم وحد تاني ممكن ياخدها. مش هتقدر ترجع في كلامك.';

  @override
  String get cancelSheetReasonLabel => 'السبب (اختياري)';

  @override
  String get cancelSheetReasonHint => 'أي حاجة تحب المطعم يعرفها';

  @override
  String get cancelSheetConfirm => 'إلغاء الحجز';

  @override
  String get cancelSheetWorking => 'بنلغي…';

  @override
  String get cancelSheetKeep => 'خليك على الحجز';

  @override
  String get moveSheetTitle => 'غيّر حجزك';

  @override
  String get moveSheetConfirm => 'احفظ التغييرات';

  @override
  String get moveSheetWorking => 'بنحفظ…';

  @override
  String get accountEditName => 'تعديل الاسم';

  @override
  String get accountEditNameTitle => 'اسمك';

  @override
  String get accountEditNameWhy =>
      'ده الاسم اللي المطعم هيدوّر عليه على الباب.';

  @override
  String get accountEditNameSave => 'احفظ';

  @override
  String get accountEditNameSaving => 'بنحفظ…';

  @override
  String get reservationVenuePhone => 'اتصل بالمطعم';

  @override
  String reservationCancelledNotice(String venue, String reason) {
    return '$venue ألغى الحجز ده: $reason';
  }

  @override
  String get reservationNotFoundTitle => 'مش لاقيين الحجز ده';

  @override
  String get reservationNotFoundMessage =>
      'يمكن يكون اتلغى، أو بيخص حساب تاني.';

  @override
  String get statusPending => 'في انتظار التأكيد';

  @override
  String get statusConfirmed => 'مؤكد';

  @override
  String get statusSeated => 'قاعد';

  @override
  String get statusCompleted => 'زيارة تمت';

  @override
  String get statusNoShow => 'مجاش';

  @override
  String get statusCancelledByUser => 'إنت ألغيته';

  @override
  String get statusCancelledByRestaurant => 'المطعم ألغاه';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get tabDiscover => 'استكشف';

  @override
  String get tabBookings => 'حجوزاتي';

  @override
  String get tabAccount => 'حسابي';

  @override
  String get accountTitle => 'حسابي';

  @override
  String get accountSignedOutTitle => 'إنت بتتفرج كضيف';

  @override
  String get accountSignedOutMessage =>
      'سجّل دخولك عشان تحجز طاولة وتلاقي حجوزاتك كلها في مكان واحد.';

  @override
  String get accountMyBookings => 'حجوزاتي';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String get accountSigningOut => 'بنخرّجك…';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountLanguageValue => 'زي إعدادات جهازك';

  @override
  String get accountNotBuilt =>
      'الأماكن المحفوظة وطرق الدفع وإعدادات الإشعارات لسه ما اتعملوش.';

  @override
  String searchLocationSemantic(String city) {
    return 'بتدوّر في $city';
  }

  @override
  String bookGuestsUnit(int count) {
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
  String get signInNameTitle => 'نناديك إيه؟';

  @override
  String get signInNameWhy =>
      'المطعم محتاج اسم للطاولة. مش محتاجين حاجة تانية.';

  @override
  String get signInNameSubmit => 'خلّصنا';

  @override
  String get signInNameSubmitting => 'بنخلّص…';

  @override
  String get signInNoCodeHelp => 'الكود مش بيوصل؟ كلّمنا:';

  @override
  String get signInEmailSupport => 'ابعت إيميل لدعم سهرة';

  @override
  String get contactCannotOpen => 'مقدرناش نفتح تطبيق لده — انسخه بدل كده.';

  @override
  String get reservationCallVenue => 'كلّم المطعم';
}
