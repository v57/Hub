//
//  Layout.swift
//  Hub
//
//  Created by Linux on 07.02.26.
//

import SwiftUI

struct HomeGridSpacing: EnvironmentKey {
  static var defaultValue: CGFloat { 0 }
}
extension EnvironmentValues {
  var homeGridSpacing: CGFloat {
    get { self[HomeGridSpacing.self] }
    set { self[HomeGridSpacing.self] = newValue }
  }
}

struct HomeGrid: Layout {
  static var minSpacing: Int { 12 }
  static var size: Int { 68 }
  static func spacing(width: CGFloat) -> CGFloat {
    widthAndSpacing(proposal: ProposedViewSize(width: width, height: nil)).1
  }
  static func widthAndSpacing(proposal: ProposedViewSize) -> (Int, CGFloat) {
    let width = max(proposal.width ?? 148, 148)
    let intWidth = max(Int(width) / (size + minSpacing), 4) / 2 * 2
    let w = CGFloat(intWidth)
    let spacing = (width - w * CGFloat(size)) / (w + 1)
    return (intWidth, spacing)
  }
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    (cache.width, cache.spacing) = HomeGrid.widthAndSpacing(proposal: proposal)
    cache.reset()
    
    for i in 0..<subviews.count {
      let p = subviews[i][GridSize.self]
      cache.fill(index: i, p: p)
    }
    var size = proposal.replacingUnspecifiedDimensions()
    size.height = CGFloat(cache.height * self.size) + CGFloat(cache.height) * (cache.spacing - 1)
    return size
  }
  func makeCache(subviews: Subviews) -> Cache {
    Cache()
  }
  var minSpacing: Int { 12 }
  var size: Int { 68 }
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
    let spacing = cache.spacing
    let size = CGFloat(size)
    for i in 0..<min(subviews.count, cache.data.count) {
      let position = cache.data[i].float
      let p = CGPoint(x: position.x * (size + spacing) + spacing + bounds.minX, y: position.y * (size + spacing) + bounds.minY)
      let width = CGFloat((size+spacing)*position.w - spacing)
      let height = CGFloat((size+spacing)*position.h - spacing)
      let s = ProposedViewSize(width: width, height: height)
      subviews[i].place(at: p, proposal: s)
    }
  }
  
  struct Cache {
    var space: [UInt64] = [0]
    var width: Int = 6
    var spacing: CGFloat = 0
    var data = [Placement]()
    var cache = [GridSize: Position]()
    var height: Int {
      for i in (0..<space.count).reversed() where space[i] > 0 {
        let rows = i * 64 / width
        let last = (64 - space[i].leadingZeroBitCount)
        if last % width == 0 {
          return rows + last / width
        } else {
          return rows + last / width + 1
        }
      }
      return 0
    }
    subscript(x: Int, y: Int) -> Bool {
      get {
        let index = y * width + x
        let arrayIndex = index / 64
        guard arrayIndex < space.count else { return false }
        return space[arrayIndex][index % 64]
      } set {
        let index = y * width + x
        let arrayIndex = index / 64
        if arrayIndex >= space.count {
          space.append(contentsOf: Array<UInt64>(repeating: 0, count: arrayIndex - space.count + 1))
        }
        space[arrayIndex][index % 64] = newValue
      }
    }
    subscript(x: Int, y: Int, width: Int, height: Int) -> Bool {
      get {
        assert(width <= self.width)
        for i in x..<x+width {
          for j in y..<y+height {
            if self[i, j] {
              return true
            }
          }
        }
        return false
      } set {
        assert(width <= self.width)
        for i in x..<x+width {
          for j in y..<y+height {
            self[i, j] = newValue
          }
        }
      }
    }
    mutating func fill(index: Int, p: GridSize) {
      guard width > 1 else { return }
      var y = 0
      var x = 0
      if let position = cache[p] {
        x = position.x
        y = position.y
      }
      while true {
        while x + p.ax <= width {
          if !self[x, y, p.w, p.h] {
            cache[p] = Position(x: x, y: y)
            data.append(Placement(x: x, y: y, w: p.w, h: p.h))
            self[x, y, p.w, p.h] = true
            return
          }
          x += p.ax
        }
        x = 0
        y += p.ay
      }
      fatalError()
    }
    mutating func reset() {
      space = [0]
      data = []
      cache = [:]
    }
    struct Placement {
      let x: Int, y: Int, w: Int, h: Int
      var float: CGPlacement {
        CGPlacement(x: CGFloat(x), y: CGFloat(y), w: CGFloat(w), h: CGFloat(h))
      }
      struct CGPlacement {
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
      }
    }
    struct Position {
      let x: Int
      let y: Int
    }
  }
  struct GridSize: Hashable, LayoutValueKey {
    static var defaultValue: GridSize { GridSize(w: 1, h: 1) }
    let w: Int
    let h: Int
    var ax: Int { w }
    var ay: Int { h }
  }
  enum PositionPreset {
    case x11, x12, x21, x22, x41, x42, x24, x44
    var value: GridSize {
      switch self {
      case .x11: GridSize(w: 1, h: 1)
      case .x12: GridSize(w: 1, h: 2)
      case .x21: GridSize(w: 2, h: 1)
      case .x22: GridSize(w: 2, h: 2)
      case .x24: GridSize(w: 2, h: 4)
      case .x41: GridSize(w: 4, h: 1)
      case .x42: GridSize(w: 4, h: 2)
      case .x44: GridSize(w: 4, h: 4)
      }
    }
  }
}

extension View {
  func gridSize(_ preset: HomeGrid.PositionPreset) -> some View {
    layoutValue(key: HomeGrid.GridSize.self, value: preset.value)
  }
}

extension BinaryInteger {
  public subscript<T: BinaryInteger>(index: T) -> Bool {
    get { self & (1 << index) != 0 }
    set {
      if newValue {
        self |= 1 << index
      } else {
        self &= ~(1 << index)
      }
    }
  }
}
