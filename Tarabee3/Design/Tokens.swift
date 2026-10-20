// مولَّد من docs/spec/05-ui-tokens.json بـ tools/gen-tokens.mjs — لا يُعدَّل باليد.

enum Tokens {
    enum Color {
        static let ground: String = "#0D0F12"
        static let surface: String = "#181C22"
        static let surfaceRaised: String = "#20252D"
        static let line: String = "#2B323B"
        static let text: String = "#FFFFFF"
        static let textMuted: String = "#98A2B0"
        static let textOnLight: String = "#0D0F12"
        static let primary: String = "#FFFFFF"
        static let focus: String = "#FFFFFF"
        static let team1: String = "#E7234D"
        static let team2: String = "#FBB320"
        static let team3: String = "#0DAA94"
        static let team4: String = "#197AE7"
        static let team5: String = "#B437D1"
        static let previewAlpha: String = "0.40"
        static let disabledAlpha: String = "0.38"
    }
    enum Font {
        static let familyAr: String = "Readex Pro"
        static let familyLat: String = "Readex Pro"
        static let familyFallback: String = "system-ui, sans-serif"
        static let sizeDisplay: String = "40px"
        static let sizeH1: String = "28px"
        static let sizeH2: String = "22px"
        static let sizeBody: String = "16px"
        static let sizeSmall: String = "14px"
        static let sizeCaption: String = "12px"
        static let sizeTimer: String = "32px"
        static let weightRegular: String = "400"
        static let weightMedium: String = "500"
        static let weightBold: String = "700"
        static let lineHeightTight: String = "1.3"
        static let lineHeightBody: String = "1.6"
        static let numeric: String = "tabular-nums"
    }
    enum Space {
        static let unit: String = "4px"
        static let scale: [Double] = [4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0]
    }
    enum Radius {
        static let cell: String = "20%"
        static let control: String = "10px"
        static let card: String = "12px"
        static let sheet: String = "20px"
        static let pill: String = "999px"
    }
    enum Icon {
        static let source: String = "lucide"
        static let sizeSm: String = "20px"
        static let sizeMd: String = "24px"
        static let stroke: String = "2"
    }
    enum Touch {
        static let minTarget: String = "44px"
    }
    enum Motion {
        static let instant: String = "120ms"
        static let base: String = "200ms"
        static let reveal: String = "320ms"
        static let pulse: String = "600ms"
        static let easing: String = "cubic-bezier(0.2, 0.8, 0.2, 1)"
    }
    enum Contrast {
        static let textMin: String = "4.5"
        static let largeAndUiMin: String = "3"
    }
    enum Cell {
        static let gradientDirection: String = "top-left-to-bottom-right"
        static let team1: [String] = ["#F42A55", "#D91B45"]
        static let team2: [String] = ["#FFC12A", "#F6A516"]
        static let team3: [String] = ["#13B89D", "#079D8B"]
        static let team4: [String] = ["#218AF5", "#1169D9"]
        static let team5: [String] = ["#C443E0", "#A32BC2"]
        static let shineColor: String = "#FFFFFF"
        static let shineAlpha: String = "0.09"
        static let shineShape: String = "top-left-triangle"
    }
    enum Fortified {
        static let stripeColor: String = "#FFFFFF"
        static let stripeColorOnLightTeams: String = "#0D0F12"
        static let lightTeams: [String] = ["team-2"]
        static let stripeAlpha: String = "0.38"
        static let stripeWidth: String = "6%"
        static let stripePeriod: String = "24%"
    }
    enum Mode {
        static let `default`: String = "system"
        enum Light {
            static let ground: String = "#FBF7EF"
            static let surface: String = "#FFFFFF"
            static let surfaceRaised: String = "#F4EDE0"
            static let line: String = "#D8CCB5"
            static let text: String = "#1B1712"
            static let textMuted: String = "#6E6453"
            static let textOnLight: String = "#0D0F12"
            static let primary: String = "#1B1712"
            static let focus: String = "#1B1712"
            static let cellEmpty: String = "#E9E0CE"
        }
        static let lightCellShadow: String = "0 1px 2px rgba(13,15,18,0.10), 0 2px 4px rgba(13,15,18,0.06)"
        static let darkCellEmpty: String = "#181C22"
        static let lightCellShadowSmall: String = "0 1px 1px rgba(13,15,18,0.10)"
    }
    enum Persona {
        static let featureColor: String = "#0D0F12"
        static let eyeWhite: String = "#FFFFFF"
        static let eyeOutlineTeams: [String] = ["team-2", "team-3"]
        static let eyeOutlineWidth: String = "3%"
        static let outfitColors: [String] = ["#FFFFFF", "#0D0F12", "#E9E0CE", "#D8CCB5", "#C8102E"]
        enum Size {
            static let badge: String = "32px"
            static let resultFirst: String = "64px"
            static let profile: String = "120px"
            static let pickerCell: String = "56px"
            static let preview: String = "160px"
            static let lobbySlot: String = "40px"
            static let burn: String = "80px"
            static let simplifiedBelow: String = "24px"
            static let blinkMin: String = "48px"
            static let shemaghDetailMin: String = "40px"
        }
        static let blinkInterval: [String] = ["4s", "8s"]
        static let hopHeight: String = "15%"
        static let sadDuration: String = "1500ms"
        static let celebrateHops: Double = 3.0
    }
    enum Countdown {
        static let duration: String = "3000ms"
        static let step: String = "1000ms"
        static let sizeMobile: String = "160px"
        static let enterScale: String = "1.4"
    }
    enum Board {
        static let displayHold: String = "3000ms"
        static let cellMin: String = "28px"
        static let gap: String = "3px"
        static let gapSmall: String = "1px"
    }
    enum Layout {
        static let orientation: String = "portrait"
        static let widthMin: String = "375px"
        static let widthMax: String = "440px"
        static let ipad: String = "phone-scaled"
        static let banner: String = "adaptive-anchored"
        static let safeArea: String = "respect"
    }
    enum TypeScale {
        static let max: String = "1.3"
        static let fixed: [String] = ["board", "timer", "invite-code", "countdown"]
    }
    enum Haptics {
        static let yourTurn: String = "medium"
        static let send: String = "light"
        static let commit: String = "light"
        static let burnOpen: String = "heavy"
        static let lastFive: String = "light"
    }
    enum Seat {
        static let seat1: String = "team-1"
        static let seat2: String = "team-2"
        static let seat3: String = "team-3"
        static let seat4: String = "team-4"
        static let seat5: String = "team-5"
    }
    enum InviteCode {
        static let digits: Double = 6.0
        static let direction: String = "ltr"
        static let size: String = "32px"
    }
}
