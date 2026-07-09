//
//  RibbonTabBar.swift
//  ZPrint
//

import SwiftUI

struct RibbonTabBar: View {
    @Binding var selectedTab: RibbonTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RibbonTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? ZPrintDesign.ColorToken.accent : Color.primary)
                        .frame(minWidth: 82, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        Rectangle()
                            .fill(ZPrintDesign.ColorToken.accent)
                            .frame(height: 2)
                            .padding(.horizontal, 13)
                    }
                }
            }

            Spacer()
        }
        .frame(height: ZPrintDesign.Metric.ribbonTabHeight)
    }
}
