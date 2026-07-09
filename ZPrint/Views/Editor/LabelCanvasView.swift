//
//  LabelCanvasView.swift
//  ZPrint
//

import AppKit
import SwiftUI

struct LabelCanvasView: View {
    @Binding var document: ZPrintDocument
    @Binding var selectedElementID: UUID?
    @Binding var selectedGuideID: UUID?
    @Binding var selectedVariableID: UUID?
    @Binding var activeFormatPanePage: FormatPanePage
    @State private var activeDrag: ElementDragState?
    @State private var activeResize: ElementResizeState?
    @State private var activeGuideDrag: GuideDragState?
    @State private var editingTextElementID: UUID?
    @State private var keyboardFocusToken = UUID()
    @State private var zoomGestureStart: Double?

    private let coordinateSpaceName = "labelCanvas"
    private let minimumElementWidthDots = 12
    private let minimumElementHeightDots = 12
    private let snapToleranceDots = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedElementID = nil
                        selectedGuideID = nil
                        selectedVariableID = nil
                        activeFormatPanePage = .document
                        editingTextElementID = nil
                        focusKeyboardShortcuts()
                    }

                ScrollView([.horizontal, .vertical]) {
                    canvasContent(containerSize: proxy.size)
                }
                .scrollContentBackground(.hidden)
            }
            .background {
                CanvasKeyEventHandler(
                    focusToken: keyboardFocusToken,
                    onDelete: deleteSelectedElement,
                    onDuplicate: duplicateSelectedElement
                )
                .frame(width: 0, height: 0)
            }
            .simultaneousGesture(trackpadZoomGesture)
            .onChange(of: selectedElementID) { _, newValue in
                if newValue != nil {
                    selectedGuideID = nil
                    selectedVariableID = nil
                    activeGuideDrag = nil
                }
            }
            .onDeleteCommand {
                deleteSelectedElement()
            }
        }
    }

    private func canvasContent(containerSize: CGSize) -> some View {
        let labelSize = scale.size(for: document.label)
        let variableRailWidth: CGFloat = document.variables.isEmpty ? 0 : 132
        let variableRailSpacing: CGFloat = document.variables.isEmpty ? 0 : 12

        return ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedElementID = nil
                    selectedGuideID = nil
                    selectedVariableID = nil
                    activeFormatPanePage = .document
                    editingTextElementID = nil
                    focusKeyboardShortcuts()
                }

            HStack(alignment: .center, spacing: variableRailSpacing) {
                if !document.variables.isEmpty {
                    CanvasVariableChipStrip(
                        variables: document.variables,
                        selectedVariableID: selectedVariableID,
                        select: selectVariable
                    )
                        .frame(width: variableRailWidth, alignment: .trailing)
                }

                labelSurface

                if !document.variables.isEmpty {
                    Color.clear
                        .frame(width: variableRailWidth)
                }
            }
        }
        .frame(
            width: max(
                containerSize.width,
                labelSize.width + (variableRailWidth * 2) + (variableRailSpacing * 2) + 128
            ),
            height: max(containerSize.height, labelSize.height + 128),
            alignment: .center
        )
    }

    private var labelSurface: some View {
        let labelSize = scale.size(for: document.label)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .frame(width: labelSize.width, height: labelSize.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedElementID = nil
                    selectedGuideID = nil
                    selectedVariableID = nil
                    activeFormatPanePage = .document
                    editingTextElementID = nil
                    focusKeyboardShortcuts()
                }

            ForEach(document.guides.filter(\.visible)) { guide in
                guideLayer(guide, labelSize: labelSize)
            }

            ForEach(document.elements) { element in
                elementLayer(element)
            }
        }
        .frame(width: labelSize.width, height: labelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            floatingTextFormatBar(labelSize: labelSize)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
        .coordinateSpace(name: coordinateSpaceName)
    }

    private var scale: DotViewScale {
        DotViewScale(zoomScale: document.viewSettings.zoomScale)
    }

    private func elementLayer(_ element: LabelElement) -> some View {
        let rect = scale.rect(for: element.frame)

        return ZStack {
            if editingTextElementID == element.id,
               let textElement = textElementBinding(for: element.id) {
                InlineTextElementEditor(
                    element: textElement,
                    scale: scale,
                    finishEditing: {
                        editingTextElementID = nil
                        focusKeyboardShortcuts()
                    }
                )
            } else {
                CanvasLabelElementView(
                    element: element,
                    scale: scale,
                    variables: document.variables,
                    isSelected: selectedElementID == element.id
                )
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if case .text = element {
                        selectedElementID = element.id
                        selectedGuideID = nil
                        selectedVariableID = nil
                        activeFormatPanePage = .document
                        editingTextElementID = element.id
                    }
                }
                .onTapGesture {
                    selectedElementID = element.id
                    selectedGuideID = nil
                    selectedVariableID = nil
                    activeFormatPanePage = .document
                    editingTextElementID = nil
                    focusKeyboardShortcuts()
                }
                .gesture(dragGesture(for: element))
            }

            if selectedElementID == element.id {
                ResizeHandlesOverlay(
                    resizeGesture: { handle in
                        resizeGesture(for: element, handle: handle)
                    }
                )
            }
        }
        .frame(width: max(1, rect.width), height: max(1, rect.height))
        .position(x: rect.midX, y: rect.midY)
        .zIndex(selectedElementID == element.id ? 12 : 10)
    }

    private func textElementBinding(for id: UUID) -> Binding<TextLabelElement>? {
        guard document.elements.contains(where: { element in
            guard element.id == id, case .text = element else {
                return false
            }
            return true
        }) else {
            return nil
        }

        return Binding(
            get: {
                guard let element = document.elements.first(where: { $0.id == id }),
                      case .text(let textElement) = element else {
                    return TextLabelElement.standardNewElement()
                }

                return textElement
            },
            set: { updatedElement in
                guard let index = document.elements.firstIndex(where: { $0.id == id }),
                      case .text = document.elements[index] else {
                    return
                }

                document.elements[index] = .text(updatedElement)
            }
        )
    }

    private func guideLayer(_ guide: GuideElement, labelSize: CGSize) -> some View {
        GuideLineView(
            guide: guide,
            scale: scale,
            labelSize: labelSize,
            isSelected: selectedGuideID == guide.id
        )
        .onTapGesture {
            selectedElementID = nil
            selectedGuideID = guide.id
            selectedVariableID = nil
            activeFormatPanePage = .document
            editingTextElementID = nil
            focusKeyboardShortcuts()
        }
        .gesture(guideDragGesture(for: guide))
        .zIndex(1)
    }

    @ViewBuilder
    private func floatingTextFormatBar(labelSize: CGSize) -> some View {
        if let selectedTextElement = selectedTextElementBinding() {
            let frame = selectedTextElement.wrappedValue.frame
            let position = floatingBarPosition(for: frame, labelSize: labelSize)

            ZStack(alignment: .topLeading) {
                FloatingTextFormatBar(
                    element: selectedTextElement,
                    onInteract: focusKeyboardShortcuts
                )
                .position(position)
                .zIndex(20)
            }
            .frame(width: labelSize.width, height: labelSize.height, alignment: .topLeading)
        }
    }

    private func selectedTextElementBinding() -> Binding<TextLabelElement>? {
        guard let selectedElementID,
              document.elements.contains(where: { element in
                  guard element.id == selectedElementID,
                        case .text = element else {
                      return false
                  }
                  return true
              }) else {
            return nil
        }

        return Binding(
            get: {
                guard let element = document.elements.first(where: { $0.id == selectedElementID }),
                      case .text(let textElement) = element else {
                    return TextLabelElement.standardNewElement()
                }

                return textElement
            },
            set: { updatedElement in
                guard let index = document.elements.firstIndex(where: { $0.id == selectedElementID }),
                      case .text = document.elements[index] else {
                    return
                }

                document.elements[index] = .text(updatedElement)
            }
        )
    }

    private func floatingBarPosition(for frame: LabelElementFrame, labelSize: CGSize) -> CGPoint {
        let elementRect = scale.rect(for: frame)
        let barSize = FloatingTextFormatBar.preferredSize
        let padding: CGFloat = 8
        let verticalGap: CGFloat = 10

        let minX = barSize.width / 2 + padding
        let maxX = labelSize.width - barSize.width / 2 - padding
        let x: CGFloat

        if maxX >= minX {
            x = min(max(elementRect.midX, minX), maxX)
        } else {
            x = labelSize.width / 2
        }

        let yAbove = elementRect.minY - barSize.height / 2 - verticalGap
        let yBelow = elementRect.maxY + barSize.height / 2 + verticalGap
        let minY = barSize.height / 2 + padding
        let maxY = labelSize.height - barSize.height / 2 - padding

        let preferredY: CGFloat
        if yAbove >= minY {
            preferredY = yAbove
        } else if yBelow <= maxY {
            preferredY = yBelow
        } else {
            preferredY = elementRect.midY
        }

        let y = maxY >= minY
            ? min(max(preferredY, minY), maxY)
            : labelSize.height / 2

        return CGPoint(x: x, y: y)
    }

    private func dragGesture(for element: LabelElement) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                if activeDrag?.id != element.id {
                    activeDrag = ElementDragState(
                        id: element.id,
                        originalFrame: currentFrame(for: element.id) ?? element.frame
                    )
                    selectedElementID = element.id
                    selectedGuideID = nil
                    selectedVariableID = nil
                    activeFormatPanePage = .document
                    editingTextElementID = nil
                    focusKeyboardShortcuts()
                }

                guard let activeDrag else {
                    return
                }

                let deltaX = scale.dots(fromPoints: value.translation.width)
                let deltaY = scale.dots(fromPoints: value.translation.height)
                var nextFrame = activeDrag.originalFrame
                nextFrame.xDots += deltaX
                nextFrame.yDots += deltaY
                let clampedFrame = nextFrame.clamped(to: document.label)

                updateElementFrame(
                    id: element.id,
                    frame: snappedFrameForMoving(clampedFrame, excluding: element.id)
                )
            }
            .onEnded { _ in
                activeDrag = nil
            }
    }

    private func resizeGesture(for element: LabelElement, handle: ResizeHandle) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                if activeResize?.id != element.id || activeResize?.handle != handle {
                    activeResize = ElementResizeState(
                        id: element.id,
                        handle: handle,
                        originalFrame: currentFrame(for: element.id) ?? element.frame
                    )
                    selectedElementID = element.id
                    selectedGuideID = nil
                    selectedVariableID = nil
                    activeFormatPanePage = .document
                    editingTextElementID = nil
                    focusKeyboardShortcuts()
                }

                guard let activeResize else {
                    return
                }

                let deltaX = scale.dots(fromPoints: value.translation.width)
                let deltaY = scale.dots(fromPoints: value.translation.height)
                let nextFrame = resizedFrame(
                    from: activeResize.originalFrame,
                    element: element,
                    handle: handle,
                    deltaX: deltaX,
                    deltaY: deltaY
                )

                updateElementFrame(
                    id: element.id,
                    frame: snappedFrameForResizing(
                        nextFrame,
                        handle: handle,
                        excluding: element.id,
                        minimumSize: minimumFrameSize(for: element)
                    )
                )
            }
            .onEnded { _ in
                activeResize = nil
            }
    }

    private func guideDragGesture(for guide: GuideElement) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                selectedElementID = nil
                selectedGuideID = guide.id
                selectedVariableID = nil
                activeFormatPanePage = .document
                editingTextElementID = nil
                focusKeyboardShortcuts()

                guard !guide.locked else {
                    return
                }

                if activeGuideDrag?.id != guide.id {
                    activeGuideDrag = GuideDragState(
                        id: guide.id,
                        originalPositionDots: currentGuidePosition(for: guide.id) ?? guide.positionDots
                    )
                }

                guard let activeGuideDrag else {
                    return
                }

                let delta = guide.orientation == .vertical
                    ? scale.dots(fromPoints: value.translation.width)
                    : scale.dots(fromPoints: value.translation.height)
                updateGuidePosition(
                    id: guide.id,
                    positionDots: activeGuideDrag.originalPositionDots + delta
                )
            }
            .onEnded { _ in
                activeGuideDrag = nil
            }
    }

    private func currentFrame(for id: UUID) -> LabelElementFrame? {
        document.elements.first { $0.id == id }?.frame
    }

    private func currentGuidePosition(for id: UUID) -> Int? {
        document.guides.first { $0.id == id }?.positionDots
    }

    private func updateElementFrame(id: UUID, frame: LabelElementFrame) {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else {
            return
        }

        document.elements[index] = document.elements[index].replacingFrame(frame)
    }

    private func updateGuidePosition(id: UUID, positionDots: Int) {
        guard let index = document.guides.firstIndex(where: { $0.id == id }) else {
            return
        }

        let guide = document.guides[index]
        let maxPosition = guide.orientation == .vertical
            ? document.label.widthDots
            : document.label.heightDots
        document.guides[index].positionDots = min(max(positionDots, 0), maxPosition)
    }

    private func resizedFrame(
        from originalFrame: LabelElementFrame,
        element: LabelElement,
        handle: ResizeHandle,
        deltaX: Int,
        deltaY: Int
    ) -> LabelElementFrame {
        let minimumSize = minimumFrameSize(for: element)
        let minWidth = minimumSize.widthDots
        let minHeight = minimumSize.heightDots
        var x = originalFrame.xDots
        var y = originalFrame.yDots
        var width = originalFrame.widthDots
        var height = originalFrame.heightDots

        if handle.affectsLeft {
            x += deltaX
            width -= deltaX
        }

        if handle.affectsRight {
            width += deltaX
        }

        if handle.affectsTop {
            y += deltaY
            height -= deltaY
        }

        if handle.affectsBottom {
            height += deltaY
        }

        if width < minWidth {
            if handle.affectsLeft {
                x = originalFrame.xDots + originalFrame.widthDots - minWidth
            }
            width = minWidth
        }

        if height < minHeight {
            if handle.affectsTop {
                y = originalFrame.yDots + originalFrame.heightDots - minHeight
            }
            height = minHeight
        }

        if x < 0 {
            width += x
            x = 0
        }

        if y < 0 {
            height += y
            y = 0
        }

        x = min(max(x, 0), max(0, document.label.widthDots - minWidth))
        y = min(max(y, 0), max(0, document.label.heightDots - minHeight))
        width = min(max(width, minWidth), document.label.widthDots - x)
        height = min(max(height, minHeight), document.label.heightDots - y)

        return LabelElementFrame(
            xDots: x,
            yDots: y,
            widthDots: width,
            heightDots: height
        )
    }

    private func minimumFrameSize(for element: LabelElement) -> (widthDots: Int, heightDots: Int) {
        guard case .text(let textElement) = element else {
            return (minimumElementWidthDots, minimumElementHeightDots)
        }

        let measuredSize = measuredTextSizeDots(for: textElement)
        return (
            max(minimumElementWidthDots, measuredSize.widthDots),
            max(minimumElementHeightDots, measuredSize.heightDots)
        )
    }

    private func measuredTextSizeDots(for element: TextLabelElement) -> (widthDots: Int, heightDots: Int) {
        let displayText = element.text.isEmpty ? " " : element.text
        let font = NSFont.systemFont(
            ofSize: CGFloat(max(7, element.fontSizeDots)),
            weight: element.isBold ? .semibold : .regular
        )
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (displayText as NSString).size(withAttributes: attributes)
        let horizontalPaddingDots = 8
        let verticalPaddingDots = 4

        return (
            Int(ceil(size.width)) + horizontalPaddingDots,
            Int(ceil(font.ascender - font.descender + font.leading)) + verticalPaddingDots
        )
    }

    private func snappedFrameForMoving(
        _ frame: LabelElementFrame,
        excluding elementID: UUID
    ) -> LabelElementFrame {
        var snappedFrame = frame

        if let offsetX = bestSnapOffset(
            anchors: [
                frame.xDots,
                frame.xDots + frame.widthDots / 2,
                frame.xDots + frame.widthDots
            ],
            targets: verticalSnapTargets(excluding: elementID)
        ) {
            snappedFrame.xDots += offsetX
        }

        if let offsetY = bestSnapOffset(
            anchors: [
                frame.yDots,
                frame.yDots + frame.heightDots / 2,
                frame.yDots + frame.heightDots
            ],
            targets: horizontalSnapTargets(excluding: elementID)
        ) {
            snappedFrame.yDots += offsetY
        }

        return constrainedElementFrame(snappedFrame)
    }

    private func snappedFrameForResizing(
        _ frame: LabelElementFrame,
        handle: ResizeHandle,
        excluding elementID: UUID,
        minimumSize: (widthDots: Int, heightDots: Int)
    ) -> LabelElementFrame {
        var snappedFrame = frame
        let verticalTargets = verticalSnapTargets(excluding: elementID)
        let horizontalTargets = horizontalSnapTargets(excluding: elementID)

        if handle.affectsLeft,
           let offset = bestSnapOffset(anchors: [frame.xDots], targets: verticalTargets) {
            snappedFrame.xDots += offset
            snappedFrame.widthDots -= offset
        }

        if handle.affectsRight,
           let offset = bestSnapOffset(anchors: [frame.xDots + frame.widthDots], targets: verticalTargets) {
            snappedFrame.widthDots += offset
        }

        if handle.affectsTop,
           let offset = bestSnapOffset(anchors: [frame.yDots], targets: horizontalTargets) {
            snappedFrame.yDots += offset
            snappedFrame.heightDots -= offset
        }

        if handle.affectsBottom,
           let offset = bestSnapOffset(anchors: [frame.yDots + frame.heightDots], targets: horizontalTargets) {
            snappedFrame.heightDots += offset
        }

        return constrainedElementFrame(
            snappedFrame,
            minimumSize: minimumSize
        )
    }

    private func verticalSnapTargets(excluding elementID: UUID) -> [Int] {
        let guideTargets = document.guides
            .filter { $0.visible && $0.orientation == .vertical }
            .map { min(max($0.positionDots, 0), document.label.widthDots) }

        return Array(Set(
            [0, document.label.widthDots / 2, document.label.widthDots]
                + guideTargets
                + elementVerticalSnapTargets(excluding: elementID)
        ))
        .sorted()
    }

    private func horizontalSnapTargets(excluding elementID: UUID) -> [Int] {
        let guideTargets = document.guides
            .filter { $0.visible && $0.orientation == .horizontal }
            .map { min(max($0.positionDots, 0), document.label.heightDots) }

        return Array(Set(
            [0, document.label.heightDots / 2, document.label.heightDots]
                + guideTargets
                + elementHorizontalSnapTargets(excluding: elementID)
        ))
        .sorted()
    }

    private func elementVerticalSnapTargets(excluding elementID: UUID) -> [Int] {
        document.elements
            .filter { $0.id != elementID }
            .flatMap { element in
                let frame = element.frame
                return [
                    frame.xDots,
                    frame.xDots + frame.widthDots / 2,
                    frame.xDots + frame.widthDots
                ]
            }
    }

    private func elementHorizontalSnapTargets(excluding elementID: UUID) -> [Int] {
        document.elements
            .filter { $0.id != elementID }
            .flatMap { element in
                let frame = element.frame
                return [
                    frame.yDots,
                    frame.yDots + frame.heightDots / 2,
                    frame.yDots + frame.heightDots
                ]
            }
    }

    private func bestSnapOffset(anchors: [Int], targets: [Int]) -> Int? {
        var bestOffset: Int?
        var bestDistance = snapToleranceDots + 1

        for anchor in anchors {
            for target in targets {
                let offset = target - anchor
                let distance = abs(offset)

                if distance <= snapToleranceDots && distance < bestDistance {
                    bestDistance = distance
                    bestOffset = offset
                }
            }
        }

        return bestOffset
    }

    private func constrainedElementFrame(
        _ frame: LabelElementFrame,
        minimumSize: (widthDots: Int, heightDots: Int)? = nil
    ) -> LabelElementFrame {
        let minWidth = minimumSize?.widthDots ?? minimumElementWidthDots
        let minHeight = minimumSize?.heightDots ?? minimumElementHeightDots
        var x = frame.xDots
        var y = frame.yDots
        var width = max(frame.widthDots, minWidth)
        var height = max(frame.heightDots, minHeight)

        if x < 0 {
            width += x
            x = 0
        }

        if y < 0 {
            height += y
            y = 0
        }

        x = min(max(x, 0), max(0, document.label.widthDots - minWidth))
        y = min(max(y, 0), max(0, document.label.heightDots - minHeight))
        width = min(max(width, minWidth), document.label.widthDots - x)
        height = min(max(height, minHeight), document.label.heightDots - y)

        return LabelElementFrame(
            xDots: x,
            yDots: y,
            widthDots: width,
            heightDots: height
        )
    }

    private func deleteSelectedElement() {
        guard let selectedElementID else {
            return
        }

        document.elements.removeAll { $0.id == selectedElementID }
        self.selectedElementID = nil
        activeDrag = nil
        activeResize = nil
        selectedGuideID = nil
        activeFormatPanePage = .document
    }

    private func selectVariable(_ variable: VariableDefinition) {
        selectedElementID = nil
        selectedGuideID = nil
        selectedVariableID = variable.id
        activeFormatPanePage = .variables
        editingTextElementID = nil
        focusKeyboardShortcuts()
    }

    private func duplicateSelectedElement() {
        guard let selectedElementID,
              let element = document.elements.first(where: { $0.id == selectedElementID }) else {
            return
        }

        let duplicatedElement = duplicate(element)
        document.elements.append(duplicatedElement)
        self.selectedElementID = duplicatedElement.id
        activeFormatPanePage = .document
        focusKeyboardShortcuts()
    }

    private func duplicate(_ element: LabelElement) -> LabelElement {
        let offsetDots = 16
        let nextFrame = LabelElementFrame(
            xDots: element.frame.xDots + offsetDots,
            yDots: element.frame.yDots + offsetDots,
            widthDots: element.frame.widthDots,
            heightDots: element.frame.heightDots
        )
        .clamped(to: document.label)

        switch element {
        case .text(var textElement):
            textElement.id = UUID()
            textElement.frame = nextFrame
            return .text(textElement)
        case .barcode(var barcodeElement):
            barcodeElement.id = UUID()
            barcodeElement.frame = nextFrame
            return .barcode(barcodeElement)
        case .shape(var shapeElement):
            shapeElement.id = UUID()
            shapeElement.frame = nextFrame
            return .shape(shapeElement)
        }
    }

    private func focusKeyboardShortcuts() {
        keyboardFocusToken = UUID()
    }

    private var trackpadZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                if zoomGestureStart == nil {
                    zoomGestureStart = document.viewSettings.zoomScale
                }

                let startZoom = zoomGestureStart ?? document.viewSettings.zoomScale
                document.viewSettings.zoomScale = min(max(startZoom * magnification, 0.25), 3.0)
            }
            .onEnded { _ in
                zoomGestureStart = nil
            }
    }
}

