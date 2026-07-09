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
    @State private var undoStack: [DocumentEditSnapshot] = []
    @State private var redoStack: [DocumentEditSnapshot] = []

    private let coordinateSpaceName = "labelCanvas"
    private let minimumElementWidthDots = 12
    private let minimumElementHeightDots = 12
    private let snapToleranceDots = 6
    private let maximumUndoSnapshots = 80
    private let elementPasteboardType = NSPasteboard.PasteboardType("com.zprint.label-element")
    private let guidePasteboardType = NSPasteboard.PasteboardType("com.zprint.guide-element")

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ZPrintDesign.ColorToken.workspaceBackground
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
                    onDuplicate: duplicateSelectedElement,
                    onCopy: copySelectedElement,
                    onCut: cutSelectedElement,
                    onPaste: pasteElement,
                    onUndo: undoLastEdit,
                    onRedo: redoLastEdit,
                    onMoveSelection: moveSelectedCanvasObject
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
        let variableRailWidth: CGFloat = document.variables.isEmpty ? 0 : 128
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
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ZPrintDesign.ColorToken.softBorder, lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            floatingTextFormatBar(labelSize: labelSize)
        }
        .shadow(color: .black.opacity(0.10), radius: 22, x: 0, y: 10)
        .shadow(color: .black.opacity(0.045), radius: 3, x: 0, y: 1)
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
        .rotationEffect(.degrees(Double(element.rotation.degrees)))
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
                    pushUndoSnapshot()
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

                updateElementFrame(
                    id: element.id,
                    frame: snappedFrameForMoving(
                        nextFrame,
                        element: element,
                        excluding: element.id
                    )
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
                    pushUndoSnapshot()
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

                let rawDeltaX = scale.dots(fromPoints: value.translation.width)
                let rawDeltaY = scale.dots(fromPoints: value.translation.height)
                let localDelta = localResizeDelta(
                    xDots: rawDeltaX,
                    yDots: rawDeltaY,
                    rotation: element.rotation
                )
                let nextFrame = resizedFrame(
                    from: activeResize.originalFrame,
                    element: element,
                    handle: handle,
                    deltaX: localDelta.xDots,
                    deltaY: localDelta.yDots
                )

                updateElementFrame(
                    id: element.id,
                    frame: snappedFrameForResizing(
                        nextFrame,
                        originalFrame: activeResize.originalFrame,
                        handle: handle,
                        element: element,
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

        document.guides[index].positionDots = positionDots
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
        let originalCenter = CGPoint(
            x: CGFloat(originalFrame.xDots) + CGFloat(originalFrame.widthDots) / 2,
            y: CGFloat(originalFrame.yDots) + CGFloat(originalFrame.heightDots) / 2
        )

        if handle.affectsLeft {
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
            width = minWidth
        }

        if height < minHeight {
            height = minHeight
        }

        let fixedAnchor = handle.fixedAnchor
        let centerShift = rotatedVector(
            x: fixedAnchor.x * (CGFloat(originalFrame.widthDots) - CGFloat(width)) / 2,
            y: fixedAnchor.y * (CGFloat(originalFrame.heightDots) - CGFloat(height)) / 2,
            rotation: element.rotation
        )
        let nextCenter = CGPoint(
            x: originalCenter.x + centerShift.x,
            y: originalCenter.y + centerShift.y
        )

        x = Int(round(nextCenter.x - CGFloat(width) / 2))
        y = Int(round(nextCenter.y - CGFloat(height) / 2))

        return constrainedElementFrame(
            LabelElementFrame(
                xDots: x,
                yDots: y,
                widthDots: width,
                heightDots: height
            ),
            minimumSize: minimumSize
        )
    }

    private func localResizeDelta(
        xDots: Int,
        yDots: Int,
        rotation: LabelElementRotation
    ) -> (xDots: Int, yDots: Int) {
        guard rotation.degrees != 0 else {
            return (xDots, yDots)
        }

        let radians = Double(rotation.degrees) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)
        let x = Double(xDots)
        let y = Double(yDots)

        return (
            Int(round(cosine * x + sine * y)),
            Int(round(-sine * x + cosine * y))
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
        let font = TextLabelFontCatalog.nsFont(
            familyName: element.fontFamilyName,
            size: CGFloat(max(7, element.fontSizeDots)),
            isBold: element.isBold,
            isItalic: element.isItalic
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
        element: LabelElement,
        excluding elementID: UUID
    ) -> LabelElementFrame {
        var snappedFrame = frame
        let anchors = snapAnchors(for: element, frame: frame)

        if let offsetX = bestSnapOffset(
            anchors: anchors.vertical,
            targets: verticalSnapTargets(excluding: elementID)
        ) {
            snappedFrame.xDots += offsetX
        }

        if let offsetY = bestSnapOffset(
            anchors: anchors.horizontal,
            targets: horizontalSnapTargets(excluding: elementID)
        ) {
            snappedFrame.yDots += offsetY
        }

        return snappedFrame
    }

    private func snappedFrameForResizing(
        _ frame: LabelElementFrame,
        originalFrame: LabelElementFrame,
        handle: ResizeHandle,
        element: LabelElement,
        excluding elementID: UUID,
        minimumSize: (widthDots: Int, heightDots: Int)
    ) -> LabelElementFrame {
        if element.rotation.degrees != 0 {
            return snappedRotatedFrameForResizing(
                frame,
                originalFrame: originalFrame,
                handle: handle,
                element: element,
                excluding: elementID,
                minimumSize: minimumSize
            )
        }

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
                snapAnchors(for: element, frame: element.frame).vertical
            }
    }

    private func elementHorizontalSnapTargets(excluding elementID: UUID) -> [Int] {
        document.elements
            .filter { $0.id != elementID }
            .flatMap { element in
                snapAnchors(for: element, frame: element.frame).horizontal
            }
    }

    private func snapAnchors(
        for element: LabelElement,
        frame: LabelElementFrame
    ) -> (vertical: [Int], horizontal: [Int]) {
        guard element.rotation.degrees != 0 else {
            return (
                [
                    frame.xDots,
                    frame.xDots + frame.widthDots / 2,
                    frame.xDots + frame.widthDots
                ],
                [
                    frame.yDots,
                    frame.yDots + frame.heightDots / 2,
                    frame.yDots + frame.heightDots
                ]
            )
        }

        let corners = rotatedCorners(for: frame, rotation: element.rotation)
        return (
            Array(Set(corners.map { Int(round($0.x)) })).sorted(),
            Array(Set(corners.map { Int(round($0.y)) })).sorted()
        )
    }

    private func snappedRotatedFrameForResizing(
        _ frame: LabelElementFrame,
        originalFrame: LabelElementFrame,
        handle: ResizeHandle,
        element: LabelElement,
        excluding elementID: UUID,
        minimumSize: (widthDots: Int, heightDots: Int)
    ) -> LabelElementFrame {
        guard handle.isCorner else {
            return constrainedElementFrame(
                frame,
                minimumSize: minimumSize
            )
        }

        let draggedCorner = rotatedHandlePoint(
            frame: frame,
            handle: handle,
            rotation: element.rotation
        )
        var snappedCorner = draggedCorner
        var didSnap = false

        if let offsetX = bestSnapOffset(
            anchors: [Int(round(draggedCorner.x))],
            targets: verticalSnapTargets(excluding: elementID)
        ) {
            snappedCorner.x += CGFloat(offsetX)
            didSnap = true
        }

        if let offsetY = bestSnapOffset(
            anchors: [Int(round(draggedCorner.y))],
            targets: horizontalSnapTargets(excluding: elementID)
        ) {
            snappedCorner.y += CGFloat(offsetY)
            didSnap = true
        }

        guard didSnap else {
            return constrainedElementFrame(
                frame,
                minimumSize: minimumSize
            )
        }

        let fixedCorner = rotatedHandlePoint(
            frame: originalFrame,
            handle: handle.opposite,
            rotation: element.rotation
        )
        let span = CGPoint(
            x: snappedCorner.x - fixedCorner.x,
            y: snappedCorner.y - fixedCorner.y
        )
        let localSpan = localVector(
            x: span.x,
            y: span.y,
            rotation: element.rotation
        )
        let width = max(minimumSize.widthDots, Int(round(abs(localSpan.x))))
        let height = max(minimumSize.heightDots, Int(round(abs(localSpan.y))))
        let center = CGPoint(
            x: (fixedCorner.x + snappedCorner.x) / 2,
            y: (fixedCorner.y + snappedCorner.y) / 2
        )

        return constrainedElementFrame(
            LabelElementFrame(
                xDots: Int(round(center.x - CGFloat(width) / 2)),
                yDots: Int(round(center.y - CGFloat(height) / 2)),
                widthDots: width,
                heightDots: height
            ),
            minimumSize: minimumSize
        )
    }

    private func rotatedCorners(
        for frame: LabelElementFrame,
        rotation: LabelElementRotation
    ) -> [CGPoint] {
        [
            rotatedHandlePoint(frame: frame, handle: .topLeft, rotation: rotation),
            rotatedHandlePoint(frame: frame, handle: .topRight, rotation: rotation),
            rotatedHandlePoint(frame: frame, handle: .bottomRight, rotation: rotation),
            rotatedHandlePoint(frame: frame, handle: .bottomLeft, rotation: rotation)
        ]
    }

    private func rotatedHandlePoint(
        frame: LabelElementFrame,
        handle: ResizeHandle,
        rotation: LabelElementRotation
    ) -> CGPoint {
        let center = CGPoint(
            x: CGFloat(frame.xDots) + CGFloat(frame.widthDots) / 2,
            y: CGFloat(frame.yDots) + CGFloat(frame.heightDots) / 2
        )
        let anchor = handle.localAnchor
        let offset = rotatedVector(
            x: anchor.x * CGFloat(frame.widthDots) / 2,
            y: anchor.y * CGFloat(frame.heightDots) / 2,
            rotation: rotation
        )

        return CGPoint(
            x: center.x + offset.x,
            y: center.y + offset.y
        )
    }

    private func rotatedVector(
        x: CGFloat,
        y: CGFloat,
        rotation: LabelElementRotation
    ) -> CGPoint {
        let radians = CGFloat(rotation.degrees) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)

        return CGPoint(
            x: cosine * x - sine * y,
            y: sine * x + cosine * y
        )
    }

    private func localVector(
        x: CGFloat,
        y: CGFloat,
        rotation: LabelElementRotation
    ) -> CGPoint {
        let radians = CGFloat(rotation.degrees) * .pi / 180
        let cosine = cos(radians)
        let sine = sin(radians)

        return CGPoint(
            x: cosine * x + sine * y,
            y: -sine * x + cosine * y
        )
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
        guard selectedElementID != nil || selectedGuideID != nil else {
            return
        }

        pushUndoSnapshot()
        deleteSelectedElement(recordUndo: false)
    }

    private func deleteSelectedElement(recordUndo: Bool) {
        guard selectedElementID != nil || selectedGuideID != nil else {
            return
        }

        if recordUndo {
            pushUndoSnapshot()
        }

        if let selectedElementID {
            document.elements.removeAll { $0.id == selectedElementID }
            self.selectedElementID = nil
        }

        if let selectedGuideID {
            document.guides.removeAll { $0.id == selectedGuideID }
            self.selectedGuideID = nil
        }

        activeDrag = nil
        activeResize = nil
        activeFormatPanePage = .document
    }

    private func moveSelectedCanvasObject(deltaX: Int, deltaY: Int) {
        guard selectedElementID != nil || selectedGuideID != nil else {
            NSSound.beep()
            return
        }

        editingTextElementID = nil

        if let selectedElementID,
           let element = document.elements.first(where: { $0.id == selectedElementID }) {
            pushUndoSnapshot()
            var nextFrame = element.frame
            nextFrame.xDots += deltaX
            nextFrame.yDots += deltaY
            updateElementFrame(
                id: selectedElementID,
                frame: snappedFrameForMoving(
                    nextFrame,
                    element: element,
                    excluding: selectedElementID
                )
            )
            focusKeyboardShortcuts()
            return
        }

        if let selectedGuideID,
           let guide = document.guides.first(where: { $0.id == selectedGuideID }) {
            guard !guide.locked else {
                NSSound.beep()
                return
            }

            pushUndoSnapshot()
            let delta = guide.orientation == .vertical ? deltaX : deltaY
            updateGuidePosition(id: selectedGuideID, positionDots: guide.positionDots + delta)
            focusKeyboardShortcuts()
        }
    }

    private func selectVariable(_ variable: VariableDefinition) {
        selectedElementID = nil
        selectedGuideID = nil
        selectedVariableID = variable.id
        activeFormatPanePage = .variables
        editingTextElementID = nil
        focusKeyboardShortcuts()
    }

    private func copySelectedElement() {
        guard let selectedObject = selectedCanvasObject else {
            NSSound.beep()
            return
        }

        do {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            switch selectedObject {
            case .element(let element):
                let data = try JSONEncoder.zprint.encode(element)
                pasteboard.setData(data, forType: elementPasteboardType)
            case .guide(let guide):
                let data = try JSONEncoder.zprint.encode(guide)
                pasteboard.setData(data, forType: guidePasteboardType)
            }
        } catch {
            NSSound.beep()
        }
    }

    private func cutSelectedElement() {
        guard selectedCanvasObject != nil else {
            NSSound.beep()
            return
        }

        pushUndoSnapshot()
        copySelectedElement()
        deleteSelectedElement(recordUndo: false)
    }

    private func pasteElement() {
        let pasteboard = NSPasteboard.general

        if let data = pasteboard.data(forType: elementPasteboardType),
           let element = try? JSONDecoder.zprint.decode(LabelElement.self, from: data) {
            pushUndoSnapshot()
            let pastedElement = duplicate(element)
            document.elements.append(pastedElement)
            selectedElementID = pastedElement.id
            selectedGuideID = nil
            selectedVariableID = nil
            activeFormatPanePage = .document
            editingTextElementID = nil
            focusKeyboardShortcuts()
            return
        }

        if let data = pasteboard.data(forType: guidePasteboardType),
           let guide = try? JSONDecoder.zprint.decode(GuideElement.self, from: data) {
            pushUndoSnapshot()
            let pastedGuide = duplicate(guide)
            document.guides.append(pastedGuide)
            selectedElementID = nil
            selectedGuideID = pastedGuide.id
            selectedVariableID = nil
            activeFormatPanePage = .document
            editingTextElementID = nil
            focusKeyboardShortcuts()
            return
        }

        NSSound.beep()
    }

    private func duplicateSelectedElement() {
        guard let selectedObject = selectedCanvasObject else {
            return
        }

        pushUndoSnapshot()
        switch selectedObject {
        case .element(let element):
            let duplicatedElement = duplicate(element)
            document.elements.append(duplicatedElement)
            selectedElementID = duplicatedElement.id
            selectedGuideID = nil
        case .guide(let guide):
            let duplicatedGuide = duplicate(guide)
            document.guides.append(duplicatedGuide)
            selectedElementID = nil
            selectedGuideID = duplicatedGuide.id
        }
        selectedVariableID = nil
        activeFormatPanePage = .document
        editingTextElementID = nil
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

    private func duplicate(_ guide: GuideElement) -> GuideElement {
        var duplicatedGuide = guide
        let offsetDots = 16
        let maxPosition = guide.orientation == .vertical
            ? document.label.widthDots
            : document.label.heightDots

        duplicatedGuide.id = UUID()
        duplicatedGuide.positionDots = min(max(guide.positionDots + offsetDots, 0), maxPosition)
        duplicatedGuide.name = guide.name
        return duplicatedGuide
    }

    private var selectedCanvasObject: CanvasClipboardObject? {
        if let selectedElement {
            return .element(selectedElement)
        }

        if let selectedGuide {
            return .guide(selectedGuide)
        }

        return nil
    }

    private var selectedElement: LabelElement? {
        guard let selectedElementID else {
            return nil
        }

        return document.elements.first { $0.id == selectedElementID }
    }

    private var selectedGuide: GuideElement? {
        guard let selectedGuideID else {
            return nil
        }

        return document.guides.first { $0.id == selectedGuideID }
    }

    private func pushUndoSnapshot() {
        undoStack.append(currentEditSnapshot)

        if undoStack.count > maximumUndoSnapshots {
            undoStack.removeFirst(undoStack.count - maximumUndoSnapshots)
        }

        redoStack.removeAll()
    }

    private var currentEditSnapshot: DocumentEditSnapshot {
        DocumentEditSnapshot(
            document: document,
            selectedElementID: selectedElementID,
            selectedGuideID: selectedGuideID,
            selectedVariableID: selectedVariableID
        )
    }

    private func undoLastEdit() {
        guard let snapshot = undoStack.popLast() else {
            NSSound.beep()
            return
        }

        redoStack.append(currentEditSnapshot)
        restore(snapshot)
    }

    private func redoLastEdit() {
        guard let snapshot = redoStack.popLast() else {
            NSSound.beep()
            return
        }

        undoStack.append(currentEditSnapshot)
        restore(snapshot)
    }

    private func restore(_ snapshot: DocumentEditSnapshot) {
        document = snapshot.document
        selectedElementID = snapshot.selectedElementID
        selectedGuideID = snapshot.selectedGuideID
        selectedVariableID = snapshot.selectedVariableID
        activeDrag = nil
        activeResize = nil
        activeGuideDrag = nil
        editingTextElementID = nil
        activeFormatPanePage = selectedVariableID == nil ? .document : .variables
        focusKeyboardShortcuts()
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

private struct DocumentEditSnapshot {
    let document: ZPrintDocument
    let selectedElementID: UUID?
    let selectedGuideID: UUID?
    let selectedVariableID: UUID?
}

private enum CanvasClipboardObject {
    case element(LabelElement)
    case guide(GuideElement)
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

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return true
        case .top, .right, .bottom, .left:
            return false
        }
    }

    var localAnchor: (x: CGFloat, y: CGFloat) {
        switch self {
        case .topLeft:
            return (-1, -1)
        case .top:
            return (0, -1)
        case .topRight:
            return (1, -1)
        case .right:
            return (1, 0)
        case .bottomRight:
            return (1, 1)
        case .bottom:
            return (0, 1)
        case .bottomLeft:
            return (-1, 1)
        case .left:
            return (-1, 0)
        }
    }

    var fixedAnchor: (x: CGFloat, y: CGFloat) {
        let anchor = localAnchor
        return (
            affectsLeft || affectsRight ? -anchor.x : 0,
            affectsTop || affectsBottom ? -anchor.y : 0
        )
    }

    var opposite: ResizeHandle {
        switch self {
        case .topLeft:
            return .bottomRight
        case .top:
            return .bottom
        case .topRight:
            return .bottomLeft
        case .right:
            return .left
        case .bottomRight:
            return .topLeft
        case .bottom:
            return .top
        case .bottomLeft:
            return .topRight
        case .left:
            return .right
        }
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
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.4)
            }
            .shadow(color: .black.opacity(0.14), radius: 1, x: 0, y: 0.5)
            .frame(width: 28, height: 28)
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
    static let preferredSize = CGSize(width: 448, height: 42)

    @Binding var element: TextLabelElement
    let onInteract: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Menu {
                ForEach(TextLabelFontCatalog.fontFamilyNames, id: \.self) { familyName in
                    Button(TextLabelFontCatalog.displayName(for: familyName)) {
                        onInteract()
                        element.fontFamilyName = familyName
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(TextLabelFontCatalog.displayName(for: element.fontFamilyName))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .medium))
                .frame(width: 112, height: 24)
            }
            .menuStyle(.borderlessButton)

            separator

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

            ZPrintNumberStepperField(
                title: "Schriftgröße",
                value: fontSizeBinding,
                width: 104
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        onInteract()
                    }
            )

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
    let onCopy: () -> Void
    let onCut: () -> Void
    let onPaste: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onMoveSelection: (_ deltaX: Int, _ deltaY: Int) -> Void

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onDelete = onDelete
        view.onDuplicate = onDuplicate
        view.onCopy = onCopy
        view.onCut = onCut
        view.onPaste = onPaste
        view.onUndo = onUndo
        view.onRedo = onRedo
        view.onMoveSelection = onMoveSelection
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.onDelete = onDelete
        nsView.onDuplicate = onDuplicate
        nsView.onCopy = onCopy
        nsView.onCut = onCut
        nsView.onPaste = onPaste
        nsView.onUndo = onUndo
        nsView.onRedo = onRedo
        nsView.onMoveSelection = onMoveSelection

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
        var onCopy: (() -> Void)?
        var onCut: (() -> Void)?
        var onPaste: (() -> Void)?
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?
        var onMoveSelection: ((_ deltaX: Int, _ deltaY: Int) -> Void)?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.contains(.command),
               let character = event.charactersIgnoringModifiers?.lowercased() {
                switch character {
                case "c":
                    onCopy?()
                    return
                case "x":
                    onCut?()
                    return
                case "v":
                    onPaste?()
                    return
                case "z":
                    if event.modifierFlags.contains(.shift) {
                        onRedo?()
                    } else {
                        onUndo?()
                    }
                    return
                case "y":
                    onRedo?()
                    return
                case "d":
                    onDuplicate?()
                    return
                default:
                    break
                }
            }

            if event.keyCode == 51 || event.keyCode == 117 {
                onDelete?()
                return
            }

            let movementStep = event.modifierFlags.contains(.shift) ? 10 : 1
            switch event.keyCode {
            case 123:
                onMoveSelection?(-movementStep, 0)
                return
            case 124:
                onMoveSelection?(movementStep, 0)
                return
            case 125:
                onMoveSelection?(0, movementStep)
                return
            case 126:
                onMoveSelection?(0, -movementStep)
                return
            default:
                break
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
        TextLabelFontCatalog.swiftUIFont(
            familyName: element.fontFamilyName,
            size: max(7, scale.points(fromDots: element.fontSizeDots)),
            isBold: element.isBold
        )
    }

    private func barcodeElementView(_ element: BarcodeLabelElement) -> some View {
        VStack(spacing: 0) {
            BarcodeBarsView(value: element.value)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if element.showsHumanReadableText {
                Text(element.value)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private func shapeElementView(_ element: ShapeLabelElement) -> some View {
        let fillColor = element.isFilled ? Color(labelElementColor: element.fillColor) : Color.clear
        let strokeColor = Color(labelElementColor: element.strokeColor)
        let strokeWidth = max(1, scale.points(fromDots: element.strokeWidthDots))

        switch element.shape {
        case .rectangle:
            Rectangle()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Rectangle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .ellipse:
            Ellipse()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Ellipse()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .capsule:
            Capsule()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        Capsule()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .triangle:
            CanvasTriangleShape()
                .fill(fillColor)
                .overlay {
                    if element.hasStroke {
                        CanvasTriangleShape()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    }
                }
        case .line:
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(strokeColor, lineWidth: strokeWidth)
            }
        }
    }
}

private struct CanvasTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private extension Color {
    init(labelElementColor color: LabelElementColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
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
        TextLabelFontCatalog.swiftUIFont(
            familyName: element.fontFamilyName,
            size: max(7, scale.points(fromDots: element.fontSizeDots)),
            isBold: element.isBold
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
    let value: String

    var body: some View {
        let segments = Code128Barcode.segments(for: value)

        return GeometryReader { proxy in
            if segments.isEmpty {
                Text("Kein Wert")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let totalModules = segments.reduce(0) { $0 + $1.widthModules }
                let fittedModuleWidth = proxy.size.width / CGFloat(max(totalModules, 1))

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.isBar ? Color.primary : Color.clear)
                            .frame(
                                width: CGFloat(segment.widthModules) * fittedModuleWidth,
                                height: proxy.size.height
                            )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            }
        }
    }
}
