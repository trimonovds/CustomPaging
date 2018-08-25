//
//  PagingView.swift
//  CustomPaging
//
//  Created by Ilya Lobanov on 26/08/2018.
//  Copyright © 2018 Ilya Lobanov. All rights reserved.
//

import UIKit
import pop

final class PagingView: UIView {
    
    let contentView: UIScrollView
    
    var anchors: [CGPoint] = []
    
    var decelerationRate: CGFloat = UIScrollView.DecelerationRate.fast.rawValue
    
    /**
     @abstract The effective bounciness.
     @discussion Use in conjunction with 'springSpeed' to change animation effect. Values are converted into corresponding dynamics constants. Higher values increase spring movement range resulting in more oscillations and springiness. Defined as a value in the range [0, 20]. Defaults to 4.
     */
    var springBounciness: CGFloat = 4

    /**
     @abstract The effective speed.
     @discussion Use in conjunction with 'springBounciness' to change animation effect. Values are converted into corresponding dynamics constants. Higher values increase the dampening power of the spring resulting in a faster initial velocity and more rapid bounce slowdown. Defined as a value in the range [0, 20]. Defaults to 12.
     */
    var springSpeed: CGFloat = 12
    
    init(contentView: UIScrollView) {
        self.contentView = contentView
        
        super.init(frame: .zero)
        
        setupViews()
        startContentObserving()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private
    
    private let gestureScrollView = UIScrollView()
    
    private var observers: [NSKeyValueObservation] = []
    
    private var minAnchor: CGPoint {
        let x = -gestureScrollView.adjustedContentInset.left
        let y = -gestureScrollView.adjustedContentInset.top
        return CGPoint(x: x, y: y)
    }
    
    private var maxAnchor: CGPoint {
        let x = gestureScrollView.contentSize.width - bounds.width + gestureScrollView.adjustedContentInset.right
        let y = gestureScrollView.contentSize.height - bounds.height + gestureScrollView.adjustedContentInset.bottom
        return CGPoint(x: x, y: y)
    }
    
    private func setupViews() {
        gestureScrollView.addSubview(contentView)
        contentView.isScrollEnabled = false
    
        addSubview(gestureScrollView)
        gestureScrollView.delegate = self
        gestureScrollView.contentSize = contentView.contentSize
        gestureScrollView.contentInset = contentView.contentInset
        gestureScrollView.contentOffset = contentView.contentOffset
        gestureScrollView.alwaysBounceVertical = contentView.alwaysBounceVertical
        gestureScrollView.alwaysBounceHorizontal = contentView.alwaysBounceHorizontal
        gestureScrollView.showsVerticalScrollIndicator = false
        gestureScrollView.showsHorizontalScrollIndicator = false
    
        setupLayout()
    }
    
    private func setupLayout() {
        gestureScrollView.translatesAutoresizingMaskIntoConstraints = false
        gestureScrollView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        gestureScrollView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        gestureScrollView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        gestureScrollView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        contentView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        contentView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
    }
    
    private func nearestAnchor(forContentOffset offset: CGPoint) -> CGPoint? {
        guard let candidate = anchors.min(by: { offset.distance(to: $0) < offset.distance(to: $1) }) else {
            return nil
        }
        
        let x = candidate.x.clamped(to: minAnchor.x...maxAnchor.x)
        let y = candidate.y.clamped(to: minAnchor.y...maxAnchor.y)
        
        return CGPoint(x: x, y: y)
    }
    
    private func startContentObserving() {
        observers = [
            contentView.observe(\.contentSize, options: .new) { [weak self] _, value in
                self?.gestureScrollView.contentSize = value.newValue ?? .zero
            },
            contentView.observe(\.contentInset, options: .new) { [weak self] _, value in
                self?.gestureScrollView.contentInset = value.newValue ?? .zero
            },
            contentView.observe(\.contentOffset, options: .new) { [weak self] _, value in
                if let new = value.newValue,
                    // To avoid cycle
                    new != self?.gestureScrollView.contentOffset
                {
                    self?.gestureScrollView.contentOffset = new
                }
            },
            contentView.observe(\.alwaysBounceVertical, options: .new) { [weak self] _, value in
                self?.gestureScrollView.alwaysBounceVertical = value.newValue ?? false
            },
            contentView.observe(\.alwaysBounceHorizontal, options: .new) { [weak self] _, value in
                self?.gestureScrollView.alwaysBounceHorizontal = value.newValue ?? false
            }
        ]
    }
    
    // MARK: - Private: Animation
    
    private static let snappingAnimationKey = "CustomPaging.PagingView.scrollView.snappingAnimation"
    
    private func snapAnimated(toContentOffset newOffset: CGPoint, velocity: CGPoint) {
        let animation: POPSpringAnimation = POPSpringAnimation(propertyNamed: kPOPScrollViewContentOffset)
        animation.velocity = velocity
        animation.toValue = newOffset
        animation.fromValue = gestureScrollView.contentOffset
        animation.springBounciness = springBounciness
        animation.springSpeed = springSpeed
     
        gestureScrollView.pop_add(animation, forKey: PagingView.snappingAnimationKey)
    }
    
    private func stopSnappingAnimation() {
        gestureScrollView.pop_removeAnimation(forKey: PagingView.snappingAnimationKey)
    }
}


extension PagingView: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        contentView.contentOffset = scrollView.contentOffset
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>)
    {
        // Stop system animation
        targetContentOffset.pointee = scrollView.contentOffset
    
        let offsetProjection = scrollView.contentOffset.project(initialVelocity: velocity,
            decelerationRate: decelerationRate)
        
        if let target = nearestAnchor(forContentOffset: offsetProjection) {
            snapAnimated(toContentOffset: target, velocity: velocity)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stopSnappingAnimation()
    }
    
}
