//
//  Colorizer.swift
//  MeshDemo
//
//  Created by Nikita Evstigneev on 25/05/2020.
//  Copyright © 2020 SABO Mobile IT. All rights reserved.
//

import Foundation
import UIKit

class Colorizer {
    private var colors: [UUID: UIColor] = [:]
    
    func assignColor(to id: UUID) -> UIColor {
        let color = colors[id] ?? UIColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 0.9)
        colors[id] = color
        return color
    }
}