private struct ElementDragState {
    let id: UUID
    let originalFrame: LabelElementFrame
}

private struct ElementResizeState {
    let id: UUID
    let handle: ResizeHandle
    let originalFrame: LabelElementFrame
}

private struct GuideDragState {
    let id: UUID
    let originalPositionDots: Int
}

private enum ResizeHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var affectsLeft: Bool {
        self == .topLeft || self == .bottomLeft || self == .left
    }

    var affectsRight: Bool {
        self == .topRight || self == .bottomRight || self == .right
    }

    var affectsTop: Bool {
        self == .topLeft || self == .topRight || self == .top
    }

    var affectsBottom: Bool {
        self == .bottomLeft || self == .bottomRight || self == .bottom
    }

    var cursor: NSCursor {
        switch self {
        case .top, .bottom:
            return .resizeUpDown
        case .left, .right:
            return .resizeLeftRight
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return .crosshair
        }
    }
}

private struct ResizeHandlesOverlay<HandleGesture: Gesture>: View {
    let resizeGesture: (ResizeHandle) -> HandleGesture

    var body: some View {
        GeometryReader { proxy in
            ForEach(ResizeHandle.allCases, id: \.self) { handle in
                ResizeHandleView(handle: handle)
                    .position(position(for: handle, in: proxy.size))
                    .gesture(resizeGesture(handle))
            }
        }
        .allowsHitTesting(true)
    }

