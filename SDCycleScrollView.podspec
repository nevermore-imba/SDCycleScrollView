Pod::Spec.new do |s|

s.name         = "SDCycleScrollView"
s.version      = "1.8.4"
s.summary      = "简单易用的图片无限轮播器."

s.homepage     = "https://github.com/gsdios/SDCycleScrollView"

s.license      = "MIT"

s.author       = { "GSD_iOS" => "gsdios@126.com" }

s.platform     = :ios
s.platform     = :ios, "8.0"


s.source       = { :git => "https://github.com/gsdios/SDCycleScrollView.git", :tag => s.version}


s.source_files  = "SDCycleScrollView/Lib/SDCycleScrollView/**/*.{h,m}"


s.requires_arc = true

end
