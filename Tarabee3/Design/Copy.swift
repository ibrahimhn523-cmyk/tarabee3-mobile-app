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