    private func position(for handle: ResizeHandle, in size: CGSize) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: 0, y: 0)
        case .top:
            return CGPoint(x: size.width / 2, y: 0)
        case .topRight:
            return CGPoint(x: size.width, y: 0)
        case .right:
            return CGPoint(x: size.width, y: size.height / 2)
        case .bottomRight:
            return CGPoint(x: size.width, y: size.height)
        case .bottom:
            return CGPoint(x: size.width / 2, y: size.height)
        case .bottomLeft:
            return CGPoint(x: 0, y: size.height)
        case .left:
            return CGPoint(x: 0, y: size.height / 2)
        }
    }
}

private struct ResizeHandleView: View {
    let handle: ResizeHandle

    var body: some View {
        Circle()
            .fill(Color(nsColor: .textBackgroundColor))
            .frame(width: 7, height: 7)
            .overlay {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.4)
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    handle.cursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .help("Größe ändern")
    }
}

private struct GuideLineView: View {
    let guide: GuideElement
    let scale: DotViewScale
    let labelSize: CGSize
    let isSelected: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            Rectangle()
                .fill(lineColor)
                .frame(width: lineSize.width, height: lineSize.height)
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .contentShape(Rectangle())
        .position(linePosition)
        .onHover { hovering in
            if hovering && !guide.locked {
                if guide.orientation == .vertical {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.resizeUpDown.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
        .accessibilityLabel(guide.name)
    }

    private var lineSize: CGSize {
        switch guide.orientation {
        case .vertical:
            return CGSize(width: isSelected ? 2 : 1, height: labelSize.height)
        case .horizontal:
            return CGSize(width: labelSize.width, height: isSelected ? 2 : 1)
        }
    }

    private var hitSize: CGSize {
        switch guide.orientation {
        case .vertical:
            return CGSize(width: 10, height: labelSize.height)
        case .horizontal:
            return CGSize(width: labelSize.width, height: 10)
        }
    }

    private var lineColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.78)
        }

