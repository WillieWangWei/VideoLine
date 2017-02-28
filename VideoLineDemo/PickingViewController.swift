//
//  PickingViewController.swift
//  VideoLineDemo
//
//  Created by 王炜 on 2017/2/24.
//  Copyright © 2017年 Willie. All rights reserved.
//

import UIKit
import Photos
import SnapKit

let SCREEN_BOUNDS = UIScreen.main.bounds
let SCREEN_WIDTH = SCREEN_BOUNDS.width
let SCREEN_HEIGHT = SCREEN_BOUNDS.height
private let ROW_COUNT = 3
private let SPACING = CGFloat(10)

class PickingViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    var collectionView: UICollectionView!
    var fetchResult: PHFetchResult<PHAsset>?
    var itemSize: CGSize!
    var thumbnailSize: CGSize!
    var imageManager: PHCachingImageManager!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = #colorLiteral(red: 0.5843137503, green: 0.8235294223, blue: 0.4196078479, alpha: 1)
        
        // 读取相册中的视频
        self.fetchAssets()
        
        // 初始化collectionView
        self.initCollectionView()
    }
    
    func fetchAssets() {
        
        // 1.抓取视频对象
        
        // 创建fetchOptions实例
        let fetchOptions = PHFetchOptions()
        // 指定fetchOptions的排序规则
        fetchOptions.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: true)]
        // 开始fetch操作，只抓取视频对象，且应用上面创建的fetchOptions实例
        fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        // 2.计算需要使用的尺寸
        
        // 获取屏幕的scale
        let sclae = UIScreen.main.scale
        // 计算出cell的宽高
        let itemWidth = (SCREEN_WIDTH - SPACING * CGFloat((ROW_COUNT + 1))) / CGFloat(ROW_COUNT)
        // 计算出cell的size
        itemSize = CGSize(width: itemWidth, height: itemWidth)
        // 计算出抓取缩略图的size，要乘以scale来保证清晰度
        thumbnailSize = CGSize(width: itemWidth * sclae, height: itemWidth * sclae)
        
        // 3.开始生成缩略图
        
        // 创建imageManager实例，用来批量生成缩略图
        imageManager = PHCachingImageManager()
        var assets = [PHAsset]()
        // 枚举fetchResult，将其asset添加到assets数组中
        fetchResult?.enumerateObjects({ (asset, _, _) in
            assets.append(asset)
        })
        // 开始对assets生成缩略图，这将会在后台线程上执行
        imageManager.startCachingImages(for: assets, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
    }
    
    func initCollectionView() {
        
        // 1.创建CollectionView布局
        
        // 创建布局实例
        let flowLayout = UICollectionViewFlowLayout()
        // 指定item的大小
        flowLayout.itemSize = itemSize
        // 指定item左右和上下间距
        flowLayout.minimumLineSpacing = CGFloat(SPACING)
        flowLayout.minimumInteritemSpacing = CGFloat(SPACING)
        
        // 2.创建CollectionView
        
        // 创建CollectionView并应用布局
        collectionView = UICollectionView(frame: SCREEN_BOUNDS, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = UIColor.white
        collectionView.register(PickingViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { (make) in
            make.edges.equalTo(view)
        }
    }
}

extension PickingViewController {
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PickingViewCell
        
        // 取出对应的asset
        let asset = fetchResult?.object(at: indexPath.row)
        // 将asset和cell绑定
        cell.localIdentifier = asset?.localIdentifier
        
        // 取出asset对应生成缩略图
        imageManager.requestImage(for: asset!,
                                  targetSize: thumbnailSize,
                                  contentMode: .aspectFill,
                                  options: nil) { (image, _) in
                                    
                                    // 将缩略图显示在cell上
                                    if cell.localIdentifier == asset?.localIdentifier {
                                        cell.imageView.image = image
                                    }
        }
        
        return cell
    }
    
    // MARK: UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let vc = DisplayViewController()
        vc.phAsset = fetchResult?.object(at: indexPath.row)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: -

class PickingViewCell: UICollectionViewCell {
    
    var localIdentifier: String?
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        self.contentView.addSubview(imageView)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.contentView)
        }
        return imageView
    }()
}
