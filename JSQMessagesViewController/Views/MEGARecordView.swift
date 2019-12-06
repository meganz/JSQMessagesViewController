import UIKit

class MEGARecordView: UIView {
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var volumeIcon: UIImageView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @objc static var recordView: MEGARecordView? {
        let bundle = Bundle(for: MEGARecordView.self)
        let nib = UINib(nibName: "MEGARecordView", bundle: bundle)
        return nib.instantiate(withOwner: nil, options: nil).first as? MEGARecordView
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
    @objc var currentVolume: Float = 0.0 {
        didSet {
            let imageNumber = min(Int(round(currentVolume * 6.0)), 6)
            volumeIcon.image = UIImage(named: "feedbackBars\(imageNumber)")
        }
    }
}

