// نصوص الواجهة (05-ui §١٠): فصيح قريب، بالمفرد المذكّر، والأزرار أفعال أمر، والعنوان أربع كلمات حدّاً أعلى.
// ما عليه «§١٠» منقول من الموجز حرفاً؛ والباقي مقترح، يُعتمد دفعة مع البناء (تقرير M-02).

enum Copy {
    enum FirstOpen {
        static let namePlaceholder = "اسمك"
        static let nameLabel = "الاسم"
        static let start = "ابدأ"
        static let nameLengthHint = "الاسم من حرفين إلى 12 حرفاً."
        static let pickerTitle = "اختر شخصيتك"
    }

    enum Home {
        static let matches = "المباريات"
        static let wins = "الانتصارات"
        static let noMatches = "لا مباريات بعد." // §١٠
        static let settings = "الإعدادات"
        static let training = "تدريب"
    }

    enum Settings {
        static let title = "الملف والإعدادات"
        static let profile = "اسمك وشخصيتك"
        static let save = "احفظ"
        static let saved = "حُفظ ملفك."
        static let appearance = "المظهر"
        static let appearanceSystem = "تلقائي"
        static let appearanceLight = "فاتح"
        static let appearanceDark = "داكن"
        static let deleteAccount = "احذف الحساب"
        static let deleteConfirm = "يُحذف ملفك وأقسامك المفتوحة، ولا رجعة. مشترياتك عند آبل تبقى حتى تنتهي." // §١٠
        static let deleteContinue = "تابع الحذف"
        static let deleteFinalTitle = "تأكيد أخير"
        static let deleteFinal = "احذف نهائياً"
        static let cancel = "إلغاء"
        static let close = "أغلق"
    }

    enum Training {
        static let title = "تدريب"
        static let line = "مباراة ضد لاعبين آليين، بلا إنترنت، ولا تُحسب في ملفك."
        static let size = "الحجم"
        static let board = "اللوح"
        static let three = "ثلاثية"
        static let four = "رباعية"
        static let five = "خماسية"
        static let start = "ابدأ"
    }

    enum Match {
        static let ready = "استعدّ"
        static let yourTurn = "دورك"
        static let chooseSquare = "اختر مربعاً فارغاً مركزاً لصليبك"
        static let commit = "اعتمد"
        static let boardTab = "اللوح"
        static let questionTab = "السؤال"
        static let bot = "آلي"
        static let truthTrue = "صح"
        static let truthFalse = "خطأ"
        static func turnOf(_ name: String) -> String { "دور \(name)" }
        static func choosing(_ name: String) -> String { "\(name) يختار مربعه" }
        static func correct(_ name: String) -> String { "أصاب \(name)" }
        static func wrong(_ name: String) -> String { "أخطأ \(name)" }
        static func timeout(_ name: String) -> String { "انتهت مهلة \(name)" }
        static func dropped(_ name: String) -> String { "انتهت مهلة اختيار \(name)" }
        static let committedMine = "اعتُمد اختيارك." // §١٠
        static let wrongMine = "إجابة خاطئة."
        static let timeoutMine = "انتهت المهلة."
        static let droppedMine = "انتهت مهلة الاختيار. ضاع الدور." // §١٠
        static func winner(_ name: String) -> String { "فاز \(name)" }
        static let tie = "تعادل على المرتبة الأولى"
        static let playAgain = "مباراة جديدة"
        static let home = "الرئيسية"
        static let exit = "اخرج"
        static let exitTitle = "الخروج من التدريب"
        static let exitConfirm = "تخرج وتنتهي المباراة. التدريب لا يُحسب في ملفك."
        static let packMissing = "يلزم اتصال مرة لتجهيز التدريب." // §١٠
    }

    enum Picker {
        static let head = "الرأس"
        static let eye = "العين"
        static let neck = "الرقبة"
    }

    enum Status {
        static let nameUnavailable = "هذا الاسم غير متاح. اختر غيره." // §١٠
        static let noInternet = "لا اتصال بالإنترنت. العب تدريباً حتى يعود." // §١٠
        static let serverError = "تعذّر الحفظ. أعد المحاولة بعد قليل."
        static let deleteFailed = "تعذّر حذف الحساب. أعد المحاولة."
        static let notConfigured = "التطبيق غير مهيّأ بعد. انتظر تحديثاً قريباً."
        static let loading = "نجهّز ملفك…"
        static let retry = "أعد المحاولة"
    }
}
