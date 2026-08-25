//
//  BlurFadeModifier.swift
//  UnionTabView
//
//  Created by Union St on 11/28/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func blurFade(_ status: Bool) -> some View {
        self
            .compositingGroup()
            .blur(radius: status ? 0 : 10)
            .opacity(status ? 1 : 0)
    }
}