        return Color.accentColor.opacity(guide.locked ? 0.30 : 0.42)
    }

    private var linePosition: CGPoint {
        switch guide.orientation {
        case .vertical:
            return CGPoint(
                x: scale.points(fromDots: guide.positionDots),
                y: labelSize.height / 2
            )
        case .horizontal:
            return CGPoint(
                x: labelSize.width / 2,
                y: scale.points(fromDots: guide.positionDots)
            )
        }
    }
}

private struct CanvasVariableChipStrip: View {
    let variables: [VariableDefinition]
    let selectedVariableID: UUID?
    let select: (VariableDefinition) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(variables) { variable in
                Button {
                    select(variable)
                } label: {
                    VariableChipView(
                        variable: variable,
                        isSelected: selectedVariableID == variable.id,
                        isCompact: true
                    )
                }
                .buttonStyle(.plain)
                .help("Variable bearbeiten: \(variable.placeholder)")
            }
        }
        .padding(.vertical, 8)
        .frame(maxHeight: 220, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Verfügbare Variablen")
    }
}

private struct FloatingTextFormatBar: View {
    static let preferredSize = CGSize(width: 314, height: 42)

    @Binding var element: TextLabelElement
    let onInteract: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            formatButton("B", isActive: element.isBold) {
                element.isBold.toggle()
            }
            .fontWeight(.semibold)

