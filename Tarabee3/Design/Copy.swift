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

    /// الكروت: الأسماء والسطور من RULES-cards.md «نصوص بطاقات الكروت» حرفاً.
    enum Cards {
        static let title = "الكروت"
        static func name(_ type: CardType) -> String {
            switch type {
            case .clearSquares: "تفريغ المربعات"
            case .swapQuestion: "غيّر السؤال"
            case .placeAnywhere: "ضع في أي مربع"
            case .anyAnswer: "أي إجابة صح"
            case .burn: "تصدٍّ وحرق"
            case .doubleCross: "صليبان"
            case .fortify: "تحصين"
            }
        }
        static func line(_ type: CardType) -> String {
            switch type {
            case .clearSquares: "يفرّغ مربعاً أو مربعين مملوكين من أي موضع."
            case .swapQuestion: "يستبدل سؤالك بآخر، ويبدأ المؤقّت من جديد."
            case .placeAnywhere: "تضع مركز صليبك ولو على مربع مملوك."
            case .anyAnswer: "تُقبل إجابتك مهما كانت. العبه قبل أن تختار."
            case .burn: "يردّ مربعاتك إن اعتُدي عليها، خلال عشر ثوانٍ."
            case .doubleCross: "صليبان في موضعين بدل صليب واحد."
            case .fortify: "يجمّد صليباً على اللوح حتى يبدأ دورك الثالث بعده."
            }
        }
        static func icon(_ type: CardType) -> String {
            switch type {
            case .burn: "icon-flame"
            case .swapQuestion: "icon-refresh-cw"
            case .anyAnswer: "icon-circle-check"
            case .clearSquares: "icon-eraser"
            case .fortify: "icon-shield"
            case .doubleCross: "icon-copy-plus"
            case .placeAnywhere: "icon-crosshair"
            }
        }
        static func clearCount(_ n: Int) -> String { n == 1 ? "مربع واحد" : "مربعان" }
        static let play = "العبه"
        static let notNow = "ليس وقته."
        static let reactionOnly = "يعمل وحده إن اعتُدي على مربعاتك."
        static let questionWindow = "يُلعب في دورك قبل الإجابة."
        static let boardWindow = "يُلعب بعد الإصابة وقبل الاعتماد."
        static let notInGroup = "لا يعمل في الجولة الجماعية."
        static let swapLocked = "لا يُلعب بعد «أي إجابة صح»."
        static let oneBoardCard = "كرت لوح واحد في الدور."
        static let none = "لا كروت معك."
        /// سبب المنع من المحرّك (engine.ts: cardBlock) نصّاً.
        static func blocked(_ code: String) -> String {
            switch code {
            case "reaction": reactionOnly
            case "question_window": questionWindow
            case "board_window": boardWindow
            case "group": notInGroup
            case "swap_locked": swapLocked
            case "one_board_card": oneBoardCard
            default: notNow
            }
        }
        static let clearTarget = "اختر المربعات المملوكة التي تفرّغها"
        static let fortifyTarget = "اختر مركز التحصين"
        static let confirm = "اعتمد"
        static let cancel = "إلغاء"
        static let anyActive = "«أي إجابة صح» مفعّل: أي إجابة تُقبل."
        static let doubleActive = "«صليبان»: اختر مركزين."
        static let anywhereActive = "«ضع في أي مربع»: يجوز المركز على مربع مملوك."
    }

    enum Choice {
        static let square = "مربع"
        static func box(_ left: Int) -> String { "صندوق (\(left))" }
        static let openBox = "افتح الصندوق"
        static let boxesGone = "نفدت صناديقك."
        static let boxAfterCard = "بعد كرت اللوح يبقى المربع وحده."
        static func gotCard(_ name: String) -> String { "خرج لك: \(name)" }
        static func opened(_ name: String) -> String { "فتح \(name) صندوقاً" }
    }

    enum Group {
        static let title = "جولة جماعية"
        static let line = "سؤال للجميع: أسرع إجابة صحيحة تكسب الاختيار."
        static let answered = "أجاب"
        static let waiting = "وصلت إجابتك. ننتظر البقية…"
        static let noWinner = "لم يُصب أحد." // §١٠
        static func winner(_ name: String) -> String { "كسبها \(name)" }
    }

    enum Burn {
        static let title = "اعتُدي على مربعاتك"
        static func line(_ name: String, _ count: Int) -> String {
            "أخذ \(name) \(count == 1 ? "مربعاً واحداً" : count == 2 ? "مربعين" : "\(count) مربعات") منك. احرق لتعيدها."
        }
        static let burn = "احرق"
        static let skip = "تجاوز"
        static func waiting(_ names: String) -> String { "\(names) يقرّر الحرق…" }
        static let fortified = "محصّن"
    }

    /// المباراة السريعة أون لاين (M-06). ما عليه «§١٠» منقول من 05-ui حرفاً، والباقي مقترح يُعتمد مع البناء.
    enum Online {
        static let quickMatch = "مباراة سريعة"
        static let title = "مباراة سريعة"
        static let line = "تلعب مع لاعبين آخرين. وإن لم يكتمل العدد في 30 ثانية أكملناه بآليين."
        static let anySize = "أي حجم"
        static let search = "ابحث"
        static let searching = "نبحث عن لاعبين…" // §١٠
        static let searchingSlot = "نبحث…" // §٦
        static let botsAfter = "بعد 30 ثانية نكمل العدد بآليين."
        static let filledWithBots = "لم يكتمل العدد. أكملناه بلاعبين آليين." // §١٠
        static let secondAnswer = "أرسلت إجابتك. الأولى هي المعتمدة." // §١٠
        static let disconnected = "انقطع الاتصال بالمباراة. أعد المحاولة بعد قليل."
        static let noQuestions = "تعذّر تجهيز الأسئلة. أعد المحاولة بعد قليل."
        static let exitTitle = "الخروج من المباراة"
        static let exitConfirm = "تخرج، وتمضي المباراة بدونك."
        /// الردود الجاهزة (R-34): ترتيبها هو رقمها عند الخادم.
        static let replies = ["أحسنت", "حظًّا أوفر", "سؤال صعب", "ما شاء الله", "اقتربت", "مباراة حلوة"]
        static func reply(_ i: Int) -> String { replies.indices.contains(i) ? replies[i] : "" }
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
