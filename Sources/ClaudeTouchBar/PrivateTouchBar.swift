import AppKit

/// Ponte para as APIs privadas da Touch Bar (as mesmas usadas por Pock/MTMR).
/// Permitem colocar um item fixo na Control Strip (lado direito) e abrir uma
/// Touch Bar "modal de sistema", que aparece em qualquer app em primeiro plano.
enum PrivateTouchBar {
    private static let dfr: UnsafeMutableRawPointer? =
        dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_NOW)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let dfr, let sym = dlsym(dfr, name) else { NSLog("[ClaudeTouchBar] símbolo ausente: %@", name); return nil }
        return unsafeBitCast(sym, to: type)
    }

    static func setControlStripPresence(_ identifier: NSTouchBarItem.Identifier, _ present: Bool) {
        typealias Fn = @convention(c) (CFString, ObjCBool) -> Void
        symbol("DFRElementSetControlStripPresenceForIdentifier", as: Fn.self)?(
            identifier.rawValue as CFString, ObjCBool(present))
    }

    static func showsCloseBoxWhenFrontmost(_ value: Bool) {
        typealias Fn = @convention(c) (ObjCBool) -> Void
        symbol("DFRSystemModalShowsCloseBoxWhenFrontMost", as: Fn.self)?(ObjCBool(value))
    }

    static func addSystemTrayItem(_ item: NSTouchBarItem) {
        let sel = NSSelectorFromString("addSystemTrayItem:")
        let cls: AnyObject = NSTouchBarItem.self
        guard cls.responds(to: sel) else { NSLog("[ClaudeTouchBar] addSystemTrayItem: indisponível"); return }
        _ = cls.perform(sel, with: item)
        NSLog("[ClaudeTouchBar] addSystemTrayItem ok: %@", item.identifier.rawValue)
    }

    static func removeSystemTrayItem(_ item: NSTouchBarItem) {
        let sel = NSSelectorFromString("removeSystemTrayItem:")
        let cls: AnyObject = NSTouchBarItem.self
        guard cls.responds(to: sel) else { return }
        _ = cls.perform(sel, with: item)
    }

    static func presentSystemModal(_ bar: NSTouchBar, trayIdentifier: NSTouchBarItem.Identifier) {
        let cls: AnyObject = NSTouchBar.self
        let modern = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
        let legacy = NSSelectorFromString("presentSystemModalFunctionBar:systemTrayItemIdentifier:")
        let sel = cls.responds(to: modern) ? modern : legacy
        guard cls.responds(to: sel) else { return }
        _ = cls.perform(sel, with: bar, with: trayIdentifier.rawValue as NSString)
        NSLog("[ClaudeTouchBar] painel apresentado via %@", NSStringFromSelector(sel))
    }

    static func dismissSystemModal(_ bar: NSTouchBar) {
        let cls: AnyObject = NSTouchBar.self
        let modern = NSSelectorFromString("dismissSystemModalTouchBar:")
        let legacy = NSSelectorFromString("dismissSystemModalFunctionBar:")
        let sel = cls.responds(to: modern) ? modern : legacy
        guard cls.responds(to: sel) else { return }
        _ = cls.perform(sel, with: bar)
    }
}