            formatButton("I", isActive: element.isItalic) {
                element.isItalic.toggle()
            }
            .italic()

            formatButton("U", isActive: element.isUnderlined) {
                element.isUnderlined.toggle()
            }
            .underline()

            separator

            HStack(spacing: 2) {
                Button {
                    onInteract()
                    fontSizeBinding.wrappedValue -= 1
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)

                Text("\(element.fontSizeDots)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 34)

                Button {
                    onInteract()
                    fontSizeBinding.wrappedValue += 1
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 3)
            .background {
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            }

            separator

            Picker("Ausrichtung", selection: $element.alignment) {
                Image(systemName: "text.alignleft")
                    .tag(TextElementAlignment.left)
                Image(systemName: "text.aligncenter")
                    .tag(TextElementAlignment.center)
                Image(systemName: "text.alignright")
                    .tag(TextElementAlignment.right)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 88)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(
            width: Self.preferredSize.width,
            height: Self.preferredSize.height
        )
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color(nsColor: .separatorColor).opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 7)
        .contentShape(Capsule())
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    onInteract()
                }
        )
        .help("Text formatieren")
    }

    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: {
                element.fontSizeDots
            },
            set: { newValue in
                element.fontSizeDots = max(6, min(newValue, 200))
            }
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.65))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 1)
    }

    private func formatButton(
        _ title: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            onInteract()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .background {
            Capsule()
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .overlay {
            Capsule()
                .stroke(isActive ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
        }
    }
}

private struct CanvasKeyEventHandler: NSViewRepresentable {
    let focusToken: UUID
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onDelete = onDelete
        view.onDuplicate = onDuplicate
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.onDelete = onDelete
        nsView.onDuplicate = onDuplicate

        guard context.coordinator.lastFocusToken != focusToken else {
            return
        }

        context.coordinator.lastFocusToken = focusToken
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastFocusToken: UUID?
    }

    final class KeyEventView: NSView {
        var onDelete: (() -> Void)?
        var onDuplicate: (() -> Void)?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "d" {
                onDuplicate?()
                return
            }

            if event.keyCode == 51 || event.keyCode == 117 {
                onDelete?()
                return
            }

            super.keyDown(with: event)
        }
    }
}

