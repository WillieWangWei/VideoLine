//
//  VideoLine.swift
//  VideoLineDemo
//
//  Created by 王炜 on 2017/2/25.
//  Copyright © 2017年 Willie. All rights reserved.
//

import UIKit
import AVFoundation
import SnapKit

@objc protocol VideoLineDelegate {
    
    /// 当左滑块或右滑块正在拖动时会调用此方法
    ///
    /// - Parameters:
    ///   - videoLine: 当前对象
    ///   - startSecond: 当前选中区间的开始秒数
    ///   - endSecond: 当前选中区间的结束秒数
    @objc optional func videoLine(_ videoLine: VideoLine, sliderValueChanged startSecond: Double, endSecond: Double)
    
    /// 当左滑块或右滑块结束拖动时会调用此方法
    ///
    /// - Parameter videoLine: 当前对象
    @objc optional func videoLineDidEndDragging(_ videoLine: VideoLine)
}

class VideoLine: UIView {
    
    /// 绑定的AVAsset对象
    private(set) var asset: AVAsset?
    /// 指定选择的区间，minDuration不得小于1秒。当maxDuration大于视频总长度时，会取视频总程度作为maxDuration
    var range: (minDuration: Double, maxDuration: Double) = (2, 5) {
        willSet {
            assert(
                newValue.minDuration >= 1 &&
                newValue.maxDuration >= 1 &&
                newValue.maxDuration >= newValue.minDuration,
                   "range value error")
        }
    }
    /// 左滑块
    lazy var leftSlider: UIImageView = {
        let leftSlider = UIImageView()
        leftSlider.backgroundColor = UIColor.white
        leftSlider.isUserInteractionEnabled = true
        leftSlider.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(leftSliderPaning)))
        return leftSlider
    }()
    /// 右滑块
    lazy var rightSlider: UIImageView = {
        let rightSlider = UIImageView()
        rightSlider.backgroundColor = UIColor.white
        rightSlider.isUserInteractionEnabled = true
        rightSlider.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(rightSliderPaning)))
        return rightSlider
    }()
    /// 单个缩略图的大小，默认(width: 40, height: 70)
    var thumbnailSize: CGSize = CGSize(width: 40, height: 70)
    /// 当前对象的代理
    weak var delegate: VideoLineDelegate?
    
    /// 开始时间label
    fileprivate var startTimeLabel: UILabel!
    /// 结束时间label
    fileprivate var endTimeLabel: UILabel!
    /// 总计时间label
    fileprivate var durationTimeLabel: UILabel!
    /// 下方呈现所有缩略图并可以滚动的view
    fileprivate var collectionView: UICollectionView!
    /// 拖动滑块时出现的边界
    fileprivate var limitBoard: UIView!
    /// 播放进度指示器
    fileprivate var indicator: UIView!
    
    /// 缩略图的最少个数
    fileprivate var minCount: Int = 10
    /// 选择区域距离左右边界的距离
    fileprivate var margin: CGFloat = 0
    /// 视频的总时长
    fileprivate var originalDuration: CGFloat = 0
    /// 区域中每一点距离代表的视频秒数，计算得到
    fileprivate var secondPerPoint: CGFloat!
    /// 每张缩略图之间间隔的秒数
    fileprivate var timeSpacing: CGFloat!
    /// 总共生成缩略图的个数
    fileprivate var totalCount: Int = 0
    /// 存放缩略图的数组
    fileprivate var images = [UIImage]()
    /// 生成缩略图的对象
    fileprivate var imageGenerator: AVAssetImageGenerator!
    
    
    /// 构造一个VideoLine实例
    ///
    /// - Parameters:
    ///   - frame: frame
    ///   - asset: 需要绑定视频的AVAsset
    init(frame: CGRect, asset: AVAsset) {
        super.init(frame: frame)
        
        self.asset = asset
        backgroundColor = UIColor.lightGray
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 当所需的属性赋值完毕后，调用此方法开始处理处理数据
    func process() {
        
        assert(asset != nil, "asset cann't be nil")
        self.setupData()
        self.setupUtil()
    }
    
    /// 更新当前指示器显示的时间
    ///
    /// - Parameter second: 当前播放到的时秒数
    func update(second: Double) {
        
        let startSecond = (leftSlider.frame.minX + collectionView.contentOffset.x) * secondPerPoint;
        let offset = (CGFloat(second) - startSecond) / secondPerPoint;
        
        indicator.snp.updateConstraints { (make) in
            make.leading.equalTo(leftSlider).offset(offset);
        }
    }
}

