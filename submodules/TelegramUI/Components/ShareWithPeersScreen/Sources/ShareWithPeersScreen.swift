import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import SolidRoundedButtonComponent
import PresentationDataUtils
import ButtonComponent
import PlainButtonComponent
import AnimatedCounterComponent
import TokenListTextField
import AvatarNode
import LocalizedPeerData
import PeerListItemComponent
import LottieComponent
import TooltipUI

final class ShareWithPeersScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let stateContext: ShareWithPeersScreen.StateContext
    let initialPrivacy: EngineStoryPrivacy
    let screenshot: Bool
    let pin: Bool
    let timeout: Int
    let mentions: [String]
    let categoryItems: [CategoryItem]
    let optionItems: [OptionItem]
    let completion: (EngineStoryPrivacy, Bool, Bool, [EnginePeer]) -> Void
    let editCategory: (EngineStoryPrivacy, Bool, Bool) -> Void
    
    init(
        context: AccountContext,
        stateContext: ShareWithPeersScreen.StateContext,
        initialPrivacy: EngineStoryPrivacy,
        screenshot: Bool,
        pin: Bool,
        timeout: Int,
        mentions: [String],
        categoryItems: [CategoryItem],
        optionItems: [OptionItem],
        completion: @escaping (EngineStoryPrivacy, Bool, Bool, [EnginePeer]) -> Void,
        editCategory: @escaping (EngineStoryPrivacy, Bool, Bool) -> Void
    ) {
        self.context = context
        self.stateContext = stateContext
        self.initialPrivacy = initialPrivacy
        self.screenshot = screenshot
        self.pin = pin
        self.timeout = timeout
        self.mentions = mentions
        self.categoryItems = categoryItems
        self.optionItems = optionItems
        self.completion = completion
        self.editCategory = editCategory
    }
    
    static func ==(lhs: ShareWithPeersScreenComponent, rhs: ShareWithPeersScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.stateContext !== rhs.stateContext {
            return false
        }
        if lhs.initialPrivacy != rhs.initialPrivacy {
            return false
        }
        if lhs.screenshot != rhs.screenshot {
            return false
        }
        if lhs.pin != rhs.pin {
            return false
        }
        if lhs.timeout != rhs.timeout {
            return false
        }
        if lhs.mentions != rhs.mentions {
            return false
        }
        if lhs.categoryItems != rhs.categoryItems {
            return false
        }
        if lhs.optionItems != rhs.optionItems {
            return false
        }
        return true
    }
    
    enum Style {
        case plain
        case blocks
    }
    
    private struct ItemLayout: Equatable {
        struct Section: Equatable {
            var id: Int
            var insets: UIEdgeInsets
            var itemHeight: CGFloat
            var itemCount: Int
            
            var totalHeight: CGFloat
            
            init(
                id: Int,
                insets: UIEdgeInsets,
                itemHeight: CGFloat,
                itemCount: Int
            ) {
                self.id = id
                self.insets = insets
                self.itemHeight = itemHeight
                self.itemCount = itemCount
                
                self.totalHeight = insets.top + itemHeight * CGFloat(itemCount)
            }
        }
        
        var style: ShareWithPeersScreenComponent.Style
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var navigationHeight: CGFloat
        var sections: [Section]
        
        var contentHeight: CGFloat
        
        init(style: ShareWithPeersScreenComponent.Style, containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, navigationHeight: CGFloat, sections: [Section]) {
            self.style = style
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.navigationHeight = navigationHeight
            self.sections = sections
            
            var contentHeight: CGFloat = 0.0
            contentHeight += navigationHeight
            for section in sections {
                contentHeight += section.totalHeight
            }
            contentHeight += bottomInset
            self.contentHeight = contentHeight
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class AnimationHint {
        let contentReloaded: Bool
        
        init(
            contentReloaded: Bool
        ) {
            self.contentReloaded = contentReloaded
        }
    }
    
    enum CategoryColor {
        case blue
        case yellow
        case green
        case purple
        case red
        case violet
    }
    
    enum CategoryId: Int, Hashable {
        case everyone = 0
        case contacts = 1
        case closeFriends = 2
        case selectedContacts = 3
    }
    
    final class CategoryItem: Equatable {
        let id: CategoryId
        let title: String
        let icon: String?
        let iconColor: CategoryColor
        let actionTitle: String?
        
        init(
            id: CategoryId,
            title: String,
            icon: String?,
            iconColor: CategoryColor,
            actionTitle: String?
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.iconColor = iconColor
            self.actionTitle = actionTitle
        }
        
        static func ==(lhs: CategoryItem, rhs: CategoryItem) -> Bool {
            if lhs === rhs {
                return true
            }
            return false
        }
    }
    
    final class PeerItem: Equatable {
        let id: EnginePeer.Id
        let peer: EnginePeer?
        
        init(
            id: EnginePeer.Id,
            peer: EnginePeer?
        ) {
            self.id = id
            self.peer = peer
        }
        
        static func ==(lhs: PeerItem, rhs: PeerItem) -> Bool {
            if lhs === rhs {
                return true
            }
            return false
        }
    }
    
    enum OptionId: Int, Hashable {
        case screenshot = 0
        case pin = 1
    }
    
    final class OptionItem: Equatable {
        let id: OptionId
        let title: String
        
        init(
            id: OptionId,
            title: String
        ) {
            self.id = id
            self.title = title
        }
        
        static func ==(lhs: OptionItem, rhs: OptionItem) -> Bool {
            if lhs === rhs {
                return true
            }
            return false
        }
    }
        
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundView: UIImageView
        
        private let navigationContainerView: UIView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationTitle = ComponentView<Empty>()
        private let navigationLeftButton = ComponentView<Empty>()
        private let navigationRightButton = ComponentView<Empty>()
        private let navigationSeparatorLayer: SimpleLayer
        private let navigationTextFieldState = TokenListTextField.ExternalState()
        private let navigationTextField = ComponentView<Empty>()
        private let textFieldSeparatorLayer: SimpleLayer
        
        private let emptyResultsTitle = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let emptyResultsAnimation = ComponentView<Empty>()
        
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let bottomBackgroundView: BlurredBackgroundView
        private let bottomSeparatorLayer: SimpleLayer
        private let actionButton = ComponentView<Empty>()
        
        private let categoryTemplateItem = ComponentView<Empty>()
        private let peerTemplateItem = ComponentView<Empty>()
        private let optionTemplateItem = ComponentView<Empty>()
        
        private let itemContainerView: UIView
        private var visibleSectionHeaders: [Int: ComponentView<Empty>] = [:]
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        private var visibleSectionBackgrounds: [Int: UIView] = [:]
        private var visibleSectionFooters: [Int: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        private var isDismissed: Bool = false
        
        private var savedSelectedPeers: [EnginePeer.Id] = []
        private var selectedPeers: [EnginePeer.Id] = []
        private var selectedCategories = Set<CategoryId>()
        private var selectedOptions = Set<OptionId>()
        
        private var component: ShareWithPeersScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var defaultStateValue: ShareWithPeersScreen.State?
        private var stateDisposable: Disposable?
        
        private var searchStateContext: ShareWithPeersScreen.StateContext?
        private var searchStateDisposable: Disposable?
        
        private var effectiveStateValue: ShareWithPeersScreen.State? {
            return self.searchStateContext?.stateValue ?? self.defaultStateValue
        }
        
        private struct DismissPanState: Equatable {
            var translation: CGFloat
            
            init(translation: CGFloat) {
                self.translation = translation
            }
        }
        
        private var dismissPanGesture: UIPanGestureRecognizer?
        private var dismissPanState: DismissPanState?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = SparseContainerView()
            
            self.backgroundView = UIImageView()
            
            self.navigationContainerView = SparseContainerView()
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationSeparatorLayer = SimpleLayer()
            self.textFieldSeparatorLayer = SimpleLayer()
            
            self.bottomBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.bottomSeparatorLayer = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 10.0
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.backgroundView)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.scrollContentView.addSubview(self.itemContainerView)
            
            self.containerView.addSubview(self.navigationContainerView)
            self.navigationContainerView.addSubview(self.navigationBackgroundView)
            self.navigationContainerView.layer.addSublayer(self.navigationSeparatorLayer)
            
            self.containerView.addSubview(self.bottomBackgroundView)
            self.containerView.layer.addSublayer(self.bottomSeparatorLayer)
            
            let dismissPanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.dismissPanGesture(_:)))
            self.containerView.addGestureRecognizer(dismissPanGesture)
            self.dismissPanGesture = dismissPanGesture
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            if scrollView.contentOffset.y <= -100.0 && velocity.y <= -2.0 {
            } else {
                var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
                if topOffset > 0.0 {
                    topOffset = max(0.0, topOffset)
                    
                    if topOffset < topOffsetDistance {
                        //targetContentOffset.pointee.y = scrollView.contentOffset.y
                        //scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
                    }
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundView.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationContainerView.hitTest(self.convert(point, to: self.navigationContainerView), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                    return
                }
                controller.requestDismiss()
            }
        }
        
        @objc private func dismissPanGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let controller = self.environment?.controller() as? ShareWithPeersScreen else {
                return
            }
            switch recognizer.state {
            case .began:
                controller.dismissAllTooltips()
                
                self.dismissPanState = DismissPanState(translation: 0.0)
                self.state?.updated(transition: .immediate)
            case .changed:
                let translation = recognizer.translation(in: self)
                self.dismissPanState = DismissPanState(translation: translation.y)
                self.state?.updated(transition: .immediate)
            case .cancelled, .ended:
                if self.dismissPanState != nil {
                    let translation = recognizer.translation(in: self)
                    let velocity = recognizer.velocity(in: self)
                    
                    self.dismissPanState = nil
                
                    if translation.y > 100.0 || velocity.y > 10.0 {
                        controller.requestDismiss()
                    } else {
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                    }
                }
            default:
                break
            }
        }
        
        private func presentOptionsTooltip(optionId: OptionId) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let animationName: String
            let text: String
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            switch optionId {
            case .screenshot:
                if self.selectedOptions.contains(.screenshot) {
                    if self.selectedCategories.contains(.everyone) {
                        animationName = "anim_savemedia"
                        text = presentationData.strings.Story_Privacy_TooltipSharingEnabledPublic
                    } else {
                        animationName = "anim_savemedia"
                        text = presentationData.strings.Story_Privacy_TooltipSharingEnabled
                    }
                } else {
                    if self.selectedCategories.contains(.everyone) {
                        animationName = "premium_unlock"
                        text = presentationData.strings.Story_Privacy_TooltipSharingDisabledPublic
                    } else {
                        animationName = "premium_unlock"
                        text = presentationData.strings.Story_Privacy_TooltipSharingDisabled
                    }
                }
            case .pin:
                if self.selectedOptions.contains(.pin) {
                    animationName = "anim_profileadd"
                    text = presentationData.strings.Story_Privacy_TooltipStoryArchived
                } else {
                    animationName = "anim_autoremove_on"
                    text = presentationData.strings.Story_Privacy_TooltipStoryExpires
                }
            }
            
            let tooltipScreen = TooltipScreen(
                context: component.context,
                account: component.context.account,
                sharedContext: component.context.sharedContext,
                text: .markdown(text: text),
                style: .wide,
                icon: .animation(name: animationName, delay: 0.0, tintColor: .white),
                location: .top,
                displayDuration: .custom(4.0),
                shouldDismissOnTouch: { point, _ in
                    return .ignore
                }
            )
            
            controller.window?.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss(inPlace: true)
                }
            })
            
            controller.present(tooltipScreen, in: .window(.root))
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout else {
                return
            }
            guard let stateValue = self.effectiveStateValue else {
                return
            }
                        
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundView.layer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            transition.setPosition(view: self.navigationContainerView, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let bottomDistance = itemLayout.contentHeight - self.scrollView.bounds.maxY
            let bottomAlphaDistance: CGFloat = 30.0
            var bottomAlpha: CGFloat = bottomDistance / bottomAlphaDistance
            bottomAlpha = max(0.0, min(1.0, bottomAlpha))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            //let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            //controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
            
            var visibleBounds = self.scrollView.bounds
            visibleBounds.origin.y -= itemLayout.topInset
            visibleBounds.size.height += itemLayout.topInset
            
            var visibleFrame = self.scrollView.frame
            visibleFrame.origin.x = 0.0
            visibleFrame.origin.y -= itemLayout.topInset
            visibleFrame.size.height += itemLayout.topInset
            
            var validIds: [AnyHashable] = []
            var validSectionHeaders: [AnyHashable] = []
            var validSectionBackgrounds: [AnyHashable] = []
            var sectionOffset: CGFloat = itemLayout.navigationHeight
            for sectionIndex in 0 ..< itemLayout.sections.count {
                let section = itemLayout.sections[sectionIndex]
                        
                if case .blocks = itemLayout.style {
                    let sectionBackgroundFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top), size: CGSize(width: itemLayout.containerSize.width, height: section.totalHeight - section.insets.top))
                    
                    if visibleFrame.intersects(sectionBackgroundFrame) {
                        validSectionBackgrounds.append(section.id)
                        
                        var sectionBackground: UIView
                        var sectionBackgroundTransition = transition
                        if let current = self.visibleSectionBackgrounds[section.id] {
                            sectionBackground = current
                        } else {
                            if !transition.animation.isImmediate {
                                sectionBackgroundTransition = .immediate
                            }
                            sectionBackground = UIView()
                            sectionBackground.backgroundColor = environment.theme.list.itemModalBlocksBackgroundColor
                            sectionBackground.layer.cornerRadius = 10.0
                            self.visibleSectionBackgrounds[section.id] = sectionBackground
                        }
                        
                        if sectionBackground.superview == nil {
                            sectionBackground.isUserInteractionEnabled = false
                            self.itemContainerView.addSubview(sectionBackground)
                        }
                        sectionBackgroundTransition.setFrame(view: sectionBackground, frame: sectionBackgroundFrame)
                    }
                }
                
                var minSectionHeader: UIView?
                do {
                    var sectionHeaderFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: itemLayout.containerInset + sectionOffset - self.scrollView.bounds.minY + itemLayout.topInset), size: CGSize(width: itemLayout.containerSize.width, height: section.insets.top))
                    
                    let sectionHeaderMinY = topOffset + itemLayout.containerInset + itemLayout.navigationHeight
                    let sectionHeaderMaxY = itemLayout.containerInset + sectionOffset - self.scrollView.bounds.minY + itemLayout.topInset + section.totalHeight - 28.0
                    
                    sectionHeaderFrame.origin.y = max(sectionHeaderFrame.origin.y, sectionHeaderMinY)
                    sectionHeaderFrame.origin.y = min(sectionHeaderFrame.origin.y, sectionHeaderMaxY)
                    
                    if visibleFrame.intersects(sectionHeaderFrame) {
                        validSectionHeaders.append(section.id)
                        let sectionHeader: ComponentView<Empty>
                        var sectionHeaderTransition = transition
                        if let current = self.visibleSectionHeaders[section.id] {
                            sectionHeader = current
                        } else {
                            if !transition.animation.isImmediate {
                                sectionHeaderTransition = .immediate
                            }
                            sectionHeader = ComponentView()
                            self.visibleSectionHeaders[section.id] = sectionHeader
                        }
                        
                        let sectionTitle: String
                        if section.id == 0 {
                            sectionTitle = environment.strings.Story_Privacy_WhoCanViewHeader
                        } else if section.id == 1 {
                            sectionTitle = environment.strings.Story_Privacy_ContactsHeader
                        } else {
                            sectionTitle = ""
                        }
                        
                        let _ = sectionHeader.update(
                            transition: sectionHeaderTransition,
                            component: AnyComponent(SectionHeaderComponent(
                                theme: environment.theme,
                                style: itemLayout.style,
                                title: sectionTitle
                            )),
                            environment: {},
                            containerSize: sectionHeaderFrame.size
                        )
                        if let sectionHeaderView = sectionHeader.view {
                            if sectionHeaderView.superview == nil {
                                sectionHeaderView.isUserInteractionEnabled = false
                                self.scrollContentClippingView.addSubview(sectionHeaderView)
                            }
                            if minSectionHeader == nil {
                                minSectionHeader = sectionHeaderView
                            }
                            sectionHeaderTransition.setFrame(view: sectionHeaderView, frame: sectionHeaderFrame.offsetBy(dx: self.scrollView.frame.minX, dy: 0.0))
                        }
                    }
                }
                
                if section.id == 0 {
                    for i in 0 ..< component.categoryItems.count {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let item = component.categoryItems[i]
                        let categoryId = item.id
                        let itemId = AnyHashable(item.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(CategoryListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                title: item.title,
                                color: item.iconColor,
                                iconName: item.icon,
                                subtitle: item.actionTitle,
                                selectionState: .editing(isSelected: self.selectedCategories.contains(item.id), isTinted: false),
                                hasNext: i != component.categoryItems.count - 1,
                                action: { [weak self] in
                                    guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                                        return
                                    }
                                    if self.selectedCategories.contains(categoryId) {
                                    } else {
                                        if self.selectedCategories.contains(.selectedContacts) {
                                            self.savedSelectedPeers = self.selectedPeers
                                        }
                                        if categoryId == .selectedContacts {
                                            self.selectedPeers = self.savedSelectedPeers
                                        } else {
                                            self.selectedPeers = []
                                        }
                                        
                                        self.selectedCategories.removeAll()
                                        self.selectedCategories.insert(categoryId)
                                        
                                        if self.selectedPeers.isEmpty && categoryId == .selectedContacts {
                                            component.editCategory(
                                                EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: []),
                                                self.selectedOptions.contains(.screenshot),
                                                self.selectedOptions.contains(.pin)
                                            )
                                            controller.dismissAllTooltips()
                                            controller.dismiss()
                                        }
                                    }
                                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.35, curve: .spring)))
                                },
                                secondaryAction: { [weak self] in
                                    guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                                        return
                                    }
                                    let base: EngineStoryPrivacy.Base?
                                    switch categoryId {
                                    case .everyone:
                                        base = nil
                                    case .contacts:
                                        base = .contacts
                                    case .closeFriends:
                                        base = .closeFriends
                                    case .selectedContacts:
                                        base = .nobody
                                    }
                                    if let base {
                                        component.editCategory(
                                            EngineStoryPrivacy(base: base, additionallyIncludePeers: self.selectedPeers),
                                            self.selectedOptions.contains(.screenshot),
                                            self.selectedOptions.contains(.pin)
                                        )
                                        controller.dismissAllTooltips()
                                        controller.dismiss()
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                if let minSectionHeader {
                                    self.itemContainerView.insertSubview(itemView, belowSubview: minSectionHeader)
                                } else {
                                    self.itemContainerView.addSubview(itemView)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                } else if section.id == 1 {
                    for i in 0 ..< stateValue.peers.count {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let peer = stateValue.peers[i]
                        let itemId = AnyHashable(peer.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(PeerListItemComponent(
                                context: component.context,
                                theme: environment.theme,
                                strings: environment.strings,
                                style: .generic,
                                sideInset: itemLayout.sideInset,
                                title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                                peer: peer,
                                subtitle: nil,
                                subtitleAccessory: .none,
                                presence: stateValue.presences[peer.id],
                                selectionState: .editing(isSelected: self.selectedPeers.contains(peer.id), isTinted: false),
                                hasNext: true,
                                action: { [weak self] peer in
                                    guard let self else {
                                        return
                                    }
                                    if let index = self.selectedPeers.firstIndex(of: peer.id) {
                                        self.selectedPeers.remove(at: index)
                                    } else {
                                        self.selectedPeers.append(peer.id)
                                    }
                                    
                                    let transition = Transition(animation: .curve(duration: 0.35, curve: .spring))
                                    self.state?.updated(transition: transition)
                                    
                                    if self.searchStateContext != nil {
                                        if let navigationTextFieldView = self.navigationTextField.view as? TokenListTextField.View {
                                            navigationTextFieldView.clearText()
                                        }
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                self.itemContainerView.addSubview(itemView)
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                } else if section.id == 2 {
                    for i in 0 ..< component.optionItems.count {
                        let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                        if !visibleBounds.intersects(itemFrame) {
                            continue
                        }
                        
                        let item = component.optionItems[i]
                        let optionId = item.id
                        let itemId = AnyHashable(item.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.visibleItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.visibleItems[itemId] = visibleItem
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(OptionListItemComponent(
                                theme: environment.theme,
                                title: item.title,
                                hasNext: i != component.optionItems.count - 1,
                                selected: self.selectedOptions.contains(item.id),
                                selectionChanged: { [weak self] selected in
                                    if let self {
                                        if selected {
                                            self.selectedOptions.insert(optionId)
                                        } else {
                                            self.selectedOptions.remove(optionId)
                                        }
                                        let transition = Transition(animation: .curve(duration: 0.35, curve: .spring))
                                        self.state?.updated(transition: transition)
                                        
                                        self.presentOptionsTooltip(optionId: optionId)
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                if let minSectionHeader {
                                    self.itemContainerView.insertSubview(itemView, belowSubview: minSectionHeader)
                                } else {
                                    self.itemContainerView.addSubview(itemView)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    
                    let sectionFooter: ComponentView<Empty>
                    var sectionFooterTransition = transition
                    if let current = self.visibleSectionFooters[section.id] {
                        sectionFooter = current
                    } else {
                        if !transition.animation.isImmediate {
                            sectionFooterTransition = .immediate
                        }
                        sectionFooter = ComponentView()
                        self.visibleSectionFooters[section.id] = sectionFooter
                    }
                    
                    let footerValue = environment.strings.Story_Privacy_KeepOnMyPageHours(Int32(component.timeout / 3600))
                    let footerText = environment.strings.Story_Privacy_KeepOnMyPageInfo(footerValue).string
                    let footerSize = sectionFooter.update(
                        transition: sectionFooterTransition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor)),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerSize.width - 16.0 * 2.0, height: itemLayout.contentHeight)
                    )
                    let footerFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset + 16.0, y: sectionOffset + section.totalHeight + 7.0), size: footerSize)
                    if let footerView = sectionFooter.view {
                        if footerView.superview == nil {
                            self.itemContainerView.addSubview(footerView)
                        }
                        sectionFooterTransition.setFrame(view: footerView, frame: footerFrame)
                    }
                }
                
                sectionOffset += section.totalHeight
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            var removeSectionHeaderIds: [Int] = []
            for (id, item) in self.visibleSectionHeaders {
                if !validSectionHeaders.contains(id) {
                    removeSectionHeaderIds.append(id)
                    if let itemView = item.view {
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removeSectionHeaderIds {
                self.visibleSectionHeaders.removeValue(forKey: id)
            }
            
            var removeSectionBackgroundIds: [Int] = []
            for (id, item) in self.visibleSectionBackgrounds {
                if !validSectionBackgrounds.contains(id) {
                    removeSectionBackgroundIds.append(id)
                    item.removeFromSuperview()
                }
            }
            for id in removeSectionBackgroundIds {
                self.visibleSectionBackgrounds.removeValue(forKey: id)
            }
            
            let fadeTransition = Transition.easeInOut(duration: 0.25)
            if let searchStateContext = self.searchStateContext, case let .search(query, _) = searchStateContext.subject, let value = searchStateContext.stateValue, value.peers.isEmpty {
                let sideInset: CGFloat = 44.0
                let emptyAnimationHeight = 148.0
                let topInset: CGFloat = topOffset + itemLayout.containerInset + 40.0
                let bottomInset: CGFloat = max(environment.safeInsets.bottom, environment.inputHeight)
                let visibleHeight = visibleFrame.height
                let emptyAnimationSpacing: CGFloat = 8.0
                let emptyTextSpacing: CGFloat = 8.0
                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Contacts_Search_NoResults, font: Font.semibold(17.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: visibleFrame.size
                )
                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Contacts_Search_NoResultsQueryDescription(query).string, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: visibleFrame.width - sideInset * 2.0, height: visibleFrame.height)
                )
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
      
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsTextSize.height + emptyTextSpacing
                let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                
                let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
                
                let emptyResultsTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsTextSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsTextSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    transition.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTextFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsText.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundView.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationContainerView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomBackgroundView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomSeparatorLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.isDismissed = true
            
            if let controller = self.environment?.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
            
            var animateOffset: CGFloat = self.bounds.height - self.backgroundView.frame.minY
            if self.scrollView.contentOffset.y < 0.0 {
                animateOffset += -self.scrollView.contentOffset.y
            }
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationContainerView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomBackgroundView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomSeparatorLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
        }
        
        func update(component: ShareWithPeersScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            guard !self.isDismissed else {
                return availableSize
            }
            let animationHint = transition.userData(AnimationHint.self)
            
            var contentTransition = transition
            if let animationHint, animationHint.contentReloaded, !transition.animation.isImmediate {
                contentTransition = .immediate
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            var sideInset: CGFloat = 0.0
            if case .stories = component.stateContext.subject {
                sideInset = 16.0
                self.scrollView.bounces = false
                self.dismissPanGesture?.isEnabled = true
            } else {
                self.scrollView.bounces = true
                self.dismissPanGesture?.isEnabled = false
            }
            
            let containerWidth: CGFloat
            if case .regular = environment.metrics.widthClass {
                containerWidth = 390.0
            } else {
                containerWidth = availableSize.width
            }
            let containerSideInset = floorToScreenPixels((availableSize.width - containerWidth) / 2.0)
            
            if self.component == nil {
                switch component.initialPrivacy.base {
                case .everyone:
                    self.selectedCategories.insert(.everyone)
                case .closeFriends:
                    self.selectedCategories.insert(.closeFriends)
                case .contacts:
                    self.selectedCategories.insert(.contacts)
                case .nobody:
                    self.selectedCategories.insert(.selectedContacts)
                }
                
                if component.screenshot {
                    self.selectedOptions.insert(.screenshot)
                }
                if component.pin {
                    self.selectedOptions.insert(.pin)
                }
                
                var applyState = false
                self.defaultStateValue = component.stateContext.stateValue
                self.selectedPeers = Array(component.stateContext.initialPeerIds)
                
                self.stateDisposable = (component.stateContext.state
                |> deliverOnMainQueue).start(next: { [weak self] stateValue in
                    guard let self else {
                        return
                    }
                    self.defaultStateValue = stateValue
                    if applyState {
                        self.state?.updated(transition: .immediate)
                    }
                })
                applyState = true
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                
                self.scrollView.indicatorStyle = environment.theme.overallDarkAppearance ? .white : .black
                
                self.backgroundView.image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    if case .stories = component.stateContext.subject {
                        context.setFillColor(environment.theme.list.modalBlocksBackgroundColor.cgColor)
                    } else {
                        context.setFillColor(environment.theme.list.plainBackgroundColor.cgColor)
                    }
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height * 0.5), size: CGSize(width: size.width, height: size.height * 0.5)))
                })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 19)
                
                if case .stories = component.stateContext.subject {
                    self.navigationBackgroundView.updateColor(color: environment.theme.list.modalBlocksBackgroundColor, transition: .immediate)
                    self.navigationSeparatorLayer.backgroundColor = UIColor.clear.cgColor
                    self.bottomBackgroundView.updateColor(color: environment.theme.list.modalBlocksBackgroundColor, transition: .immediate)
                    self.bottomSeparatorLayer.backgroundColor = UIColor.clear.cgColor
                } else {
                    self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                    self.navigationSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                    self.bottomBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                    self.bottomSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                }
                
                self.textFieldSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            
            let itemLayoutStyle: ShareWithPeersScreenComponent.Style
            let itemsContainerWidth: CGFloat
            let navigationTextFieldSize: CGSize
            if case .stories = component.stateContext.subject {
                itemLayoutStyle = .blocks
                itemsContainerWidth = containerWidth - sideInset * 2.0
                navigationTextFieldSize = .zero
            } else {
                itemLayoutStyle = .plain
                itemsContainerWidth = containerWidth
                
                var tokens: [TokenListTextField.Token] = []
                for peerId in self.selectedPeers {
                    guard let stateValue = self.defaultStateValue, let peer = stateValue.peers.first(where: { $0.id == peerId }) else {
                        continue
                    }
                    tokens.append(TokenListTextField.Token(
                        id: AnyHashable(peerId),
                        title: peer.compactDisplayTitle,
                        fixedPosition: nil,
                        content: .peer(peer)
                    ))
                }
                
                let placeholder: String
                switch component.stateContext.subject {
                case .chats:
                    placeholder = environment.strings.Story_Privacy_SearchChats
                default:
                    placeholder = environment.strings.Story_Privacy_SearchContacts
                }
                self.navigationTextField.parentState = state
                navigationTextFieldSize = self.navigationTextField.update(
                    transition: transition,
                    component: AnyComponent(TokenListTextField(
                        externalState: self.navigationTextFieldState,
                        context: component.context,
                        theme: environment.theme,
                        placeholder: placeholder,
                        tokens: tokens,
                        sideInset: sideInset,
                        deleteToken: { [weak self] tokenId in
                            guard let self else {
                                return
                            }
                            if let categoryId = tokenId.base as? CategoryId {
                                self.selectedCategories.remove(categoryId)
                            } else if let peerId = tokenId.base as? EnginePeer.Id {
                                self.selectedPeers.removeAll(where: { $0 == peerId })
                            }
                            if self.selectedCategories.isEmpty {
                                self.selectedCategories.insert(.everyone)
                            }
                            self.state?.updated(transition: Transition(animation: .curve(duration: 0.35, curve: .spring)))
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: containerWidth, height: 1000.0)
                )
                
                if !self.navigationTextFieldState.text.isEmpty {
                    var onlyContacts = false
                    if component.initialPrivacy.base == .closeFriends || component.initialPrivacy.base == .contacts {
                        onlyContacts = true
                    }
                    if let searchStateContext = self.searchStateContext, searchStateContext.subject == .search(query: self.navigationTextFieldState.text, onlyContacts: onlyContacts) {
                    } else {
                        self.searchStateDisposable?.dispose()
                        let searchStateContext = ShareWithPeersScreen.StateContext(context: component.context, subject: .search(query: self.navigationTextFieldState.text, onlyContacts: onlyContacts))
                        var applyState = false
                        self.searchStateDisposable = (searchStateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.searchStateContext = searchStateContext
                            if applyState {
                                self.state?.updated(transition: Transition(animation: .none).withUserData(AnimationHint(contentReloaded: true)))
                            }
                        })
                        applyState = true
                    }
                } else if let _ = self.searchStateContext {
                    self.searchStateContext = nil
                    self.searchStateDisposable?.dispose()
                    self.searchStateDisposable = nil
                    
                    contentTransition = contentTransition.withUserData(AnimationHint(contentReloaded: true))
                }
            }
                
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            
            let categoryItemSize = self.categoryTemplateItem.update(
                transition: .immediate,
                component: AnyComponent(CategoryListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    title: "Title",
                    color: .blue,
                    iconName: nil,
                    subtitle: nil,
                    selectionState: .editing(isSelected: false, isTinted: false),
                    hasNext: true,
                    action: {},
                    secondaryAction: {}
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            let peerItemSize = self.peerTemplateItem.update(
                transition: transition,
                component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    style: .generic,
                    sideInset: sideInset,
                    title: "Name",
                    peer: nil,
                    subtitle: self.searchStateContext != nil ? "" : "sub",
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .editing(isSelected: false, isTinted: false),
                    hasNext: true,
                    action: { _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            let optionItemSize = self.optionTemplateItem.update(
                transition: transition,
                component: AnyComponent(OptionListItemComponent(
                    theme: environment.theme,
                    title: "Title",
                    hasNext: true,
                    selected: false,
                    selectionChanged: { _ in }
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
            
            var sections: [ItemLayout.Section] = []
            if let stateValue = self.effectiveStateValue {
                if case .stories = component.stateContext.subject {
                    sections.append(ItemLayout.Section(
                        id: 0,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: categoryItemSize.height,
                        itemCount: component.categoryItems.count
                    ))
                    sections.append(ItemLayout.Section(
                        id: 2,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: optionItemSize.height,
                        itemCount: component.optionItems.count
                    ))
                } else {
                    sections.append(ItemLayout.Section(
                        id: 1,
                        insets: UIEdgeInsets(top: 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: peerItemSize.height,
                        itemCount: stateValue.peers.count
                    ))
                }
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            var navigationHeight: CGFloat = 56.0
            let navigationSideInset: CGFloat = 16.0
            var navigationButtonsWidth: CGFloat = 0.0
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self, let environment = self.environment, let controller = environment.controller() as? ShareWithPeersScreen else {
                            return
                        }
                        controller.requestDismiss()
                    }
                ).minSize(CGSize(width: navigationHeight, height: navigationHeight))),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: navigationHeight)
            )
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: containerSideInset + navigationSideInset, y: floor((navigationHeight - navigationLeftButtonSize.height) * 0.5)), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.navigationContainerView.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
            }
            navigationButtonsWidth += navigationLeftButtonSize.width + navigationSideInset
            
            var actionButtonTitle = environment.strings.Story_Privacy_SaveSettings
            let title: String
            switch component.stateContext.subject {
            case let .stories(editing):
                if editing {
                    title = environment.strings.Story_Privacy_EditStory
                } else {
                    title = environment.strings.Story_Privacy_ShareStory
                    actionButtonTitle = environment.strings.Story_Privacy_PostStory
                }
            case .chats:
                title = ""
            case let .contacts(category):
                switch category {
                case .closeFriends:
                    title = environment.strings.Story_Privacy_CategoryCloseFriends
                case .contacts:
                    title = environment.strings.Story_Privacy_ExcludePeople
                case .nobody:
                    title = environment.strings.Story_Privacy_CategorySelectedContacts
                case .everyone:
                    title = ""
                }
            case .search:
                title = ""
            }
            let navigationTitleSize = self.navigationTitle.update(
                transition: .immediate,
                component: AnyComponent(Text(text: title, font: Font.semibold(17.0), color: environment.theme.rootController.navigationBar.primaryTextColor)),
                environment: {},
                containerSize: CGSize(width: containerWidth - navigationButtonsWidth, height: navigationHeight)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: containerSideInset + floor((containerWidth - navigationTitleSize.width) * 0.5), y: floor((navigationHeight - navigationTitleSize.height) * 0.5)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    self.navigationContainerView.addSubview(navigationTitleView)
                }
                transition.setPosition(view: navigationTitleView, position: navigationTitleFrame.center)
                navigationTitleView.bounds = CGRect(origin: CGPoint(), size: navigationTitleFrame.size)
            }
            
            let navigationTextFieldFrame = CGRect(origin: CGPoint(x: containerSideInset, y: navigationHeight), size: navigationTextFieldSize)
            if let navigationTextFieldView = self.navigationTextField.view {
                if navigationTextFieldView.superview == nil {
                    self.navigationContainerView.addSubview(navigationTextFieldView)
                    self.navigationContainerView.layer.addSublayer(self.textFieldSeparatorLayer)
                }
                transition.setFrame(view: navigationTextFieldView, frame: navigationTextFieldFrame)
                transition.setFrame(layer: self.textFieldSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: navigationTextFieldFrame.maxY), size: CGSize(width: navigationTextFieldFrame.width, height: UIScreenPixel)))
            }
            navigationHeight += navigationTextFieldFrame.height
            
            if case .stories = component.stateContext.subject {
                navigationHeight += 16.0
            }
            
            let topInset: CGFloat
            if environment.inputHeight != 0.0 || !self.navigationTextFieldState.text.isEmpty {
                topInset = 0.0
            } else {
                let inset: CGFloat
                if case let .stories(editing) = component.stateContext.subject {
                    if editing {
                        inset = 446.0
                    } else {
                        inset = 605.0
                    }
                } else {
                    inset = 600.0
                }
                topInset = max(0.0, availableSize.height - containerInset - inset)
            }
            
            self.navigationBackgroundView.update(size: CGSize(width: containerWidth, height: navigationHeight), cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.navigationBackgroundView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: navigationHeight)))
            
            transition.setFrame(layer: self.navigationSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: navigationHeight), size: CGSize(width: containerWidth, height: UIScreenPixel)))
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: actionButtonTitle,
                        component: AnyComponent(ButtonTextContentComponent(
                            text: actionButtonTitle,
                            badge: 0,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component, let environment = self.environment, let controller = self.environment?.controller() as? ShareWithPeersScreen else {
                            return
                        }
                                                                        
                        let base: EngineStoryPrivacy.Base
                        if self.selectedCategories.contains(.everyone) {
                            base = .everyone
                        } else if self.selectedCategories.contains(.closeFriends) {
                            base = .closeFriends
                        } else if self.selectedCategories.contains(.contacts) {
                            base = .contacts
                        } else if self.selectedCategories.contains(.selectedContacts) {
                            base = .nobody
                        } else {
                            base = .nobody
                        }
                        
                        let proceed = {
                            component.completion(
                                EngineStoryPrivacy(
                                    base: base,
                                    additionallyIncludePeers: self.selectedPeers
                                ),
                                self.selectedOptions.contains(.screenshot),
                                self.selectedOptions.contains(.pin),
                                self.component?.stateContext.stateValue?.peers.filter { self.selectedPeers.contains($0.id) } ?? []
                            )

                            controller.dismissAllTooltips()
                            controller.dismiss()
                        }
                        
                        let presentAlert: ([String]) -> Void = { usernames in
                            let usernamesString = String(usernames.map { "@\($0)" }.joined(separator: ", "))
                            let alertController = textAlertController(
                                context: component.context,
                                forceTheme: defaultDarkColorPresentationTheme,
                                title: environment.strings.Story_Privacy_MentionRestrictedTitle,
                                text: environment.strings.Story_Privacy_MentionRestrictedText(usernamesString).string,
                                actions: [
                                    TextAlertAction(type: .defaultAction, title: environment.strings.Story_Privacy_MentionRestrictedProceed, action: {
                                        proceed()
                                    }),
                                    TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {})
                                ],
                                actionLayout: .vertical
                            )
                            controller.present(alertController, in: .window(.root))
                        }
                        
                        func matchingUsername(user: TelegramUser, usernames: Set<String>) -> String? {
                            for username in user.usernames {
                                if usernames.contains(username.username) {
                                    return username.username
                                }
                            }
                            if let username = user.username {
                                if usernames.contains(username) {
                                    return username
                                }
                            }
                            return nil
                        }
                        
                        let context = component.context
                        let selectedPeerIds = self.selectedPeers
                        
                        if case .stories = component.stateContext.subject {
                            if component.mentions.isEmpty {
                                proceed()
                            } else if case .nobody = base {
                                if selectedPeerIds.isEmpty {
                                    presentAlert(component.mentions)
                                } else {
                                    let _ = (context.account.postbox.transaction { transaction in
                                        var filteredMentions = Set(component.mentions)
                                        for peerId in selectedPeerIds {
                                            if let user = transaction.getPeer(peerId) as? TelegramUser, let username = matchingUsername(user: user, usernames: filteredMentions) {
                                                filteredMentions.remove(username)
                                            }
                                        }
                                        return Array(filteredMentions)
                                    }
                                    |> deliverOnMainQueue).start(next: { mentions in
                                        if mentions.isEmpty {
                                            proceed()
                                        } else {
                                            presentAlert(mentions)
                                        }
                                    })
                                }
                            } else if case .contacts = base {
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
                                |> map { contacts -> [String] in
                                    var filteredMentions = Set(component.mentions)
                                    let peers = contacts.peers
                                    for peer in peers {
                                        if selectedPeerIds.contains(peer.id) {
                                            continue
                                        }
                                        if case let .user(user) = peer, let username = matchingUsername(user: user, usernames: filteredMentions) {
                                            filteredMentions.remove(username)
                                        }
                                    }
                                    return Array(filteredMentions)
                                }
                                |> deliverOnMainQueue).start(next: { mentions in
                                    if mentions.isEmpty {
                                        proceed()
                                    } else {
                                        presentAlert(mentions)
                                    }
                                })
                            } else if case .closeFriends = base {
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
                                |> map { contacts -> [String] in
                                    var filteredMentions = Set(component.mentions)
                                    let peers = contacts.peers
                                    for peer in peers {
                                        if case let .user(user) = peer, user.flags.contains(.isCloseFriend), let username = matchingUsername(user: user, usernames: filteredMentions) {
                                            filteredMentions.remove(username)
                                        }
                                    }
                                    return Array(filteredMentions)
                                }
                                |> deliverOnMainQueue).start(next: { mentions in
                                    if mentions.isEmpty {
                                        proceed()
                                    } else {
                                        presentAlert(mentions)
                                    }
                                })
                            } else {
                                proceed()
                            }
                        } else {
                            proceed()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: containerWidth - navigationSideInset * 2.0, height: 50.0)
            )
            
            var bottomPanelHeight: CGFloat = 0.0
            if environment.inputHeight != 0.0 {
                bottomPanelHeight += environment.inputHeight + 8.0 + actionButtonSize.height
            } else {
                bottomPanelHeight += 10.0 + environment.safeInsets.bottom + actionButtonSize.height
            }
            let actionButtonFrame = CGRect(origin: CGPoint(x: containerSideInset + navigationSideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.containerView.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
                        
            transition.setFrame(view: self.bottomBackgroundView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: availableSize.height - bottomPanelHeight - 8.0), size: CGSize(width: containerWidth, height: bottomPanelHeight + 8.0)))
            self.bottomBackgroundView.update(size: self.bottomBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.bottomSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset + sideInset, y: availableSize.height - bottomPanelHeight - 8.0 - UIScreenPixel), size: CGSize(width: containerWidth, height: UIScreenPixel)))
                        
            let itemContainerSize = CGSize(width: itemsContainerWidth, height: availableSize.height)
            let itemLayout = ItemLayout(style: itemLayoutStyle, containerSize: itemContainerSize, containerInset: containerInset, bottomInset: bottomPanelHeight, topInset: topInset, sideInset: sideInset, navigationHeight: navigationHeight, sections: sections)
            let previousItemLayout = self.itemLayout
            self.itemLayout = itemLayout
            
            contentTransition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: itemLayout.contentHeight)))
            
            let scrollContentHeight = max(topInset + itemLayout.contentHeight + containerInset, availableSize.height - containerInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: containerWidth, height: itemLayout.contentHeight)))
            
            transition.setPosition(view: self.backgroundView, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset + 10.0), size: CGSize(width: availableSize.width, height: availableSize.height - 10.0))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            var dismissOffset: CGFloat = 0.0
            if let dismissPanState = self.dismissPanState {
                dismissOffset = max(0.0, dismissPanState.translation)
            }
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: dismissOffset), size: availableSize))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            let contentSize = CGSize(width: containerWidth, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            let indicatorInsets = UIEdgeInsets(top: max(itemLayout.containerInset, environment.safeInsets.top + navigationHeight), left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if indicatorInsets != self.scrollView.scrollIndicatorInsets {
                self.scrollView.scrollIndicatorInsets = indicatorInsets
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height))
            } else if let previousItemLayout, previousItemLayout.topInset != topInset {
                let topInsetDifference = previousItemLayout.topInset - topInset
                var scrollBounds = self.scrollView.bounds
                scrollBounds.origin.y += -topInsetDifference
                scrollBounds.origin.y = max(0.0, min(scrollBounds.origin.y, self.scrollView.contentSize.height - scrollBounds.height))
                let visibleDifference = self.scrollView.bounds.origin.y - scrollBounds.origin.y
                self.scrollView.bounds = scrollBounds
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: visibleDifference), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: contentTransition)
             
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ShareWithPeersScreen: ViewControllerComponentContainer {
    public final class State {
        let peers: [EnginePeer]
        let presences: [EnginePeer.Id: EnginePeer.Presence]
        let closeFriendsPeers: [EnginePeer]
        
        fileprivate init(
            peers: [EnginePeer],
            presences: [EnginePeer.Id: EnginePeer.Presence],
            closeFriendsPeers: [EnginePeer]
        ) {
            self.peers = peers
            self.presences = presences
            self.closeFriendsPeers = closeFriendsPeers
        }
    }
    
    public final class StateContext {
        public enum Subject: Equatable {
            case stories(editing: Bool)
            case chats
            case contacts(EngineStoryPrivacy.Base)
            case search(query: String, onlyContacts: Bool)
        }
        
        fileprivate var stateValue: State?
        
        public let subject: Subject
        public private(set) var initialPeerIds: Set<EnginePeer.Id> = Set()
        
        private var stateDisposable: Disposable?
        private let stateSubject = Promise<State>()
        public var state: Signal<State, NoError> {
            return self.stateSubject.get()
        }
        private let readySubject = ValuePromise<Bool>(false, ignoreRepeated: true)
        public var ready: Signal<Bool, NoError> {
            return self.readySubject.get()
        }
        
        public init(
            context: AccountContext,
            subject: Subject = .chats,
            initialPeerIds: Set<EnginePeer.Id> = Set(),
            closeFriends: Signal<[EnginePeer], NoError> = .single([])
        ) {
            self.subject = subject
            self.initialPeerIds = initialPeerIds
            
            switch subject {
            case .stories:
                var peerSignals: [Signal<EnginePeer?, NoError>] = []
                if initialPeerIds.count < 3 {
                    for peerId in initialPeerIds {
                        peerSignals.append(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                    }
                }
                                
                let peers = combineLatest(peerSignals)
                                
                self.stateDisposable = combineLatest(queue: Queue.mainQueue(), peers, closeFriends)
                .start(next: { [weak self] peers, closeFriends in
                    guard let self else {
                        return
                    }

                    let state = State(
                        peers: peers.compactMap { $0 },
                        presences: [:],
                        closeFriendsPeers: closeFriends
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case .chats:
                self.stateDisposable = (context.engine.messages.chatList(group: .root, count: 200)
                |> deliverOnMainQueue).start(next: { [weak self] chatList in
                    guard let self else {
                        return
                    }
                    
                    var selectedPeers: [EnginePeer] = []
                    for item in chatList.items.reversed() {
                        if self.initialPeerIds.contains(item.renderedPeer.peerId), let peer = item.renderedPeer.peer {
                            selectedPeers.append(peer)
                        }
                    }
                    
                    var presences: [EnginePeer.Id: EnginePeer.Presence] = [:]
                    for item in chatList.items {
                        presences[item.renderedPeer.peerId] = item.presence
                    }
                    
                    var peers: [EnginePeer] = []
                    peers = chatList.items.filter { !self.initialPeerIds.contains($0.renderedPeer.peerId) && $0.renderedPeer.peerId != context.account.peerId }.reversed().compactMap { $0.renderedPeer.peer }
                    peers.insert(contentsOf: selectedPeers, at: 0)
                    
                    let state = State(
                        peers: peers,
                        presences: presences,
                        closeFriendsPeers: []
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case let .contacts(base):
                self.stateDisposable = (context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Contacts.List(includePresences: true)
                )
                |> deliverOnMainQueue).start(next: { [weak self] contactList in
                    guard let self else {
                        return
                    }
                    
                    var selectedPeers: [EnginePeer] = []
                    if case .closeFriends = base {
                        for peer in contactList.peers {
                            if case let .user(user) = peer, user.flags.contains(.isCloseFriend) {
                                selectedPeers.append(peer)
                            }
                        }
                        self.initialPeerIds = Set(selectedPeers.map { $0.id })
                    } else {
                        for peer in contactList.peers {
                            if case let .user(user) = peer, initialPeerIds.contains(user.id), !user.isDeleted {
                                selectedPeers.append(peer)
                            }
                        }
                        self.initialPeerIds = initialPeerIds
                    }
                    selectedPeers = selectedPeers.sorted(by: { lhs, rhs in
                        let result = lhs.indexName.isLessThan(other: rhs.indexName, ordering: .firstLast)
                        if result == .orderedSame {
                            return lhs.id < rhs.id
                        } else {
                            return result == .orderedAscending
                        }
                    })
                    
                    var peers: [EnginePeer] = []
                    peers = contactList.peers.filter { !self.initialPeerIds.contains($0.id) && $0.id != context.account.peerId && !$0.isDeleted }.sorted(by: { lhs, rhs in
                        let result = lhs.indexName.isLessThan(other: rhs.indexName, ordering: .firstLast)
                        if result == .orderedSame {
                            return lhs.id < rhs.id
                        } else {
                            return result == .orderedAscending
                        }
                    })
                    peers.insert(contentsOf: selectedPeers, at: 0)
                    
                    let state = State(
                        peers: peers,
                        presences: contactList.presences,
                        closeFriendsPeers: []
                    )
                                        
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            case let .search(query, onlyContacts):
                let signal: Signal<[EngineRenderedPeer], NoError>
                if onlyContacts {
                    signal = combineLatest(
                        context.engine.contacts.searchLocalPeers(query: query),
                        context.engine.contacts.searchContacts(query: query)
                    )
                    |> map { peers, contacts in
                        let contactIds = Set(contacts.0.map { $0.id })
                        return peers.filter { contactIds.contains($0.peerId) }
                    }
                } else {
                    signal = context.engine.contacts.searchLocalPeers(query: query)
                }
                self.stateDisposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self] peers in
                    guard let self else {
                        return
                    }
                                        
                    let state = State(
                        peers: peers.compactMap { $0.peer }.filter { peer in
                            if case let .user(user) = peer {
                                if user.id == context.account.peerId {
                                    return false
                                } else if user.botInfo != nil {
                                    return false
                                } else {
                                    return true
                                }
                            } else {
                                return false
                            }
                        },
                        presences: [:],
                        closeFriendsPeers: []
                    )
                    self.stateValue = state
                    self.stateSubject.set(.single(state))
                    
                    self.readySubject.set(true)
                })
            }
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
    }
    
    private let context: AccountContext
    
    private var isDismissed: Bool = false
    
    public var dismissed: () -> Void = {}
    
    public init(
        context: AccountContext,
        initialPrivacy: EngineStoryPrivacy,
        allowScreenshots: Bool = true,
        pin: Bool = false,
        timeout: Int = 0,
        mentions: [String] = [],
        stateContext: StateContext,
        completion: @escaping (EngineStoryPrivacy, Bool, Bool, [EnginePeer]) -> Void,
        editCategory: @escaping (EngineStoryPrivacy, Bool, Bool) -> Void
    ) {
        self.context = context
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var categoryItems: [ShareWithPeersScreenComponent.CategoryItem] = []
        var optionItems: [ShareWithPeersScreenComponent.OptionItem] = []
        if case let .stories(editing) = stateContext.subject {
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .everyone,
                title: presentationData.strings.Story_Privacy_CategoryEveryone,
                icon: "Chat List/Filters/Channel",
                iconColor: .blue,
                actionTitle: nil
            ))
            
            var peerNames = ""
            if let peers = stateContext.stateValue?.peers, !peers.isEmpty {
                peerNames = String(peers.map { $0.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) }.joined(separator: ", "))
            }
            
            var contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeople
            if initialPrivacy.base == .contacts, initialPrivacy.additionallyIncludePeers.count > 0 {
                if initialPrivacy.additionallyIncludePeers.count == 1 {
                    if !peerNames.isEmpty {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                    } else {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(1)
                    }
                } else {
                    if !peerNames.isEmpty {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExceptNames(peerNames).string
                    } else {
                        contactsSubtitle = presentationData.strings.Story_Privacy_ExcludePeopleExcept(Int32(initialPrivacy.additionallyIncludePeers.count))
                    }
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .contacts,
                title: presentationData.strings.Story_Privacy_CategoryContacts,
                icon: "Chat List/Tabs/IconContacts",
                iconColor: .yellow,
                actionTitle: contactsSubtitle
            ))
            
            var closeFriendsSubtitle = presentationData.strings.Story_Privacy_EditList
            if let peers = stateContext.stateValue?.closeFriendsPeers, !peers.isEmpty {
                if peers.count > 2 {
                    closeFriendsSubtitle = presentationData.strings.Story_Privacy_People(Int32(peers.count))
                } else {
                    closeFriendsSubtitle = String(peers.map { $0.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) }.joined(separator: ", "))
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .closeFriends,
                title: presentationData.strings.Story_Privacy_CategoryCloseFriends,
                icon: "Call/StarHighlighted",
                iconColor: .green,
                actionTitle: closeFriendsSubtitle
            ))
            
            var selectedContactsSubtitle = presentationData.strings.Story_Privacy_Choose
            if initialPrivacy.base == .nobody, initialPrivacy.additionallyIncludePeers.count > 0 {
                if initialPrivacy.additionallyIncludePeers.count == 1 {
                    if !peerNames.isEmpty {
                        selectedContactsSubtitle = peerNames
                    } else {
                        selectedContactsSubtitle = presentationData.strings.Story_Privacy_People(1)
                    }
                } else {
                    if !peerNames.isEmpty {
                        selectedContactsSubtitle = peerNames
                    } else {
                        selectedContactsSubtitle = presentationData.strings.Story_Privacy_People(Int32(initialPrivacy.additionallyIncludePeers.count))
                    }
                }
            }
            categoryItems.append(ShareWithPeersScreenComponent.CategoryItem(
                id: .selectedContacts,
                title: presentationData.strings.Story_Privacy_CategorySelectedContacts,
                icon: "Chat List/Filters/Group",
                iconColor: .violet,
                actionTitle: selectedContactsSubtitle
            ))
            
            if !editing {
                optionItems.append(ShareWithPeersScreenComponent.OptionItem(
                    id: .screenshot,
                    title: presentationData.strings.Story_Privacy_AllowScreenshots
                ))
                
                optionItems.append(ShareWithPeersScreenComponent.OptionItem(
                    id: .pin,
                    title: presentationData.strings.Story_Privacy_KeepOnMyPage
                ))
            }
        }
        
        super.init(context: context, component: ShareWithPeersScreenComponent(
            context: context,
            stateContext: stateContext,
            initialPrivacy: initialPrivacy,
            screenshot: allowScreenshots,
            pin: pin,
            timeout: timeout,
            mentions: mentions,
            categoryItems: categoryItems,
            optionItems: optionItems,
            completion: completion,
            editCategory: editCategory
        ), navigationBarAppearance: .none, theme: .dark)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? ShareWithPeersScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController { controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
        }
        self.forEachController { controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        }
    }
    
    func requestDismiss() {
        self.dismissAllTooltips()
        self.dismissed()
        self.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.view.endEditing(true)
            
            if let componentView = self.node.hostView.componentView as? ShareWithPeersScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}