private struct CanvasLabelElementView: View {
    let element: LabelElement
    let scale: DotViewScale
    let variables: [VariableDefinition]
    let isSelected: Bool

    var body: some View {
        ZStack {
            switch element {
            case .text(let textElement):
                textElementView(textElement)
            case .barcode(let barcodeElement):
                barcodeElementView(barcodeElement)
            case .shape(let shapeElement):
                shapeElementView(shapeElement)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }

    private func textElementView(_ element: TextLabelElement) -> some View {
        InlineVariableTextView(
            text: element.text,
            variables: variables,
            font: textFont(for: element),
            isItalic: element.isItalic,
            isUnderlined: element.isUnderlined,
            alignment: element.alignment.viewAlignment
        )
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: element.alignment.viewAlignment)
        .background(Color.accentColor.opacity(isSelected ? 0.05 : 0.001))
    }

    private func textFont(for element: TextLabelElement) -> Font {
        .system(
            size: max(7, scale.points(fromDots: element.fontSizeDots)),
            weight: element.isBold ? .semibold : .regular
        )
    }

    private func barcodeElementView(_ element: BarcodeLabelElement) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(element.symbology.displayName.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            BarcodeBarsView(moduleWidth: max(1, scale.points(fromDots: element.moduleWidth)))

            if element.showsHumanReadableText {
                Text(element.value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func shapeElementView(_ element: ShapeLabelElement) -> some View {
        switch element.shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(element.isFilled ? Color.accentColor.opacity(0.18) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.primary.opacity(0.82), lineWidth: max(1, scale.points(fromDots: element.strokeWidthDots)))
                }
        case .ellipse:
            Ellipse()
                .fill(element.isFilled ? Color.accentColor.opacity(0.18) : Color.clear)
                .overlay {
                    Ellipse()
                        .stroke(Color.primary.opacity(0.82), lineWidth: max(1, scale.points(fromDots: element.strokeWidthDots)))
                }
        case .line:
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(Color.primary.opacity(0.82), lineWidth: max(1, scale.points(fromDots: element.strokeWidthDots)))
            }
        }
    }
}

private struct InlineVariableTextView: View {
    let text: String
    let variables: [VariableDefinition]
    let font: Font
    let isItalic: Bool
    let isUnderlined: Bool
    let alignment: Alignment

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let value):
                    if !value.isEmpty {
                        Text(value)
                            .font(font)
                            .foregroundStyle(.primary)
                            .italic(isItalic)
                            .underline(isUnderlined)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                case .variable(let name):
                    Text(chipTitle(for: name))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                        .help("Variable: \(name)")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .clipped()
    }