extension VideoLine: UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! VideoLineCell
        cell.imageView.image = images[indexPath.row]
        return cell
    }
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // 更新label显示内容
        
        let startSecond = (leftSlider.frame.minX + collectionView.contentOffset.x) * secondPerPoint
        startTimeLabel.text = String(format: "%02d:%02d开始", Int(startSecond / 60), Int(startSecond.truncatingRemainder(dividingBy: 60)))
        
        let endSecond = (rightSlider.frame.maxX + collectionView.contentOffset.x) * secondPerPoint
        endTimeLabel.text = String(format: "%02d:%02d结束", Int(endSecond / 60), Int(endSecond.truncatingRemainder(dividingBy: 60)))
        
        let durationSecond = (rightSlider.frame.maxX - leftSlider.frame.minX) * secondPerPoint;
        durationTimeLabel.text = String(format: "共%.1f秒", durationSecond)
        
        // 更新指示器位置
        self.update(second: Double(startSecond))
        
        // 通知代理
        guard let _ = delegate?.videoLine?(self, sliderValueChanged: Double(startSecond), endSecond: Double(endSecond)) else {
            print("videoLineSliderValueChanged is not implemented")
            return
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        // 通知代理
        guard let _ = delegate?.videoLineDidEndDragging?(self) else {
            print("videoLineDidEndDragging is not implemented")
            return
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        // 通知代理
        guard let _ = delegate?.videoLineDidEndDragging?(self) else {
            print("videoLineDidEndDragging is not implemented")
            return
        }
    }
}

private extension VideoLine {
    
    // 计算出所需数值
    func setupData() {
        
        originalDuration = CGFloat(CMTimeGetSeconds(asset!.duration))
        minCount = Int(self.frame.width) / Int(thumbnailSize.width) - 2
        
        range = (CGFloat(range.minDuration) > originalDuration ? Double(originalDuration) : range.minDuration,
                 CGFloat(range.maxDuration) > originalDuration ? Double(originalDuration) : range.maxDuration)
        
        timeSpacing = CGFloat(range.maxDuration) / CGFloat(minCount)
        totalCount = Int(originalDuration / timeSpacing)
        secondPerPoint = timeSpacing / thumbnailSize.width;
        margin = (self.frame.width - CGFloat(minCount) * thumbnailSize.width) * 0.5
        
        self.generatorImages()
    }
    
    // 初始化所有视图
    func setupUtil() {
        
        startTimeLabel = UILabel()
        self.addSubview(startTimeLabel)
        startTimeLabel.snp.makeConstraints { (make) in
            make.leading.equalTo(8)
            make.top.equalTo(self)
        }
        
        endTimeLabel = UILabel()
        self.addSubview(endTimeLabel)
        endTimeLabel.snp.makeConstraints { (make) in
            make.trailing.equalTo(-8)
            make.top.equalTo(self)
        }
        
        durationTimeLabel = UILabel()
        self.addSubview(durationTimeLabel)
        durationTimeLabel.snp.makeConstraints { (make) in
            make.centerX.top.equalTo(self)
        }
        
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = thumbnailSize
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.scrollDirection = .horizontal
        
        collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
        collectionView.bounces = false
        collectionView.register(VideoLineCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.contentInset = UIEdgeInsetsMake(0, CGFloat(margin), 0, CGFloat(margin))
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor.lightGray
        self.addSubview(collectionView)
        collectionView.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalTo(self)
            make.height.equalTo(thumbnailSize.height)
        }
        
        self.addSubview(leftSlider)
        leftSlider.snp.makeConstraints { (make) in
            make.leading.equalTo(margin)
            make.bottom.equalTo(collectionView)
            make.size.equalTo(CGSize(width: 10, height: thumbnailSize.height))
        }
        
        let leftMask = UIView()
        leftMask.isUserInteractionEnabled = false
        leftMask.backgroundColor = UIColor(white: 0, alpha: 0.7)
        self.addSubview(leftMask)
        leftMask.snp.makeConstraints { (make) in
            make.leading.top.bottom.equalTo(collectionView)
            make.trailing.equalTo(leftSlider.snp.leading)
        }
        
        self.addSubview(rightSlider)
        rightSlider.snp.makeConstraints { (make) in
            make.trailing.equalTo(-margin)
            make.bottom.size.equalTo(leftSlider)
        }
        
        let rightMask = UIView()
        rightMask.isUserInteractionEnabled = false
        rightMask.backgroundColor = UIColor(white: 0, alpha: 0.7)
        self.addSubview(rightMask)
        rightMask.snp.makeConstraints { (make) in
            make.trailing.top.bottom.equalTo(collectionView)
            make.leading.equalTo(rightSlider.snp.trailing);
        }

        limitBoard = UIView()
        limitBoard.layer.borderWidth = 2
        limitBoard.layer.borderColor = UIColor(white: 1.0, alpha: 0.5).cgColor
        limitBoard.isHidden = true
        self.addSubview(limitBoard)
        limitBoard.snp.makeConstraints { (make) in
            make.size.equalTo(CGSize(width: self.frame.width - 2 * margin, height: thumbnailSize.height))
            make.center.equalTo(collectionView)
        }
        
        let topMask = UIView()
        topMask.isUserInteractionEnabled = false
        topMask.backgroundColor = UIColor.white
        self.addSubview(topMask)
        topMask.snp.makeConstraints { (make) in
            make.top.equalTo(collectionView)
            make.height.equalTo(3)
            make.leading.equalTo(leftSlider.snp.trailing)
            make.trailing.equalTo(rightSlider.snp.leading)
        }
        
        let bottomMask = UIView()
        bottomMask.isUserInteractionEnabled = false
        bottomMask.backgroundColor = UIColor.white
        self.addSubview(bottomMask)
        bottomMask.snp.makeConstraints { (make) in
            make.bottom.equalTo(collectionView)
            make.height.leading.trailing.equalTo(topMask)
        }
        
        indicator = UIView()
        indicator.backgroundColor = UIColor.white
        self.insertSubview(indicator, belowSubview: leftSlider)
        indicator.snp.makeConstraints { (make) in
            make.leading.equalTo(leftSlider);
            make.width.equalTo(3);
            make.top.bottom.equalTo(collectionView);
        }
    }

