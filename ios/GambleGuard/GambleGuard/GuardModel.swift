import FamilyControls
import Foundation
import ManagedSettings

/// Screen Time layer. Everything set here lives in the system's ManagedSettingsStore: it survives
/// relaunches and reboots, and is cleared only if the app's Screen Time access is revoked, which
/// the Screen Time passcode protects.
@MainActor @Observable
final class GuardModel {
    private let store = ManagedSettingsStore()
    private let selectionKey = "selection"

    var status = AuthorizationCenter.shared.authorizationStatus
    private(set) var blockedDomainCount = 0
    private(set) var isLocked = false
    var error: String?
    /// Apps and sites picked in FamilyActivityPicker; the view calls applyShields() when it changes.
    var selection = FamilyActivitySelection()

    var isAuthorized: Bool { status != .notDetermined && status != .denied }

    init() {
        isLocked = store.application.denyAppRemoval == true
        if let data = UserDefaults.standard.data(forKey: selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        }
    }

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Re-reads the status and re-applies the web filter, so a new bundled list ships with an app update.
    func refresh() {
        status = AuthorizationCenter.shared.authorizationStatus
        if isAuthorized { applyWebFilter() }
    }

    /// Apple's adult-content filter plus the bundled list, in every browser on the phone.
    /// Apple documents no cap on the set; if the policy does not read back intact, the core brands
    /// are applied instead so the block is never silently empty.
    func applyWebFilter() {
        let full: WebContentSettings.FilterPolicy = .auto(Blocklist.bundled.union(Blocklist.core), except: [])
        store.webContent.blockedByFilter = full
        if store.webContent.blockedByFilter != full {
            store.webContent.blockedByFilter = .auto(Blocklist.core, except: [])
        }
        if case .auto(let domains, _)? = store.webContent.blockedByFilter {
            blockedDomainCount = domains.count
        }
    }

    func applyShields() {
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens, except: [])
        store.shield.webDomains = selection.webDomainTokens
        UserDefaults.standard.set(try? JSONEncoder().encode(selection), forKey: selectionKey)
    }

    /// Screen Time "Deleting Apps: Don't Allow" for the whole phone, this app included.
    func lock() {
        store.application.denyAppRemoval = true
        isLocked = true
    }
}

enum Blocklist {
    /// Resources/blocklist.txt: a slice of lists/compact.txt in hosts format ("0.0.0.0 domain").
    static let bundled: Set<WebDomain> = {
        let url = Bundle.main.url(forResource: "blocklist", withExtension: "txt")
        let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let domains = Set<WebDomain>(text.split(whereSeparator: \.isNewline).compactMap { line in
            guard line.hasPrefix("0.0.0.0 "), let domain = line.split(separator: " ").last else { return nil }
            return WebDomain(domain: String(domain))
        })
        assert(domains.count > 1000, "Resources/blocklist.txt is missing or not in hosts format")
        return domains
    }()

    /// The brands people actually reach for, by region: Canada, US, South America, UK and Europe
    /// (Malta-licensed brands included), Romania, Australia, then the crypto and offshore sites.
    static let core: Set<WebDomain> = Set("""
        lotoquebec.com espacejeux.com playnow.com olg.ca proline.ca playalberta.ca bclc.com wclc.com \
        bet99.com sportsinteraction.com thescore.bet northstarbets.ca
        bet365.com draftkings.com fanduel.com betmgm.com caesars.com betrivers.com pointsbet.com \
        espnbet.com hardrock.bet prizepicks.com underdogfantasy.com bovada.lv betonline.ag mybookie.ag \
        ignitioncasino.eu bodog.eu
        betano.com betsson.com codere.es codere.mx codere.com.co pixbet.com blaze.com estrelabet.com betnacional.com \
        apostaganha.bet esportesdasorte.com sportingbet.com
        williamhill.com ladbrokes.com paddypower.com betfair.com skybet.com coral.co.uk betvictor.com \
        betfred.com unibet.com bwin.com 888casino.com 888sport.com 888poker.com pokerstars.com \
        partypoker.com ggpoker.com leovegas.com mrgreen.com casumo.com videoslots.com tipico.de \
        bet-at-home.com interwetten.com winamax.fr pmu.fr betclic.com snai.it sisal.it lottomatica.it \
        eurobet.it pinnacle.com betway.com 10bet.com 22bet.com
        superbet.ro betano.ro unibet.ro efortuna.ro maxbet.ro casapariurilor.ro netbet.ro winner.ro \
        admiral.ro princesscasino.ro stanleybet.ro publicwin.ro getsbet.ro vladcazino.ro frankcasino.ro don.ro favbet.ro
        sportsbet.com.au tab.com.au ladbrokes.com.au bet365.com.au neds.com.au pointsbet.com.au \
        betr.com.au unibet.com.au tabtouch.com.au picklebet.com dabble.com.au palmerbet.com \
        bluebet.com.au playup.com.au
        stake.com stake.us stake.bet roobet.com rainbet.com rollbit.com duelbits.com gamdom.com bc.game \
        bcgame.com shuffle.com betfury.io bitcasino.io cloudbet.com thunderpick.io 1xbet.com melbet.com \
        betwinner.com parimatch.com mostbet.com pin-up.casino pin-up.bet vulkanvegas.com mystake.com \
        bitstarz.com csgoempire.com csgoroll.com hypedrop.com keydrop.com rustclash.com trustdice.win \
        primedice.com jackbit.com metaspins.com wild.io luckyblock.com betplay.io winna.com bitsler.com \
        fortunejack.com 1xbit.com coinpoker.com betchain.com mbitcasino.com sportbet.one jackpotcity.com \
        spincasino.com rubyfortune.com royalvegas.com luckynugget.com
        """.split(whereSeparator: \.isWhitespace).map { WebDomain(domain: String($0)) })
}