    private var segments: [InlineVariableTextSegment] {
        InlineVariableTextSegment.parse(text)
    }

    private func chipTitle(for name: String) -> String {
        variables.first { $0.name == name }?.name ?? name
    }
}

private enum InlineVariableTextSegment: Equatable {
    case text(String)
    case variable(String)

    static func parse(_ text: String) -> [InlineVariableTextSegment] {
        let pattern = #"\{\{\s*([A-Za-z0-9_]+)(?::[^}]+)?\s*\}\}"#

        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let matches = expression.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )

        guard !matches.isEmpty else {
            return [.text(text)]
        }

        var segments: [InlineVariableTextSegment] = []
        var currentLocation = 0

        for match in matches {
            if match.range.location > currentLocation {
                let plainRange = NSRange(
                    location: currentLocation,
                    length: match.range.location - currentLocation
                )
                segments.append(.text(nsText.substring(with: plainRange)))
            }

            if match.numberOfRanges >= 2,
               match.range(at: 1).location != NSNotFound {
                segments.append(.variable(nsText.substring(with: match.range(at: 1))))
            }

            currentLocation = match.range.location + match.range.length
        }

        if currentLocation < nsText.length {
            segments.append(.text(nsText.substring(from: currentLocation)))
        }

        return segments
    }
}

