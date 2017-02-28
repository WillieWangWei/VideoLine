# VideoLine

##需求
Swift 3.0

##说明
一个视频时间轴选择控件。它可以自动解析一个包含录像信息的`AVAsset`对象，进而生成缩略图来显示。

当拖动滑块或缩略图时，当前选取的时间段会实时通过代理方法返回以供使用。

##功能演示
![](http://upload-images.jianshu.io/upload_images/4518631-37266302283569c7.gif?imageMogr2/auto-orient/strip)

##使用
* 导入

直接拖拽`VideoLine.swift`到您的项目中即可。

* 初始化

```
// 通过构造器指定frame，以及绑定的AVAsset
videoLine = VideoLine(frame: CGRect(x: 0, y: SCREEN_HEIGHT - 100, width: SCREEN_WIDTH, height: 100), asset: avAsset!)
// 指定可选的区间，(2, 5)指最少选择2秒的内容，最多选择5秒的内容
videoLine.range = (2, 5)
// 设置代理
videoLine.delegate = self
// 自定义UI 可选的
videoLine.leftSlider.image = #imageLiteral(resourceName: "silder")
videoLine.rightSlider.image = #imageLiteral(resourceName: "silder")
videoLine.thumbnailSize = CGSize(width: 30, height: 50)
// 添加到父视图
view.addSubview(videoLine)
// 开始处理数据
videoLine.process()
```

* 更新指示器

```
videoLine.update(second: second)
```

* 代理方法

```
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
```

* 更多内容

请参照Demo。

##实现过程
[《使用Swift构建一个视频时间轴控件》](http://www.jianshu.com/p/5fbc1079d63f)