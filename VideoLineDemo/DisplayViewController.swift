//
//  DisplayViewController.swift
//  VideoLineDemo
//
//  Created by 王炜 on 2017/2/25.
//  Copyright © 2017年 Willie. All rights reserved.
//

import UIKit
import Photos

class DisplayViewController: UIViewController {
    
    /// 相册中请求出的asset，由外部赋值
    var phAsset: PHAsset?
    
    /// PHAsset中的AVAsset
    fileprivate var avAsset: AVAsset?
    /// 由AVAsset创建的AVPlayer
    fileprivate var player: AVPlayer?
    /// AVPlayer的监听者
    fileprivate var playerTimeObserver: AnyObject?
    
    /// 片段的起始时间，单位秒
    fileprivate var startSecond = 0.0
    /// 片段的结束时间，单位秒
    fileprivate var endSecond = 0.0
    
    /// 播放控制按钮
    fileprivate lazy var playButton: UIButton = {
        let playButton = UIButton()
        playButton.setTitle("播放", for: .normal)
        playButton.backgroundColor = UIColor.red
        playButton.sizeToFit()
        return playButton
    }()
    /// videoLine
    fileprivate var videoLine: VideoLine!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        // 请求AVAsset
        self.requestAVAsset()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // 移除播放器监听
        if let actualObserver = playerTimeObserver {
            player?.removeTimeObserver(actualObserver)
        }
    }
    
    deinit {
        print("deinit")
    }
}

private extension DisplayViewController {
    
    func requestAVAsset() {
        
        // 创建PHVideoRequestOptions实例
        let options = PHVideoRequestOptions()
        // 如果本地没有此视频，不允许从iCloud下载
        options.isNetworkAccessAllowed = false
        // 忽略质量，最快加载速度
        options.deliveryMode = .fastFormat
        // 从PHAsset中请求AVAsset
        PHImageManager.default().requestAVAsset(forVideo: phAsset!, options: options) { (asset, _, _) in
            DispatchQueue.main.async {
                self.avAsset = asset
                self.initPlayer()
            }
        }
    }
    
    func initPlayer() {
        
        // 1.初始化AVPlayer
        
        // 通过AVAsset创建一个AVPlayer实例
        player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset!))
        // 给player添加一个监听，并指定更新周期
        playerTimeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: nil, using: { [weak self] (time) in
            
            let second = CMTimeGetSeconds(time)
            print(String(format:"start %.2f, end %.2f, current %.2f", (self?.startSecond)!, (self?.endSecond)!, second))
            
            // 如果即将播放到尾部，返回头部重新播放
            if second >= (self?.endSecond)! - 0.2 {
                self?.player?.seek(to: CMTime(value: CMTimeValue((self?.startSecond)!), timescale: 1))
                
                // 更新VideoLine状态
            } else if second > (self?.startSecond)! {
                self?.videoLine.update(second: second)
            }
        }) as AnyObject?
        
        // 2.初始化AVPlayerLayer
        
        // 通过AVPlayer创建一个AVPlayerLayer实例
        let playerLayer = AVPlayerLayer(player: player)
        // 设置显示方式，frame等
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect
        playerLayer.frame = CGRect(x: 0, y: 64, width: SCREEN_WIDTH, height: SCREEN_HEIGHT - 64 - 100)
        playerLayer.backgroundColor = UIColor.darkGray.cgColor
        view.layer.addSublayer(playerLayer)
        
        // 3.添加控制按钮
        
        playButton.addTarget(self, action: #selector(playButtonClick), for: .touchUpInside)
        playButton.center = view.center
        view.addSubview(playButton)
        
        // 4.初始化VideoLine
        self.initVideoLine()
    }
    
    func initVideoLine() {
        
        // 通过构造器指定frame，以及绑定的AVAsset
        videoLine = VideoLine(frame: CGRect(x: 0, y: SCREEN_HEIGHT - 100, width: SCREEN_WIDTH, height: 100), asset: avAsset!)
        // 指定可选的区间，(2, 5)指最少选择2秒的内容，最多选择5秒的内容
        videoLine.range = (2, 5)
        // 设置代理
        videoLine.delegate = self
        // 自定义UI
        videoLine.leftSlider.image = #imageLiteral(resourceName: "silder")
        videoLine.rightSlider.image = #imageLiteral(resourceName: "silder")
        videoLine.thumbnailSize = CGSize(width: 30, height: 50)
        // 添加到父视图上
        view.addSubview(videoLine)
        // 开始处理数据
        videoLine.process()
    }
    
    @objc func playButtonClick() {
        
        if player?.rate != 0 {
            
            player?.pause()
            playButton.setTitle("播放", for: .normal)
            
        } else {
            
            player?.play()
            playButton.setTitle("暂停", for: .normal)
        }
    }
}

extension DisplayViewController: VideoLineDelegate {
    
    // MARK: VideoLineDelegate
    
    func videoLine(_ videoLine: VideoLine, sliderValueChanged startSecond: Double, endSecond: Double) {
        // startSecond是选中区间开始的秒数，endSecond是选中区间结束的秒数
        
        self.startSecond = startSecond
        self.endSecond = endSecond
        player?.pause()
    }
    
    func videoLineDidEndDragging(_ videoLine: VideoLine) {
        player?.seek(to: CMTime(seconds: startSecond, preferredTimescale: 1), completionHandler: { (_) in
            self.player?.play()
        })
    }
}