private struct InlineTextElementEditor: View {
    @Binding var element: TextLabelElement
    let scale: DotViewScale
    let finishEditing: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $element.text)
            .textFieldStyle(.plain)
            .font(textFont)
            .foregroundStyle(.primary)
            .italic(element.isItalic)
            .underline(element.isUnderlined)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: element.alignment.viewAlignment)
            .background(Color.accentColor.opacity(0.08))
            .focused($isFocused)
            .onSubmit(finishEditing)
            .onAppear {
                isFocused = true
            }
    }

    private var textFont: Font {
        .system(
            size: max(7, scale.points(fromDots: element.fontSizeDots)),
            weight: element.isBold ? .semibold : .regular
        )
    }
}

private extension TextElementAlignment {
    var viewAlignment: Alignment {
        switch self {
        case .left:
            return .leading
        case .center:
            return .center
        case .right:
            return .trailing
        }
    }
}

private struct BarcodeBarsView: View {
    let moduleWidth: CGFloat

    private let barHeights: [CGFloat] = [
        0.82, 0.44, 0.70, 0.92, 0.56, 0.76, 0.38, 0.88,
        0.64, 0.48, 0.96, 0.72, 0.42, 0.80, 0.58, 0.90,
        0.52, 0.68, 0.84, 0.46, 0.78, 0.60, 0.94, 0.50
    ]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: max(1, moduleWidth)) {
                ForEach(barHeights.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Color.primary.opacity(0.84))
                        .frame(
                            width: barWidth(at: index),
                            height: proxy.size.height * barHeights[index]
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func barWidth(at index: Int) -> CGFloat {
        index.isMultiple(of: 5) ? moduleWidth * 1.8 : moduleWidth
    }
}