    func generatorImages() {
        
        imageGenerator = AVAssetImageGenerator(asset: asset!)
        
        for i in 0..<totalCount {
            
            if let image = self.getVideoPreViewImage(second: Double(i) * Double(timeSpacing),
                                                     size: thumbnailSize,
                                                     transform: asset?.tracks.first?.preferredTransform) {
                images.append(image)
            }
        }
    }
    
    func getVideoPreViewImage(second: Double, size: CGSize, transform: CGAffineTransform?) -> UIImage? {
        
        var actualTime = CMTime()
        let time = CMTime(seconds: Double(second), preferredTimescale: 1)
        var cgImage: CGImage
        
        do {
            cgImage = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)
            
        } catch {
            
            print(error)
            return nil
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()
        var image = UIImage()
        
        if transform?.tx != 0 { // 竖屏录制的视频
            
            context?.draw(cgImage, in: .init(x: 0, y: 0, width: size.width, height: size.height))
            context?.translateBy(x: size.width, y: 0)
            image = UIImage(cgImage: context!.makeImage()!, scale: 0, orientation: .leftMirrored)
            
        } else {    // 横屏录制的视频
            
            context?.draw(cgImage, in: .init(x: 0, y: 0, width: size.height * (1 + (size.height - size.width) / size.height), height: size.height))
            image = UIImage(cgImage: context!.makeImage()!, scale: 0, orientation: .downMirrored)
        }
        
        UIGraphicsEndImageContext()
        
        return image
    }
    
    @objc func leftSliderPaning(panGR: UIPanGestureRecognizer) {
        
        if originalDuration <= CGFloat(range.minDuration) {
            return
        }
        
        let tX = panGR.translation(in: self).x
        
        let min = margin
        let max = rightSlider.frame.maxX - CGFloat(range.minDuration) / secondPerPoint
        
        if leftSlider.frame.minX + tX < min  {
            leftSlider.snp.updateConstraints({ (make) in
                make.leading.equalTo(min)
            })
            
        } else if leftSlider.frame.minX + tX > max {
            leftSlider.snp.updateConstraints({ (make) in
                make.leading.equalTo(max)
            })
            
        } else {
            leftSlider.snp.updateConstraints({ (make) in
                make.leading.equalTo(leftSlider.frame.minX + tX)
            })
        }
        
        self.scrollViewDidScroll(collectionView)
        
        panGR.setTranslation(CGPoint.zero, in: self)
        limitBoard.isHidden = panGR.state != .changed
        
        if panGR.state == .ended {
            
            guard let _ = delegate?.videoLineDidEndDragging?(self) else {
                print("videoLineDidEndDragging is not implemented")
                return
            }
        }
    }
    
    @objc func rightSliderPaning(panGR: UIPanGestureRecognizer) {
        
        if originalDuration <= CGFloat(range.minDuration) {
            return
        }
        
        let tX = panGR.translation(in: self).x
        
        let min = margin
        let max = self.frame.width - (leftSlider.frame.minX + CGFloat(range.minDuration) / secondPerPoint)
        
        if self.frame.width - (rightSlider.frame.maxX + tX) < min  {
            rightSlider.snp.updateConstraints({ (make) in
                make.trailing.equalTo(-min)
            })
            
        } else if self.frame.width - (rightSlider.frame.maxX + tX) > max {
            rightSlider.snp.updateConstraints({ (make) in
                make.trailing.equalTo(-max)
            })
            
        } else {
            rightSlider.snp.updateConstraints({ (make) in
                make.trailing.equalTo(-(self.frame.width - rightSlider.frame.maxX - tX))
            })
        }
        
        self.scrollViewDidScroll(collectionView)
        
        panGR.setTranslation(CGPoint.zero, in: self)
        limitBoard.isHidden = panGR.state != .changed
        
        if panGR.state == .ended {
            
            guard let _ = delegate?.videoLineDidEndDragging?(self) else {
                print("videoLineDidEndDragging is not implemented")
                return
            }
        }
    }
}

// MARK: -

private class VideoLineCell: UICollectionViewCell {
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.clipsToBounds = true
        self.contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.contentView)
        }
        return imageView
    }()
}
