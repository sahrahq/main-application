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
  String get errAlreadyOnWaitlist => 'إنت بالفعل في قائمة الانتظار لليلة دي.';

  @override
  String get errWaitlistEntryNotFound => 'مش لاقيين طلب الانتظار ده.';

  @override
  String get errReviewAlreadyExists => 'إنت قيّمت الزيارة دي قبل كده.';

  @override
  String get errReviewNotEligible => 'التقييم بيكون للزيارات اللي حصلت فعلاً.';

  @override
  String get errReviewTooEarly => 'تقدر تقيّم بعد ما ميعاد الطاولة يخلص.';

  @override
  String get errReviewNotFound => 'مش لاقيين التقييم ده.';

  @override
  String get errCannotReportOwnReview => 'ده تقييمك إنت.';

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
  String get savedTitle => 'المحفوظة';

  @override
  String discoverGreeting(String name) {
    return 'مساء الخير يا $name';
  }

  @override
  String get discoverGreetingAnonymous => 'مساء الخير';

  @override
  String get discoverCity => 'القاهرة';

  @override
  String get discoverTonight => 'متاح الليلة';

  @override
  String get onboardKicker1 => 'القاهرة، الليلة';

  @override
  String get onboardTitle1 => 'اعثر على أجواء ليلتك';

  @override
  String get onboardBody1 =>
      'روف توب، مطابخ تفتح لوقت متأخر، وعود حي — أفضل موائد المدينة في مكان واحد.';

  @override
  String get onboardKicker2 => 'من غير مكالمات';

  @override
  String get onboardTitle2 => 'احجز طاولتك في ثوانٍ';

  @override
  String get onboardBody2 => 'توافر لحظي. اختر الوقت، وإحنا نبلّغهم إنك جاي.';

  @override
  String get onboardKicker3 => 'لكل مناسبة';

  @override
  String get onboardTitle3 => 'من الإفطار لعشاء رومانسي';

  @override
  String get onboardBody3 =>
      'مختارة لرمضان، أعياد الميلاد، أو حتى يوم تلات يستاهل أحسن.';

  @override
  String get onboardNext => 'التالي';

  @override
  String onboardSlideOf(int index, int total) {
    return 'شريحة $index من $total';
  }

  @override
  String get onboardStart => 'ابدأ';

  @override
  String get onboardHaveAccount => 'عندك حساب؟';

  @override
  String get onboardSignIn => 'سجّل دخول';

  @override
  String get filterTitle => 'فلاتر';

  @override
  String get filterCuisine => 'المطبخ';

  @override
  String get filterPrice => 'السعر';

  @override
  String get filterRating => 'التقييم';

  @override
  String get filterAmenities => 'مناسب لـ';

  @override
  String get filterApply => 'اعرض النتايج';

  @override
  String get filterClear => 'امسح الكل';

  @override
  String filterRatingPlus(String rating) {
    return '$rating+';
  }

  @override
  String get filterOpen => 'فلاتر';

  @override
  String filterOpenWithCount(int count) {
    return 'فلاتر ($count)';
  }

  @override
  String get discoverSeeAll => 'الكل';

  @override
  String get discoverNothingTonightTitle => 'مافيش حاجة فاضية الليلة';

  @override
  String get discoverNothingTonightMessage =>
      'كل الترابيزات اللي شايفينها محجوزة. جرّب ليلة تانية.';

  @override
  String get discoverNothingTonightAction => 'دوّر';

  @override
  String get tabDiscoverHome => 'استكشف';

  @override
  String get savedFailed => 'الحفظ مانجحش. اتأكد من النت وحاول تاني.';

  @override
  String get savedEmptyTitle => 'لسه مافيش حاجة محفوظة';

  @override
  String get savedEmptyMessage =>
      'دوس على القلب في أي مكان يعجبك وهتلاقيه مستنيك هنا.';

  @override
  String get savedEmptyAction => 'دوّر على مكان';

  @override
  String get savedSignedOutTitle => 'سجّل دخول عشان تشوف أماكنك المحفوظة';

  @override
  String get savedSignedOutMessage => 'قائمتك بتيجي معاك على أي موبايل.';

  @override
  String savedRemoveLabel(String venue) {
    return 'شيل $venue من المحفوظة';
  }

  @override
  String savedAddLabel(String venue) {
    return 'احفظ $venue';
  }

  @override
  String get accountSavedPlaces => 'الأماكن المحفوظة';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String get accountSigningOut => 'بنخرّجك…';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get languageFollowDevice => 'زي إعدادات جهازك';

  @override
  String get accountLanguageValue => 'زي إعدادات جهازك';

  @override
  String get accountNotBuilt =>
      'دعوة الأصحاب وطرق الدفع والمساعدة وإعدادات الإشعارات التفصيلية لسه ما اتعملوش.';

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

  @override
  String get venueMenuTitle => 'من المنيو';

  @override
  String get venueMenuFull => 'المنيو كامل';

  @override
  String get menuSheetTitle => 'المنيو';

  @override
  String get menuEmptyTitle => 'مفيش منيو لسه';

  @override
  String get menuEmptyMessage =>
      'المطعم ده لسه ما شاركش المنيو معانا. كلّمهم وهيقولولك إيه الحلو النهارده.';

  @override
  String get menuPdfOpen => 'افتح المنيو';

  @override
  String get menuPdfNote => 'منيو المكان ده ملف. هيفتح برّه التطبيق.';

  @override
  String menuItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طبق',
      few: '$count أطباق',
      two: 'طبقين',
      one: 'طبق واحد',
    );
    return '$_temp0';
  }

  @override
  String menuPrice(String price, String currency) {
    return '$price $currency';
  }

  @override
  String get currencyEgp => 'ج.م';

  @override
  String get dietVegetarian => 'نباتي';

  @override
  String get dietVegan => 'نباتي صرف';

  @override
  String get dietGlutenFree => 'من غير جلوتين';

  @override
  String get dietNutFree => 'من غير مكسرات';

  @override
  String get dietDairyFree => 'من غير ألبان';

  @override
  String get dietShellfish => 'فيه قشريات';

  @override
  String get dietSpicy => 'حرّاق';

  @override
  String get dietContainsAlcohol => 'فيه كحول';

  @override
  String get dietContainsPork => 'فيه لحم خنزير';

  @override
  String get venueReviewsTitle => 'التقييمات';

  @override
  String get venueReviewsAll => 'كل التقييمات';

  @override
  String get reviewsSheetTitle => 'التقييمات';

  @override
  String get reviewsEmptyTitle => 'مفيش تقييمات لسه';

  @override
  String get reviewsEmptyMessage =>
      'التقييم بيكتبه بس اللي حجز وجه فعلاً، فأول واحد بياخد وقت.';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      few: '$count تقييمات',
      two: 'تقييمين',
      one: 'تقييم واحد',
      zero: 'مفيش تقييمات',
    );
    return '$_temp0';
  }

  @override
  String get reviewsVerifiedNote => 'كل تقييم هنا من زبون حجز طاولة وجه فعلاً.';

  @override
  String get reviewOwnerReply => 'رد المطعم';

  @override
  String get reviewFood => 'الأكل';

  @override
  String get reviewService => 'الخدمة';

  @override
  String get reviewAmbience => 'الجو';

  @override
  String get reviewsShowMore => 'اعرض كمان';

  @override
  String reviewStarsLabel(String rating) {
    return '$rating من 5';
  }

  @override
  String reviewBreakdownLabel(int stars, int count) {
    return '$stars نجوم: $count';
  }

  @override
  String get writeReviewCta => 'اكتب تقييم';

  @override
  String get writeReviewTitle => 'كانت عاملة إيه؟';

  @override
  String writeReviewVenue(String name, String date) {
    return '$name، $date';
  }

  @override
  String get writeReviewOverall => 'بشكل عام';

  @override
  String get writeReviewDetail => 'تفاصيل أكتر، لو حابب';

  @override
  String get writeReviewBodyLabel => 'حاجة كنت هتقولها لصاحبك؟';

  @override
  String get writeReviewBodyHint => 'أكلت إيه، قعدت فين، وهترجع تاني ولا لأ.';

  @override
  String get writeReviewSubmit => 'انشر التقييم';

  @override
  String get writeReviewSubmitting => 'بننشر…';

  @override
  String get writeReviewPosted => 'اتنشر. شكراً ليك.';

  @override
  String writeReviewStar(int n) {
    return '$n من 5 نجوم';
  }

  @override
  String get writeReviewNeedsRating => 'اختار تقييم الأول.';

  @override
  String get reviewAlreadyWritten => 'إنت قيّمت الزيارة دي';

  @override
  String get reviewPublicNote => 'هيظهر اسمك الأول وأول حرف من اسم العيلة.';

  @override
  String venueGalleryLabel(int index, int total) {
    return 'صورة $index من $total';
  }

  @override
  String get filterDistance => 'المسافة';

  @override
  String get filterNearMe => 'قريب مني';

  @override
  String filterNearMeRadius(String km) {
    return 'في حدود $km كم';
  }

  @override
  String get filterSort => 'ترتيب حسب';

  @override
  String get sortRelevance => 'الأنسب';

  @override
  String get sortRating => 'الأعلى تقييماً';

  @override
  String get sortDistance => 'الأقرب';

  @override
  String get locationAsking => 'بندوّر عليك…';

  @override
  String get locationDenied => 'مش هنعرف نرتب بالمسافة من غير موقعك.';

  @override
  String get locationDeniedForever =>
      'الموقع مقفول لسهرة. افتحه من إعدادات التليفون عشان الترتيب بالمسافة.';

  @override
  String get locationServiceDisabled => 'الموقع مقفول على التليفون ده.';

  @override
  String get locationUnavailable => 'مقدرناش نلاقيك. دوّر على منطقة بدل كده.';

  @override
  String resultDistance(String km) {
    return '$km كم';
  }

  @override
  String get reviewReport => 'بلّغ';

  @override
  String get reviewReportTitle => 'بلّغ عن التقييم ده';

  @override
  String get reviewReportWhy => 'إيه المشكلة فيه؟';

  @override
  String get reviewReportReasonSpam => 'سبام أو إعلان';

  @override
  String get reviewReportReasonAbusive => 'مسيء أو بذيء';

  @override
  String get reviewReportReasonNotMyVisit => 'دي مش زيارتي';

  @override
  String get reviewReportReasonWrongVenue => 'المطعم غلط';

  @override
  String get reviewReportReasonOther => 'حاجة تانية';

  @override
  String get reviewReportNoteLabel => 'عايز تضيف حاجة؟';

  @override
  String get reviewReportNoteHint => 'اختياري. هيوصل للي بيراجع.';

  @override
  String get reviewReportSubmit => 'ابعت البلاغ';

  @override
  String get reviewReportSubmitting => 'بنبعت…';

  @override
  String get reviewReportSent => 'شكراً ليك. حد هيبص عليه.';

  @override
  String get reviewReportNoReasonYet => 'اختار السبب الأول.';

  @override
  String get reviewReportHonest => 'البلاغ مش بيخفي التقييم. حد بيقراه وبيقرر.';

  @override
  String get reviewReportAlready => 'إنت بلّغت عن ده قبل كده.';

  @override
  String get accountNotifications => 'الإشعارات';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsEmptyTitle => 'مفيش حاجة لسه';

  @override
  String get notificationsEmptyMessage =>
      'لما مطعم يغيّر حاجة، أو ترابيزة تفضى، هتلاقيها هنا.';

  @override
  String get notificationsSignedOutTitle => 'سجّل دخولك عشان تشوف إشعاراتك';

  @override
  String get notificationsFailed => 'مش قادرين نحمّل الإشعارات.';

  @override
  String notificationsUnreadBadge(int count) {
    return '$count جديد';
  }

  @override
  String get notificationsToday => 'النهارده';

  @override
  String get notificationsEarlier => 'قبل كده';

  @override
  String get notificationsNoPushNote =>
      'لسه مش بنقدر ننبّه موبايلك، فارجع لهنا من وقت للتاني.';

  @override
  String notifCancelledTitle(String venue) {
    return '$venue ألغى حجزك';
  }

  @override
  String notifCancelledBody(String date, String time) {
    return '$date الساعة $time';
  }

  @override
  String notifConfirmedTitle(String venue) {
    return 'تم حجز ترابيزة في $venue';
  }

  @override
  String notifConfirmedBody(
      String date, String time, String party, String code) {
    return '$date الساعة $time · $party أفراد · $code';
  }

  @override
  String notifReminder24hTitle(String venue) {
    return 'بكرة في $venue';
  }

  @override
  String notifReminder24hBody(String time) {
    return 'الساعة $time. مش هتقدر تيجي؟ الغِ الحجز عشان الترابيزة تروح لحد تاني.';
  }

  @override
  String notifReminder2hTitle(String venue) {
    return 'بعد ساعتين في $venue';
  }

  @override
  String notifReminder2hBody(String time, String party, String code) {
    return 'الساعة $time · $party أفراد · $code';
  }

  @override
  String notifWaitlistOfferTitle(String venue) {
    return 'فضيت ترابيزة في $venue';
  }

  @override
  String notifWaitlistOfferBody(String date, String time) {
    return '$date الساعة $time. احجز دلوقتي — اللي يسبق يكسب.';
  }

  @override
  String notifWaitlistExpiredTitle(String venue) {
    return 'الترابيزة اتحجزت في $venue';
  }

  @override
  String notifWaitlistExpiredBody(String date) {
    return 'لسه اسمك في القائمة ليوم $date.';
  }

  @override
  String get notifFallbackVenue => 'المطعم';
}
